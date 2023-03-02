#Sys.setlocale('LC_ALL','en_US.UTF-8')
source("~/StockTradebot/Rscript/Han2FunctionList.R")
pkg = c('RPostgres', 'DBI','stringr')
new.pkg = pkg[!(pkg %in% installed.packages()[, "Package"])]
if (length(new.pkg)) {
  install.packages(new.pkg, dependencies = TRUE)}
sapply(pkg,library,character.only=T)

config<-fromJSON("~/config.json")
dbconfig<-config$database
conn<-dbConnect(RPostgres::Postgres(),dbname=dbconfig$database,host=dbconfig$host,port=dbconfig$port,user=dbconfig$user,password=dbconfig$passwd)

#apiConfig<-config$api$config$dev
apiConfig<-config$api$config$prod

#account<-config$api$account$dev
account<-config$api$account$prod$main

#재무제표 이상한 기업 우선 거르기
#최근 2년 간 분기재무제표에서 매출, 매출원가가 음수인 경우가 한 번이라도 있다면 목록에서 제거
prevDate<-str_replace(substring(Sys.Date()-730,1,7),'-','.')
sql<-sprintf("select * from metainfo.월별기업정보 a
where 일자=(select max(일자) from metainfo.월별기업정보)
and not exists (
select 1 from metainfo.분기재무제표 c
where 일자>'%s' 
and (계정='매출액' or 계정='매출원가')
and 값<0 and a.종목코드=c.종목코드
)",prevDate) 

corpTable<-dbGetQuery(conn,SQL(sql))
setDT(corpTable)

filter<-function(data){
  dat<-data[관리여부!="관리종목"]
  dat<-dat[is.na(매출총이익)==F]
  dat<-dat[is.na(영업활동으로인한현금흐름)==F]
  dat<-dat[is.na(자산)==F]
  dat<-dat[매출액>=매출총이익] #매출원가가 -인 경우 제외
  dat<-dat[자본>자본금] #자본잠식상태가 아님
  dat<-dat[영업활동으로인한현금흐름>0]
  dat<-dat[매출총이익>0]
  dat<-dat[is.na(유상증자)] #최근 1년간 유상증자 안함
  return(dat)
}
orderData<-function(data){
  data[,SIZERANK:=rank(시가총액)]
  data[,QUALITYRANK:=rank(-(매출총이익+영업활동으로인한현금흐름)/자산)]
  data[,VALUERANK:=0]
  data[,MOMENTUMRANK:=0]
  data[,TOTALRANK:=QUALITYRANK+SIZERANK+VALUERANK+MOMENTUMRANK]
  setorder(data,TOTALRANK,QUALITYRANK,SIZERANK)
  return(data)
}

stocknum<-15
goalBalanceSum<-63000000

output<-filter(corpTable)
output<-orderData(output)
output<-output[1:stocknum]
output$일자<-as.character(output$일자)

print("Selected stocks")
print(output)

goalBalanceSheet<-output[,c('종목코드','종목명')]
goalBalanceSheet$목표비율<-1
goalBalanceSheet$목표금액<-goalBalanceSheet[,목표비율/sum(목표비율)]*goalBalanceSum

currentBalance<-getBalancesheet(apiConfig,account)
totalBalanceSum<-currentBalance$summary$tot_evlu_amt

if(currentBalance$rt_cd!='0' | currentBalance$status_code!='200'){
  stop("Fail to get current balance. Stop script")
}

if(!is.null(currentBalance$sheet)){
  currentBalanceSheet<-currentBalance$sheet[,c('pdno','prdt_name','hldg_qty','evlu_amt')]  
  names(currentBalanceSheet)<-c('종목코드','종목명','보유수량','평가금액')
  combinedSheet<-merge(goalBalanceSheet,currentBalanceSheet,by=c('종목코드','종목명'),all=T)
} else{
  totalBalanceSum<-0
  combinedSheet<-goalBalanceSheet
  combinedSheet[,c('평가금액','보유수량'):=0]
}
combinedSheet[,평가금액:=as.numeric(평가금액)]
combinedSheet[,보유수량:=as.numeric(보유수량)]
combinedSheet[is.na(목표금액)]$목표금액<-0
combinedSheet[is.na(평가금액)]$평가금액<-0
combinedSheet[is.na(보유수량)]$보유수량<-0

combinedSheet<-combinedSheet[,c('종목코드','종목명','보유수량','목표금액','평가금액')]

print("Final stock list")
print(combinedSheet)

print("Sell orders")
sellRes<-orderStocks(apiConfig,account,combinedSheet[평가금액>목표금액]) #매도 먼저
print("Buy orders")
buyRes<-orderStocks(apiConfig,account,combinedSheet[평가금액<목표금액]) #매수 다음

res<-rbind(sellRes,buyRes)
