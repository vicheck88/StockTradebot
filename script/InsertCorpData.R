print(paste0(Sys.time()," : Starting Script"))

library(RPostgres)
library(DBI)
library(jsonlite)

config=read_json("~/config.json")
dbConfig=config$database
krxLogin=config$krx
conn<-dbConnect(RPostgres::Postgres(),dbname=dbConfig$database,host=dbConfig$host,port=dbConfig$port,user=dbConfig$user,password=dbConfig$passwd)
#함수 불러돌이기
source("~/stockInfoCrawler/StockTradebot/script/RQuantFunctionList.R",encoding="utf-8")

#source("~/StockTradebot/script/telegramAPI.R") #macOS에서 읽는 경우
source("./telegramAPI.R") #라즈베리에서 읽는 경우

#전월 말 날짜 구하기
print(paste0(Sys.time()," : Starting to get date"))

availableDate<-getLastBizdayofMonth(2)
if(month(Sys.Date())==month(availableDate[2])) {
  availableDate<-availableDate[1]
} else{
  availableDate<-availableDate[2]
}
print(paste0("Date: ",availableDate))

latestDate<-dbGetQuery(conn,SQL("select max(일자) from metainfo.월별기업정보"))[,1]
count<-0
while(count<10){
  tryCatch({
    print(paste0(Sys.time()," : Starting to get current coporation list"))
    day<-str_remove_all(availableDate,"-")
    #전달 말 등록된 기업정보
    df<-KRXDataMerge(day, krxLogin)
    corpTable<-as.data.table(df)
    print(paste0(Sys.time()," : Succeed in getting corp Data."))
    break
  }, error = function(e) {
    count<<-count+1
    print(paste0(Sys.time()," : [",count,"/10] Fail to get corp Data: ",conditionMessage(e),". Try again after 5mins"))
    Sys.sleep(60*5)
  })
}
if(count==10) sendMessage("Fail to get recent corp Data. Use previous corp info")

