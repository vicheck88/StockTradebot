#Sys.setlocale('LC_ALL','en_US.UTF-8')
source("~/StockTradebot/Rscript/Han2FunctionList.R") #macOS에서 읽는 경우
source("~/StockTradebot/Rscript/telegramAPI.R") #macOS에서 읽는 경우
#source("~/stockInfoCrawler/StockTradebot/Rscript/Han2FunctionList.R") #라즈베리에서 읽는 경우
#source("~/stockInfoCrawler/StockTradebot/Rscript/telegramAPI.R") #라즈베리에서 읽는 경우

pkg = c('data.table','xts','quantmod','stringr','timeDate','lubridate')

new.pkg = pkg[!(pkg %in% installed.packages()[, "Package"])]
if (length(new.pkg)) {
  install.packages(new.pkg, dependencies = TRUE)}
sapply(pkg,library,character.only=T)

config<-fromJSON("~/config.json")
#apiConfig<-config$api$config$dev
apiConfig<-config$api$config$prod

#account<-config$api$account$dev
account<-config$api$account$prod$isa

today<-str_replace_all(Sys.Date(),"-","")
token<-getToken(apiConfig,account)
if(isKoreanHoliday(token,apiConfig,account,today)=="N") stop("Market closed")

symbols = c('QQQ')
getSymbols(symbols, src = 'yahoo')
prices = do.call(cbind,lapply(symbols, function(x) Ad(get(x))))
prices<-as.data.table(prices)

movingAvg<-NULL
for(i in c(5,10,20,30,60,100,200)){
  tbl<-as.xts(prices)
  tbl<-do.call(cbind,lapply(tbl,function(y)rollmean(y,i,align='right')))
  names(tbl)<-paste0(names(tbl),".MA.",i)
  movingAvg<-cbind(movingAvg,tbl)
}
priceWithMA<-cbind(prices,movingAvg)
priceWithMA<-as.data.table(priceWithMA)

currentPrice<-tail(priceWithMA,1)
currentPrice<-currentPrice[,-1]
currentDisparity<-currentPrice[,100*QQQ.Adjusted/QQQ.Adjusted.MA.200-100]

nasdaqCode<-'418660' #tiger 나스닥 레버리지
sofrCode<-'456610' #tiger sofr

currentNasdaqPrice<-getCurrentPrice(apiConfig,account,token,nasdaqCode)
currentSofrPrice<-getCurrentPrice(apiConfig,account,token,sofrCode)

goalRatio<-floor(currentDisparity)*0.5
goalRatio<-min(1,goalRatio)
goalRatio<-max(0,goalRatio)

currentBalance<-getBalancesheet(token,apiConfig,account)
if(currentBalance$status_code!='200'){
  stop("Fail to get current balance. Stop script")
}

totalBalanceSum<-as.numeric(currentBalance$summary$tot_evlu_amt)

goalBalanceSum<-totalBalanceSum*goalRatio
bondBalanceSum<-totalBalanceSum-goalBalanceSum

goalBalanceSheet<-data.table(종목코드=nasdaqCode,종목명='tiger 나스닥 레버리지',현재가=currentNasdaqPrice,목표금액=goalBalanceSum,signal=sign(currentDisparity),주문구분='00')
goalBalanceSheet<-rbind(goalBalanceSheet,data.table(종목코드=sofrCode,종목명='tiger sofr',현재가=currentSofrPrice,목표금액=bondBalanceSum,signal=0,주문구분='00'))


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

sendMessage("Stocks to buy")
for(i in 1:nrow(combinedSheet)){
  row<-combinedSheet[i,]
  text<-paste0("code: ",row$종목코드," name: ",row$종목명," qty: ",row$보유수량," goalPrice: ",row$목표금액," curPrice: ",row$평가금액)
  sendMessage(text,0)
  Sys.sleep(0.04)
}


print("Sell orders")

sellSheet<-combinedSheet[평가금액>목표금액]
sellRes<-orderStocks(token,apiConfig,account,sellSheet) #매도 먼저

sendMessage("Sell orders")
for(i in nrow(sellRes)){
  row<-sellRes[i,]
  text<-paste0("rt_cd: ",row$rt_cd," msg_cd: ",row$msg_cd," msg: ",row$msg1," code: ",row$code," qty: ",row$qty," price: ",row$price)
  sendMessage(text,0)
  Sys.sleep(0.04)
}


print("Buy orders")
buySheet<-combinedSheet[평가금액<목표금액]
buyRes<-orderStocks(token,apiConfig,account,buySheet) #매수 다음
sendMessage("Buy orders")
for(i in nrow(buyRes)){
  row<-buyRes[i,]
  text<-paste0("rt_cd: ",row$rt_cd," msg_cd: ",row$msg_cd," msg: ",row$msg1," code: ",row$code," qty: ",row$qty," price: ",row$price)
  sendMessage(text,0)
  Sys.sleep(0.04)
}


print("failed stocks")
print(sellRes[rt_cd!='0'])
print(buyRes[rt_cd!='0'])

cnt<-0
failNum<-nrow(buyRes[rt_cd!='0'])
rebuySheet<-buySheet
rebuyRes<-buyRes
while(failNum>0 & cnt<=10){
  cnt<-cnt+1
  rebuySheet<-rebuySheet[rebuyRes[rt_cd!='0']$idx]
  rebuyRes<-orderStocks(token,apiConfig,account,rebuySheet)
  for(i in nrow(rebuyRes)){
    sendMessage("Buy orders")
    row<-rebuyRes[i,]
    text<-paste0("rt_cd: ",row$rt_cd," msg_cd: ",row$msg_cd," msg: ",row$msg1," code: ",row$code," qty: ",row$qty," price: ",row$price)
    sendMessage(text,0)
    Sys.sleep(0.04)
  }
  failNum<-nrow(rebuyRes[rt_cd!='0'])
  Sys.sleep(30)
}

res<-rbind(sellRes,buyRes)
revokeToken(apiConfig,account,token)
