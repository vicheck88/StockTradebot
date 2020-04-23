library(RPostgres)
library(DBI)

conn<-dbConnect(RPostgres::Postgres(),dbname='stocks',host='203.243.21.33',port='5432',user='postgres',password='rlghlsms1qjs!@')
run <- postgresHasDefault()

#함수 불러돌이기
source("./RQuantFunctionList.R",encoding="utf-8")
today<-recentBizDay()

#오늘 주식시장에 등록된 기업 목록, 섹터 정보

#처음 전체 update
#year<-as.character(2000:2020)
#availableDate<-getLastBizdayofMonth(300)
#availableDate[availableDate>'2000-01-01']
#availableDate<-str_remove_all(availableDate,"-")
#availableDate<-availableDate[substr(availableDate,5,6) %in% c('03','05','08','11')]
#availableDate<-availableDate[availableDate>'20000000']


availableDate<-getLastBizdayofMonth(2)
availableDate<-str_remove_all(availableDate,"-")
table<-NULL
for(day in availableDate){
  tryCatch(
    {
      df<-KRXDataMerge(day)
      df<-subset(df,select=c(8,1,2,3,4,7,9))
      table<-rbind(table,df)
    },
    error=function(e){
      print(paste0("Fail to Read: ",day))
    } 
  )
}
colnames(table)[6]<-"시가총액"

priceList<-getPriceList(today,corpList)
corpList <- getAllCorpsCode(today)
stockNumberList<-getStockNumberList(today,corpList)
dataList<-getAllFS(today)
fs<-getAllFactor(today,corpList,dataList,priceList,stockNumberList)


dbWriteTable(conn,SQL("metainfo.기업정보"),table)
