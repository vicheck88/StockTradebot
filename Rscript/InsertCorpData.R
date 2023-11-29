print(paste0(Sys.time()," : Starting Script"))

library(RPostgres)
library(DBI)
library(jsonlite)
dbConfig=read_json("./config.json")$database
conn<-dbConnect(RPostgres::Postgres(),dbname=dbConfig$database,host=dbConfig$host,port=dbConfig$port,user=dbConfig$user,password=dbConfig$passwd)
#함수 불러돌이기
source("~/StockTradebot/Rscript/RQuantFunctionList.R",encoding="utf-8")

source("~/StockTradebot/Rscript/telegramAPI.R") #macOS에서 읽는 경우
#source("~/stockInfoCrawler/StockTradebot/Rscript/telegramAPI.R") #라즈베리에서 읽는 경우

#전월 말 날짜 구하기
print(paste0(Sys.time()," : Starting to get date"))

availableDate<-getLastBizdayofMonth(2)
if(month(Sys.Date())==month(availableDate[2])) {
  availableDate<-availableDate[1]
} else{
  availableDate<-availableDate[2]
}


latestDate<-dbGetQuery(conn,SQL("select max(일자) from metainfo.월별기업정보"))[,1]
count<-0
while(count<10){
  tryCatch({
    print(paste0(Sys.time()," : Starting to get current coporation list"))
    day<-str_remove_all(availableDate,"-")
    #전달 말 등록된 기업정보
    df<-KRXDataMerge(day)
    corpTable<-as.data.table(df)
    print(paste0(Sys.time()," : Succeed in getting corp Data."))
    break
  }, error = function(e) {
    count<-count+1
    print(paste0(Sys.time()," : Fail to get corp Data. Try again after 5mins"))
    Sys.sleep(60*5)
  })
}


#지금까지 등록되어있는 기업정보 구하기
prevCorpTable<-as.data.table(dbGetQuery(conn,
                                        SQL("select * from metainfo.월별기업정보 
                                            where 일자=(select max(일자) from metainfo.월별기업정보)")))
corpList<-unique(prevCorpTable$종목코드)
if(exists("corpTable")) {
  corpList<-unique(c(corpList,corpTable$종목코드))
} else {
  prevCorpTable<-prevCorpTable[,c('일자','종목코드','종목명','시장구분','산업분류','현재가(종가)','시가총액',
                                 '주당배당금','배당수익률','관리여부')]
  prevCorpTable$일자<-as.Date(availableDate)
  corpTable<-prevCorpTable
}

dbDisconnect(conn)
conn<-dbConnect(RPostgres::Postgres(),dbname=dbConfig$database,host=dbConfig$host,port=dbConfig$port,user=dbConfig$user,password=dbConfig$passwd)

print(paste0(Sys.time()," : Starting to write FS"))
for(code in corpList){
  tryCatch({
    htmlData<-getFSHtmlFromFnGuide(code)
    fsQ<-cleanFSHtmlToDataFrame('Q',htmlData[code])
    fsY<-cleanFSHtmlToDataFrame('Y',htmlData[code])
    
    FfsY<-data.table(dbGetQuery(conn,SQL(sprintf("SELECT * from metainfo.연간재무제표 WHERE 종목코드='%s'",code))))
    FfsQ<-data.table(dbGetQuery(conn,SQL(sprintf("SELECT * from metainfo.분기재무제표 WHERE 종목코드='%s'",code))))
    
    names(fsQ)<-names(FfsQ[,-'등록일자'])
    names(fsY)<-names(FfsY[,-'등록일자'])
    newfsQ<-fsetdiff(fsQ,FfsQ[,-'등록일자'])
    newfsY<-fsetdiff(fsY,FfsY[,-'등록일자'])
    newfsQ$등록일자<-Sys.Date()
    newfsY$등록일자<-Sys.Date()
    names(newfsQ)<-names(FfsQ)
    names(newfsY)<-names(FfsY)
    dbWriteTable(conn,SQL("metainfo.분기재무제표"),newfsQ,append=TRUE,row.names=FALSE)
    dbWriteTable(conn,SQL("metainfo.연간재무제표"),newfsY,append=TRUE,row.names=FALSE)
    print(paste0(Sys.time()," : [",which(corpList==code),"/",length(corpList),"] ", "Success: code: ",code," Quarter: ",nrow(newfsQ)," Year: ",nrow(newfsY)))
  },error=function(e){
    print(paste0(Sys.time()," : [",which(corpList==code),"/",length(corpList),"] ", "Fail: ",code))
  })
}

text<-paste0(Sys.time()," : Complete updating FS")
print(text)
sendMessage(text)

#현재 날짜가 기록된 날짜보다 늦을 경우
if(latestDate!=availableDate){
    print(paste0(Sys.time()," : Starting to summarize financial data"))
    fs<-NULL
    for(i in 1:nrow(corpTable)){
      oldN<-NROW(fs)
      code<-corpTable[i,종목코드]
      fsY<-data.table(dbGetQuery(conn,SQL(sprintf("SELECT * from metainfo.연간재무제표 WHERE 종목코드='%s'",code," order by 등록일자 desc"))))
      fsQ<-data.table(dbGetQuery(conn,SQL(sprintf("SELECT * from metainfo.분기재무제표 WHERE 종목코드='%s'",code," order by 등록일자 desc"))))
      fsY<-unique(fsY,by=names(fsY)[1:4])
      fsQ<-unique(fsQ,by=names(fsQ)[1:4])
      res<-cleanDataAndExtractEntitiesFromFS(corpTable[i,],fsY,fsQ,TRUE)
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