#지금까지 등록되어있는 기업정보 구하기
prevCorpTable<-as.data.table(dbGetQuery(conn,
                                        SQL("select * from metainfo.월별기업정보 
                                            where 일자=(select max(일자) from metainfo.월별기업정보)")))
corpList<-unique(prevCorpTable$종목코드)
if(exists("corpTable")) {
  corpList<-unique(c(corpList,corpTable$종목코드))
} else {
  #prevCorpTable<-prevCorpTable[,c('일자','종목코드','종목명','시장구분','산업분류','현재가(종가)','시가총액',
  #                               '주당배당금','배당수익률','관리여부')]
  #prevCorpTable$일자<-as.Date(availableDate)
  #corpTable<-prevCorpTable
}

dbDisconnect(conn)
conn<-dbConnect(RPostgres::Postgres(),dbname=dbConfig$database,host=dbConfig$host,port=dbConfig$port,user=dbConfig$user,password=dbConfig$passwd)

print(paste0(Sys.time()," : Starting to write FS (total: ",length(corpList)," corps)"))
successCount<-0; failCount<-0
for(code in corpList){
  tryCatch({
    # 연결재무 (ReportGB=D)
    htmlData<-getFSHtmlFromFnGuide(code, reportGB='D')
    fsQ<-cleanFSHtmlToDataFrame('Q',htmlData[code])
    fsY<-cleanFSHtmlToDataFrame('Y',htmlData[code])
    if(!is.null(fsQ)) fsQ[, 연결구분 := '연결']
    if(!is.null(fsY)) fsY[, 연결구분 := '연결']

    # 별도재무 (ReportGB=B)
    htmlData_sep<-getFSHtmlFromFnGuide(code, reportGB='B')
    fsQ_sep<-cleanFSHtmlToDataFrame('Q',htmlData_sep[code])
    fsY_sep<-cleanFSHtmlToDataFrame('Y',htmlData_sep[code])
    if(!is.null(fsQ_sep)){
      fsQ_sep[, 연결구분 := '별도']
      fsQ<-rbind(fsQ, fsQ_sep)
    }
    if(!is.null(fsY_sep)){
      fsY_sep[, 연결구분 := '별도']
      fsY<-rbind(fsY, fsY_sep)
    }

    FfsY<-data.table(dbGetQuery(conn,SQL(sprintf("SELECT * from metainfo.연간재무제표 WHERE 종목코드='%s'",code))))
    FfsQ<-data.table(dbGetQuery(conn,SQL(sprintf("SELECT * from metainfo.분기재무제표 WHERE 종목코드='%s'",code))))

    names(fsQ)<-names(FfsQ[,-'등록일자'])
    names(fsY)<-names(FfsY[,-'등록일자'])
    newfsQ<-fsetdiff(fsQ,FfsQ[,-'등록일자'])
    newfsY<-fsetdiff(fsY,FfsY[,-'등록일자'])
    newfsQ$등록일자<-Sys.Date()
    newfsY$등록일자<-Sys.Date()
    setcolorder(newfsQ, names(FfsQ))
    setcolorder(newfsY, names(FfsY))
    dbWriteTable(conn,SQL("metainfo.분기재무제표"),newfsQ,append=TRUE,row.names=FALSE)
    dbWriteTable(conn,SQL("metainfo.연간재무제표"),newfsY,append=TRUE,row.names=FALSE)
    successCount<<-successCount+1
    print(paste0(Sys.time()," : [",which(corpList==code),"/",length(corpList),"] ", "Success: ",code," Q:",nrow(newfsQ)," Y:",nrow(newfsY)))
  },error=function(e){
    failCount<<-failCount+1
    print(paste0(Sys.time()," : [",which(corpList==code),"/",length(corpList),"] ", "FAIL: ",code," | ",conditionMessage(e)))
  })
}

text<-paste0(Sys.time()," : Complete updating FS (Success:",successCount," Fail:",failCount,")")
print(text)
print(paste0("telegram message send: ",sendMessage(text,0)))

#현재 날짜가 기록된 날짜보다 늦을 경우
if(latestDate!=availableDate && exists("corpTable")){
    print(paste0(Sys.time()," : Starting to summarize financial data"))
    fs<-NULL
    for(i in 1:nrow(corpTable)){
      oldN<-NROW(fs)
      code<-corpTable[i,종목코드]
      fsY<-data.table(dbGetQuery(conn,SQL(sprintf("SELECT * from metainfo.연간재무제표 WHERE 종목코드='%s' AND 연결구분='연결'",code))))
      fsQ<-data.table(dbGetQuery(conn,SQL(sprintf("SELECT * from metainfo.분기재무제표 WHERE 종목코드='%s' AND 연결구분='연결'",code))))
      fsY_sep<-data.table(dbGetQuery(conn,SQL(sprintf("SELECT * from metainfo.연간재무제표 WHERE 종목코드='%s' AND 연결구분='별도'",code))))
      fsQ_sep<-data.table(dbGetQuery(conn,SQL(sprintf("SELECT * from metainfo.분기재무제표 WHERE 종목코드='%s' AND 연결구분='별도'",code))))
      fsY<-unique(fsY,by=names(fsY)[1:4])
      fsQ<-unique(fsQ,by=names(fsQ)[1:4])
      fsY_sep<-unique(fsY_sep,by=names(fsY_sep)[1:4])
      fsQ_sep<-unique(fsQ_sep,by=names(fsQ_sep)[1:4])
      res<-cleanDataAndExtractEntitiesFromFS(corpTable[i,],fsY,fsQ,TRUE,fsY_sep,fsQ_sep)
      if(!is.null(fs) & !is.null(res)) names(res)<-names(fs)
      fs<-rbind(fs,res)
      if(oldN<NROW(fs)) print(paste0(Sys.time()," : [",i,"/",nrow(corpTable),"] success: Summarizing Data of ",corpTable[i,]$종목코드))
    }
    
    dbDisconnect(conn)
    conn<-dbConnect(RPostgres::Postgres(),dbname=dbConfig$database,host=dbConfig$host,port=dbConfig$port,user=dbConfig$user,password=dbConfig$passwd)
    
    res<-dbWriteTable(conn,SQL("metainfo.월별기업정보"),fs,append=TRUE)
    print(paste0(Sys.time()," : Finished"))
    sendMessage("Finished to summarize financial data")
} else{ print(paste0(Sys.time()," : Already updated. Script finished"))}
