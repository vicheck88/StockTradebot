print(paste0(Sys.time()," : Starting Script"))

library(RPostgres)
library(DBI)
library(jsonlite)
dbConfig=read_json("./config.json")$database
conn<-dbConnect(RPostgres::Postgres(),dbname=dbConfig$database,host=dbConfig$host,port=dbConfig$port,user=dbConfig$user,password=dbConfig$passwd)
#함수 불러돌이기
source("./RQuantFunctionList.R",encoding="utf-8")


print(paste0(Sys.time()," : Starting to get current coporation list"))

availableDate<-getLastBizdayofMonth(3)
if(month(Sys.Date())==month(availableDate[2])) {
  availableDate<-availableDate[1]
} else{
  availableDate<-availableDate[2]
}
day<-str_remove_all(availableDate,"-")
df<-KRXDataMerge(day)
corpTable<-as.data.table(df)

#지금까지 등록되어있는 기업정보 구하기
corpList<-dbGetQuery(conn,SQL("select distinct 종목코드 from metainfo.월별기업정보"))$종목코드
corpList<-unique(c(corpList,corpTable$종목코드))

print(paste0(Sys.time()," : Starting to get FS"))
#최신 재무제표 받기
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

dbWriteTable(conn,SQL("metainfo.분기재무제표"),fsQ,overwrite=TRUE,row.names=FALSE)
dbWriteTable(conn,SQL("metainfo.연간재무제표"),fsY,overwrite=TRUE,row.names=FALSE)



#전월 말 날짜 구하기
print(paste0(Sys.time()," : Starting to get date"))
latestDate<-dbGetQuery(conn,SQL("select max(일자) from metainfo.월별기업정보"))[,1]

<<<<<<< HEAD
if(latestDate!=availableDate){
  #전달 말 등록된 기업정보

=======
print(paste0(Sys.time()," : Starting to get current coporation list"))
day<-str_remove_all(availableDate,"-")
#전달 말 등록된 기업정보
df<-KRXDataMerge(day)
corpTable<-as.data.table(df)

#지금까지 등록되어있는 기업정보 구하기
corpList<-dbGetQuery(conn,SQL("select distinct 종목코드 from metainfo.월별기업정보"))$종목코드
corpList<-unique(c(corpList,corpTable$종목코드))

print(paste0(Sys.time()," : Starting to get FS"))
#최신 재무제표 받기
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

newfsQ<-fsetdiff(fsQ,FfsQ[,-'등록일자'])
newfsY<-fsetdiff(fsY,FfsY[,-'등록일자'])
newfsQ$등록일자<-Sys.Date()
newfsY$등록일자<-Sys.Date()

names(newfsQ)<-names(FfsQ)
names(newfsY)<-n
fsY<-rbind(FfsY,newfsY)
fsQ<-rbind(FfsQ,newfsQ)

dbWriteTable(conn,SQL("metainfo.분기재무제표"),newfsQ,append=TRUE,row.names=FALSE)
dbWriteTable(conn,SQL("metainfo.연간재무제표"),newfsY,append=TRUE,row.names=FALSE)

print(paste0(Sys.time()," : Complete updating FS"))

#현재 날짜가 기록된 날짜보다 늦을 경우
if(latestDate!=availableDate){
>>>>>>> 2f9028dea9ca8e7a59708c72362670b782dd80c0
  print(paste0(Sys.time()," : Starting to summarize financial data"))
  fs<-NULL
  for(i in 1:nrow(corpTable)){
    oldN<-NROW(fs)
    fs<-rbind(fs,cleanDataAndExtractEntitiesFromFS2(corpTable[i,],fsY,fsQ))
    if(oldN<NROW(fs)) print(paste0(Sys.time()," : [",i,"/",nrow(corpTable),"] success: Summarizing Data of ",corpTable[i,]$종목코드))
  }
  
  dbDisconnect(conn)
  conn<-dbConnect(RPostgres::Postgres(),dbname=dbConfig$database,host=dbConfig$host,port=dbConfig$port,user=dbConfig$user,password=dbConfig$passwd)
  
  dbWriteTable(conn,SQL("metainfo.월별기업재무요약"),fs,append=TRUE)
  dbWriteTable(conn,SQL("metainfo.기업정보"),corpTable,append=TRUE)
  print(paste0(Sys.time()," : Finished"))
}






