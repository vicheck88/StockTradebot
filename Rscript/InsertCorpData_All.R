library(RPostgres)
library(DBI)

conn<-dbConnect(RPostgres::Postgres(),dbname='stocks',host='119.194.25.19',port='54321',user='postgres',password='12dnjftod')
#함수 불러돌이기
source("./RQuantFunctionList.R",encoding="utf-8")

#처음 전체 update

year<-as.character(2010:2020)
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
      df<-subset(df,select=c("일자","종목코드", "종목명", "시장구분", "산업분류","현재가(종가)","시가총액(원)","주당배당금", "배당수익률","관리여부"))
      corpTable<-rbind(corpTable,df)
    },
    error=function(e){
      print(paste0("Fail to Read: ",day))
    } 
  )
}
colnames(corpTable)[7]<-"시가총액"
setDT(corpTable)

#dbWriteTable(conn,SQL("metainfo.기업정보"),corpTable)
#corpTable<-as.data.table(dbGetQuery(conn,SQL("select * from metainfo.기업정보")))
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
  res<-cleanDataAndExtractEntitiesFromFS(corpTable[i,],fsY,fsQ,FALSE)
  fs<-rbind(fs,res)
  if(!is.null(res)) print(paste0(Sys.time()," : [",i,"/",nrow(corpTable),"] success: calculating Factors of ",corpTable[i,]$종목코드," Date: ",corpTable[i,]$일자))
  #else print(paste0(Sys.time()," : [",i,"/",nrow(corpTable),"] fail: calculating Factors of ",corpTable[i,]$종목코드," Date: ",corpTable[i,]$일자," : return NULL"))
}

dbDisconnect(conn)
conn<-dbConnect(RPostgres::Postgres(),dbname='stocks',host='203.243.21.33',port='5432',user='postgres',password='12dnjftod')

res<-dbWriteTable(conn,SQL("metainfo.월별기업정보"),fs,overwrite=TRUE)
print(paste0(Sys.time()," : Finished"))
