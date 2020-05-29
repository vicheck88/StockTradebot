library(RPostgres)
library(DBI)

conn<-dbConnect(RPostgres::Postgres(),dbname='stocks',host='203.243.21.33',port='5432',user='postgres',password='12dnjftod')
#함수 불러돌이기
source("./RQuantFunctionList.R",encoding="utf-8")

#처음 전체 update

year<-as.character(2016:2020)
availableDate<-getLastBizdayofMonth(60)
availableDate<-availableDate[availableDate>'2016-01-01']
availableDate<-str_remove_all(availableDate,"-")
availableDateForFS<-availableDate[substr(availableDate,5,6) %in% c('03','05','08','11')]

#전체 기업 데이터 획득
corpTable<-NULL
for(day in availableDate){
  tryCatch(
    {
      df<-mergeWICSKRX(day)
      df<-subset(df,select=c(10, 1, 4, 3, 5, 6, 7, 9, 17, 18, 11))
      corpTable<-rbind(corpTable,df)
    },
    error=function(e){
      print(paste0("Fail to Read: ",day))
    } 
  )
}
colnames(corpTable)[8]<-"시가총액"
corpTable<-as.data.table(corpTable)

dbWriteTable(conn,SQL("metainfo.기업정보"),corpTable)
corpTable<-as.data.table(dbGetQuery(conn,SQL("select * from metainfo.기업정보")))
#모든 기업의 재무제표 구하기

#corpList<-unique(corpTable$종목코드)
#fsQ<-getAllFS('Q',corpList)
#fsY<-getAllFS('Y',corpList)
#dbWriteTable(conn,SQL("metainfo.연간재무제표"),fsY)
#dbWriteTable(conn,SQL("metainfo.분기재무제표"),fsQ)

#데이터베이스에서 구하기
fsQ<-as.data.table(dbGetQuery(conn,SQL("select * from metainfo.분기재무제표")))
fsY<-as.data.table(dbGetQuery(conn,SQL("select * from metainfo.연간재무제표")))

## sapply 함수 이용 예정
fs<-NULL
for(i in 1:nrow(corpTable)){
  fs<-rbind(fs,cleanDataAndGetFactor(corpTable[i,],fsY,fsQ))
}


dbWriteTable(conn,SQL("metainfo.기업정보"),fs)

