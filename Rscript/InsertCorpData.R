print(paste0(Sys.time()," : Starting Script"))

library(RPostgres)
library(DBI)
library(jsonlite)
dbConfig=read_json("./config.json")$database
conn<-dbConnect(RPostgres::Postgres(),dbname=dbConfig$database,host=dbConfig$host,port=dbConfig$port,user=dbConfig$user,password=dbConfig$passwd)
#함수 불러돌이기
source("./RQuantFunctionList.R",encoding="utf-8")

#전월 말 날짜 구하기
print(paste0(Sys.time()," : Starting to get date"))

availableDate<-getLastBizdayofMonth(3)
if(month(Sys.Date())==month(availableDate[2])) {
  availableDate<-availableDate[1]
} else{
  availableDate<-availableDate[2]
}
latestDate<-dbGetQuery(conn,SQL("select max(일자) from metainfo.월별기업정보"))[,1]

cnt<-0
while(TRUE){
  if(cnt==10){
    print("Fail to get corp Data.")
    break
  }
  print(paste0(Sys.time()," : Starting to get current coporation list"))
  day<-str_remove_all(availableDate,"-")
  #전달 말 등록된 기업정보
  df<-KRXDataMerge(day)
  if(is.null(df)) {
    cnt++
    print("Fail to get corp Data. Try again after 10mins")
    Sys.sleep(60*10)
  } else { break }
}
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
names(newfsY)<-names(FfsY)
fsY<-rbind(FfsY,newfsY)
fsQ<-rbind(FfsQ,newfsQ)
fsY$일자<-as.character(fsY$일자)
fsQ$일자<-as.character(fsQ$일자)

dbWriteTable(conn,SQL("metainfo.분기재무제표"),newfsQ,append=TRUE,row.names=FALSE)
dbWriteTable(conn,SQL("metainfo.연간재무제표"),newfsY,append=TRUE,row.names=FALSE)

print(paste0(Sys.time()," : Complete updating FS"))

#현재 날짜가 기록된 날짜보다 늦을 경우
if(latestDate!=availableDate){
  print(paste0(Sys.time()," : Starting to summarize financial data"))
  fs<-NULL
  for(i in 1:nrow(corpTable)){
    oldN<-NROW(fs)
    res<-cleanDataAndExtractEntitiesFromFS(corpTable[i,],fsY,fsQ,TRUE)
    if(!is.null(fs) & !is.null(res)) names(res)<-names(fs)
    fs<-rbind(fs,res)
    if(oldN<NROW(fs)) print(paste0(Sys.time()," : [",i,"/",nrow(corpTable),"] success: Summarizing Data of ",corpTable[i,]$종목코드))
  }
  
  dbDisconnect(conn)
  conn<-dbConnect(RPostgres::Postgres(),dbname=dbConfig$database,host=dbConfig$host,port=dbConfig$port,user=dbConfig$user,password=dbConfig$passwd)
  
  res<-dbWriteTable(conn,SQL("metainfo.월별기업정보"),fs,append=TRUE)
  print(paste0(Sys.time()," : Finished"))
} else{ print(paste0(Sys.time()," : Already updated. Script finished"))}
