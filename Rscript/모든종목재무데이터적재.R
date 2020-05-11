library(jsonlite)
library(RPostgres)
library(DBI)


#DB 접속
conn<-dbConnect(RPostgres::Postgres(),dbname='stocks',host='203.243.21.33',port='5432',user='postgres',password='12dnjftod')
#현재 기업정보 저장
today<-recentBizDay()
df<-KRXDataMerge(today)
table<-subset(df,select=c(8,1,2,3,4,7,9))
colnames(table)[6]<-"시가총액"
dbWriteTable(conn,SQL("metainfo.기업정보"),table,append=TRUE)
#기업 재무제표 저장

codeList<-table$'종목코드'

dataQList<-getAllFS(today,'Q',codeList)
dataYList<-getAllFS(today,'Y',codeList)


dataQ<-NULL
dataY<-NULL
dataQ<-do.call(rbind,dataQList)
dataY<-do.call(rbind,dataYList)

setDT(dataQ)
setDT(dataY)


for(code in codeList){
  dbWriteTable(conn,SQL("metainfo.분기재무제표"),dataQList[[code]], row.names=FALSE, append=TRUE)
}

dbWriteTable(conn,SQL("metainfo.분기재무제표"),dataQ, row.names=FALSE, append=TRUE)
dbWriteTable(conn,SQL("metainfo.연간재무제표"),dataY, row.names=FALSE, append=TRUE)

