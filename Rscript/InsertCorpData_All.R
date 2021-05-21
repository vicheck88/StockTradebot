library(RPostgres)
library(DBI)
library(jsonlite)
dbConfig=read_json("./config.json")$database
conn<-dbConnect(RPostgres::Postgres(),dbname=dbConfig$database,host=dbConfig$host,port=dbConfig$port,user=dbConfig$user,password=dbConfig$passwd)
#함수 불러돌이기
source("./RQuantFunctionList.R",encoding="utf-8")

#처음 전체 update

year<-as.character(2010:2021)
availableDate<-getLastBizdayofMonth(100)
availableDate<-availableDate[-99]
availableDate<-availableDate[availableDate>'2010-01-01']
availableDate<-str_remove_all(availableDate,"-")
availableDateForFS<-availableDate[substr(availableDate,5,6) %in% c('03','05','08','11')]

#전체 기업 데이터 획득
corpTable<-NULL
for(day in availableDate){
  tryCatch(
    {
      df<-KRXDataMerge(day)
      df<-subset(df,select=c("일자","종목코드", "종목명", "시장구분", "산업분류","현재가(종가)","시가총액","주당배당금", "배당수익률","관리여부"))
      corpTable<-rbind(corpTable,df)
    },
    error=function(e){
      print(paste0("Fail to Read: ",day))
    } 
  )
}
setDT(corpTable)

#dbWriteTable(conn,SQL("metainfo.월별기업정보"),corpTable)
#corpTable<-as.data.table(dbGetQuery(conn,SQL("select * from metainfo.월별기업정보")))
#모든 기업의 재무제표 구하기
print(paste0(Sys.time()," : Starting to get FS"))
#최신 재무제표 받기
corpList<-unique(corpTable$종목코드)
htmlData<-getFSHtmlFromFnGuide(corpList)

fsQ<-rbindlist(lapply(corpList,function(x){
  cleanFSHtmlToDataFrame('Q',htmlData[x])
}))
fsY<-rbindlist(lapply(corpList,function(x){
  cleanFSHtmlToDataFrame('Y',htmlData[x])
}))

dbDisconnect(conn)
conn<-dbConnect(RPostgres::Postgres(),dbname=dbConfig$database,host=dbConfig$host,port=dbConfig$port,user=dbConfig$user,password=dbConfig$passwd)

print(paste0(Sys.time()," : Starting to write FS"))
FfsY<-data.table(dbGetQuery(conn,SQL("SELECT * from metainfo.연간재무제표")))
FfsQ<-data.table(dbGetQuery(conn,SQL("SELECT * from metainfo.분기재무제표")))

fsY<-unique(rbind(FfsY,fsY),by=c("종목코드","종류","계정","일자"),fromLast=T)
fsQ<-unique(rbind(FfsQ,fsQ),by=c("종목코드","종류","계정","일자"),fromLast=T)

dbWriteTable(conn,SQL("test.분기재무제표"),fsQ,overwrite=TRUE,row.names=FALSE)
dbWriteTable(conn,SQL("test.연간재무제표"),fsY,overwrite=TRUE,row.names=FALSE)

print(paste0(Sys.time()," : Starting to get factor data"))
fs<-NULL

#등록날짜 설정하기
fsY[,등록일자:=as.Date(paste0(일자,'.01'),format='%Y.%m.%d')]
fsQ[,등록일자:=as.Date(paste0(일자,'.01'),format='%Y.%m.%d')]
fsY$등록일자<-fsY$등록일자 %m+% months(4)
fsQ$등록일자<-fsQ$등록일자 %m+% months(3)
joinedQ<-fsQ[fsY,.(종목코드,종류,계정,일자,값,등록일자=i.등록일자),on=c("종목코드","종류","계정","일자"),nomatch=0]
names(joinedQ)<-names(fsQ)
fsQ<-unique(rbind(fsQ,joinedQ),by=c("종목코드","종류","계정","일자","값"),fromLast=TRUE)


for(i in 1:nrow(corpTable)){
  res<-cleanDataAndExtractEntitiesFromFS(corpTable[i,],fsY,fsQ,FALSE)
  fs<-rbind(fs,res)
  if(!is.null(res)) print(paste0(Sys.time()," : [",i,"/",nrow(corpTable),"] success: calculating Factors of ",corpTable[i,]$종목코드," Date: ",corpTable[i,]$일자))
  #else print(paste0(Sys.time()," : [",i,"/",nrow(corpTable),"] fail: calculating Factors of ",corpTable[i,]$종목코드," Date: ",corpTable[i,]$일자," : return NULL"))
}

dbDisconnect(conn)
conn<-dbConnect(RPostgres::Postgres(),dbname=dbConfig$database,host=dbConfig$host,port=dbConfig$port,user=dbConfig$user,password=dbConfig$passwd)

res<-dbWriteTable(conn,SQL("metainfo.월별기업정보"),fs,overwrite=TRUE)
print(paste0(Sys.time()," : Finished"))
