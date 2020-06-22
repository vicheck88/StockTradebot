library(RPostgres)
library(DBI)

conn<-dbConnect(RPostgres::Postgres(),dbname='stocks',host='203.243.21.33',port='5432',user='postgres',password='12dnjftod')
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

corpList<-unique(corpTable$종목코드)
fsQ<-getAllFS('Q',corpList)
fsY<-getAllFS('Y',corpList)

#데이터베이스에서 구하기
FfsQ<-as.data.table(dbGetQuery(conn,SQL("select * from metainfo.분기재무제표")))
FfsY<-as.data.table(dbGetQuery(conn,SQL("select * from metainfo.연간재무제표")))

Ydiff<-fsetdiff(fsY,FfsY)
Qdiff<-fsetdiff(fsQ,FfsQ)

fsQ<-funion(FfsQ,Qdiff)
fsY<-funion(FfsY,Ydiff)

dbWriteTable(conn,SQL("metainfo.분기재무제표"),fsQ,overwrite=TRUE,row.names=FALSE)
dbWriteTable(conn,SQL("metainfo.연간재무제표"),fsY,overwrite=TRUE,row.names=FALSE)

fs<-NULL
for(i in 1:nrow(corpTable)){
  fs<-rbind(fs,cleanDataAndGetFactor(corpTable[i,],fsY,fsQ))
}


dbWriteTable(conn,SQL("metainfo.기업정보"),fs,overwrite=TRUE)

