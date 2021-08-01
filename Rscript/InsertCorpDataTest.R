print(paste0(Sys.time()," : Starting Script"))

library(RPostgres)
library(DBI)

conn<-dbConnect(RPostgres::Postgres(),dbname='stocks',host='203.243.21.33',port='5432',user='postgres',password='12dnjftod')
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

print(paste0(Sys.time()," : Starting to get current coporation list"))

<<<<<<< HEAD
  print(paste0(Sys.time()," : Starting to get current coporation list"))
  
  day<-str_remove_all(availableDate,"-")
  #전달 말 등록된 기업정보
  df<-KRXDataMerge(day)
  df<-subset(df,select=c("일자","종목코드", "종목명", "시장구분", "산업분류","현재가(종가)","시가총액(원)","주당배당금", "배당수익률","관리여부"))
  colnames(df)[7]<-"시가총액"
  corpTable<-as.data.table(df)
  
  #지금까지 등록되어있는 기업정보 구하기
  corpList<-dbGetQuery(conn,SQL("select distinct 종목코드 from metainfo.기업정보"))$종목코드
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
  conn<-dbConnect(RPostgres::Postgres(),dbname='stocks',host='203.243.21.33',port='5432',user='postgres',password='12dnjftod')
  
  print(paste0(Sys.time()," : Starting to write FS"))
  FfsY<-data.table(dbGetQuery(conn,SQL("SELECT * from metainfo.연간재무제표")))
  FfsQ<-data.table(dbGetQuery(conn,SQL("SELECT * from metainfo.분기재무제표")))
  
  fsY<-unique(rbind(FfsY,fsY),by=c("종목코드","종류","계정","일자"),fromLast=T)
  fsQ<-unique(rbind(FfsQ,fsQ),by=c("종목코드","종류","계정","일자"),fromLast=T)
  
  dbWriteTable(conn,SQL("test.분기재무제표"),fsQ,overwrite=TRUE,row.names=FALSE)
  dbWriteTable(conn,SQL("test.연간재무제표"),fsY,overwrite=TRUE,row.names=FALSE)
  
  print(paste0(Sys.time()," : Starting to get factor data"))
  fs<-NULL
  for(i in 1:nrow(corpTable)){
    fs<-rbind(fs,cleanDataAndExtractEntitiesFromFS(corpTable[i,],fsY,fsY,TRUE))
    #fs<-rbind(fs,cleanDataAndGetFactor(corpTable[i,],fsY,fsQ,TRUE))
    print(paste0(Sys.time()," : [",i,"/",nrow(corpTable),"] success: calculating Factors of ",corpTable[i,]$종목코드))
  }
  
  dbDisconnect(conn)
  conn<-dbConnect(RPostgres::Postgres(),dbname='stocks',host='203.243.21.33',port='5432',user='postgres',password='12dnjftod')
  
  res<-dbWriteTable(conn,SQL("test.기업정보"),fs,overwrite=TRUE)
  print(paste0(Sys.time()," : Fisished"))
=======
day<-str_remove_all(availableDate,"-")
#전달 말 등록된 기업정보
df<-KRXDataMerge(day)
df<-subset(df,select=c("일자","종목코드", "종목명", "시장구분", "산업분류","현재가(종가)","시가총액(원)","주당배당금", "배당수익률","관리여부"))
colnames(df)[7]<-"시가총액"
corpTable<-as.data.table(df)

#지금까지 등록되어있는 기업정보 구하기
corpList<-dbGetQuery(conn,SQL("select distinct 종목코드 from metainfo.기업정보"))$종목코드
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

fsY[,등록일자:=Sys.Date()]
fsQ[,등록일자:=Sys.Date()]

dbDisconnect(conn)
conn<-dbConnect(RPostgres::Postgres(),dbname='stocks',host='203.243.21.33',port='5432',user='postgres',password='12dnjftod')

print(paste0(Sys.time()," : Starting to write FS"))

FfsY<-data.table(dbGetQuery(conn,SQL("SELECT * from metainfo.연간재무제표")))
FfsQ<-data.table(dbGetQuery(conn,SQL("SELECT * from metainfo.분기재무제표")))

#새로 얻은 데이터와의 차집합 구해서 새로 넣기
fsY<-unique(rbind(FfsY,fsY),by=c("종목코드","종류","계정","일자"),fromLast=T)
fsQ<-unique(rbind(FfsQ,fsQ),by=c("종목코드","종류","계정","일자"),fromLast=T)

dbWriteTable(conn,SQL("test.분기재무제표"),fsQ,overwrite=TRUE,row.names=FALSE)
dbWriteTable(conn,SQL("test.연간재무제표"),fsY,overwrite=TRUE,row.names=FALSE)

print(paste0(Sys.time()," : Starting to get factor data"))
fs<-NULL
for(i in 1:nrow(corpTable)){
  fs<-rbind(fs,cleanDataAndExtractEntitiesFromFS(corpTable[i,],fsY,fsY,TRUE))
  #fs<-rbind(fs,cleanDataAndGetFactor(corpTable[i,],fsY,fsQ,TRUE))
  print(paste0(Sys.time()," : [",i,"/",nrow(corpTable),"] success: calculating Factors of ",corpTable[i,]$종목코드))
}

dbDisconnect(conn)
conn<-dbConnect(RPostgres::Postgres(),dbname='stocks',host='203.243.21.33',port='5432',user='postgres',password='12dnjftod')

res<-dbWriteTable(conn,SQL("test.기업정보"),fs,overwrite=TRUE)
print(paste0(Sys.time()," : Fisished"))
>>>>>>> 2f9028dea9ca8e7a59708c72362670b782dd80c0

