library(RPostgres)
library(DBI)

conn<-dbConnect(RPostgres::Postgres(),dbname='stocks',host='203.243.21.33',port='5432',user='postgres',password='12dnjftod')
#함수 불러돌이기
source("./RQuantFunctionList.R",encoding="utf-8")

#전월 말 날짜 구하기
availableDate<-getLastBizdayofMonth(3)
if(month(Sys.Date())==month(availableDate[2])) {
  availableDate<-availableDate[1]
} else{
  availableDate<-availableDate[2]
  }

day<-str_remove_all(availableDate,"-")

#전달 말 등록된 기업정보

df<-mergeWICSKRX(day)
df<-subset(df,select=c(10, 1, 4, 3, 5, 6, 7, 9, 17, 18, 11))
colnames(df)[8]<-"시가총액"
corpTable<-as.data.table(df)

#지금까지 등록되어있는 기업정보 구하기
corpList<-dbGetQuery(conn,SQL("select distinct 종목코드 from metainfo.기업정보"))$종목코드
corpList<-unique(c(corpList,corpTable$종목코드))

#데이터베이스에서 구하기
fsQ<-as.data.table(dbGetQuery(conn,SQL("select * from metainfo.분기재무제표")))
fsY<-as.data.table(dbGetQuery(conn,SQL("select * from metainfo.연간재무제표")))

#종목별 최신기록일자
maxQ<-fsQ[,.(최신일자=max(일자)),by=종목코드]
maxY<-fsY[,.(최신일자=max(일자)),by=종목코드]

#모든 기업의 가장 최신 재무데이터 구하기
fsQNew<-getAllRecentFS('Q',corpList, maxQ)
fsYNew<-getAllRecentFS('Y',corpList, maxY)

#기록한 재무제표 데이터베이스 저장
dbWriteTable(conn,SQL("metainfo.분기재무제표"),fsQ,append=TRUE,row.names=FALSE)
dbWriteTable(conn,SQL("metainfo.연간재무제표"),fsY,append=TRUE,row.names=FALSE)

#데이터 병합
fsQ<-rbind(fsQ,fsQNew)
fsY<-rbind(fsY,fsYNew)

fs<-NULL
for(i in 1:nrow(corpTable)){
  fs<-rbind(fs,cleanDataAndGetFactor(corpTable[i,],fsY,fsQ))
}

dbWriteTable(conn,SQL("metainfo.기업정보"),table,append=TRUE)
