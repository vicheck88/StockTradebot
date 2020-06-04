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

df<-KRXDataMerge(day)
df<-subset(df,select=c("일자","종목코드", "종목명", "시장구분", "산업분류","현재가(종가)","시가총액(원)","주당배당금", "배당수익률","관리여부"))
colnames(df)[7]<-"시가총액"
corpTable<-as.data.table(df)

#지금까지 등록되어있는 기업정보 구하기
corpList<-dbGetQuery(conn,SQL("select distinct 종목코드 from metainfo.기업정보"))$종목코드
corpList<-unique(c(corpList,corpTable$종목코드))

#데이터베이스에서 구하기
FfsQ<-as.data.table(dbGetQuery(conn,SQL("select * from metainfo.분기재무제표")))
FfsY<-as.data.table(dbGetQuery(conn,SQL("select * from metainfo.연간재무제표")))

fsQ<-getAllFS('Q',corpList)
fsY<-getAllFS('Y',corpList)

fsQNew<-fsetdiff(fsQ,FfsQ)
fsYNew<-fsetdiff(fsY,FfsY)


#기록한 재무제표 데이터베이스 저장
dbWriteTable(conn,SQL("metainfo.분기재무제표"),fsQNew,append=TRUE,row.names=FALSE)
dbWriteTable(conn,SQL("metainfo.연간재무제표"),fsYNew,append=TRUE,row.names=FALSE)

#데이터 병합
fsQ<-rbind(FfsQ,fsQNew)
fsY<-rbind(FfsY,fsYNew)

fs<-NULL
for(i in 1:nrow(corpTable)){
  fs<-rbind(fs,cleanDataAndGetFactor(corpTable[i,],fsY,fsQ))
}

dbWriteTable(conn,SQL("metainfo.기업정보"),fs,append=TRUE)
