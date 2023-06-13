#setwd("/home/pi/stockInfoCrawler/StockTradebot/Rscript")
setwd("/Users/chhan/StockTradebot/Rscript")
source("~/StockTradebot/Rscript/Han2FunctionList.R") #macOS에서 읽는 경우
source("~/StockTradebot/Rscript/telegramAPI.R") #macOS에서 읽는 경우
#source("~/stockInfoCrawler/StockTradebot/Rscript/Han2FunctionList.R") #라즈베리에서 읽는 경우
#source("~/stockInfoCrawler/StockTradebot/Rscript/telegramAPI.R") #라즈베리에서 읽는 경우

pkg = c('data.table','xts','quantmod','stringr','timeDate','lubridate')
new.pkg = pkg[!(pkg %in% installed.packages()[, "Package"])]
if (length(new.pkg)) {
  install.packages(new.pkg, dependencies = TRUE)}
sapply(pkg,library,character.only=T)

newYorkTime<-with_tz(Sys.time(),"America/New_York")
weekday<-as.POSIXlt(newYorkTime)$wday
holidays<-with_tz(holidayNYSE(year = getRmetricsOptions("currentYear"))@Data,"America/New_York")

if(weekday %in% c(0,6) | as.Date(newYorkTime) %in% holidays){
  stop("Today is weekend, or holiday")
}
config<-fromJSON("~/config.json")
#apiConfig<-config$api$config$dev
apiConfig<-config$api$config$prod
#account<-config$api$account$dev
account<-config$api$account$prod$main

tmptoken<-getToken(apiConfig,account)

symbols = c('QQQ')
getSymbols(symbols, src = 'yahoo')
prices = do.call(cbind,lapply(symbols, function(x) Ad(get(x))))
prices<-as.data.table(prices)

currentQQQPrice<-getCurrentOverseasPrice(apiConfig,account,tmptoken,"QQQ",'NAS')
revokeToken(apiConfig,account,tmptoken)
tmptoken<-NULL
prices<-as.xts(rbind(prices,data.table(index=Sys.Date(),QQQ.Adjusted=currentQQQPrice)))

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
currentDisparity<-currentPrice[,lapply(.SD,function(y) 100*QQQ.Adjusted/y-100)]


#TQQQratio
TQQQGoalRatio<-floor(currentDisparity$QQQ.Adjusted.MA.200)*0.5
TQQQGoalRatio<-min(1,TQQQGoalRatio)
TQQQGoalRatio<-max(0,TQQQGoalRatio)

currentBalance<-getPresentOverseasBalancesheet(apiConfig,account)
if(currentBalance$status_code!='200'){
  stop("Fail to get current balance. Stop script")
}

totalBalanceSum<-as.numeric(currentBalance$summary[crcy_cd=="USD",frcr_dncl_amt_2])
if(nrow(currentBalance$sheet)>0){
  totalBalanceSum<-totalBalanceSum+sum(as.numeric(currentBalance$sheet[buy_crcy_cd=="USD",frcr_evlu_amt2]))
}
goalBalanceSum<-totalBalanceSum*TQQQGoalRatio
goalBalanceSheet<-data.table(종목코드=c('TQQQ'),거래소_현재가='NAS',거래소='NASD',목표금액=goalBalanceSum,signal=sign(currentDisparity$QQQ.Adjusted.MA.200))

if(nrow(currentBalance$sheet)>0){
  currentBalanceSheet<-currentBalance$sheet[,c('pdno','prdt_name','ovrs_excg_cd','ccld_qty_smtl1','frcr_evlu_amt2','buy_crcy_cd')]  
  names(currentBalanceSheet)<-c('종목코드','종목명','거래소','보유수량','평가금액','매수통화코드')
  combinedSheet<-merge(goalBalanceSheet,currentBalanceSheet,by=c('종목코드','거래소'),all=T)
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

combinedSheet<-combinedSheet[(signal>0 & 목표금액>평가금액) | (signal<0 & 목표금액<평가금액)]
combinedSheet[,주문구분:=34]
print("Final stock list")
print(combinedSheet)

if(nrow(combinedSheet)>0){
  sendMessage("Stocks to buy")
  for(i in 1:nrow(combinedSheet)){
    row<-combinedSheet[i,]
    text<-paste0("code: ",row$종목코드," name: ",row$종목명," qty: ",row$보유수량," goalPrice: ",row$목표금액," curPrice: ",row$평가금액)
    sendMessage(text,0)
    Sys.sleep(0.04)
  }
  
  
  print("Sell orders")
  sellSheet<-combinedSheet[평가금액>목표금액]
  sellRes<-orderOverseasStocks(apiConfig,account,sellSheet) #매도 먼저
  
  sendMessage("Sell orders")
  for(i in nrow(sellRes)){
    row<-sellRes[i,]
    text<-paste0("rt_cd: ",row$rt_cd," msg_cd: ",row$msg_cd," msg: ",row$msg1," code: ",row$code," qty: ",row$qty," price: ",row$price)
    sendMessage(text,0)
    Sys.sleep(0.04)
  }
  
  
  print("Buy orders")
  buySheet<-combinedSheet[평가금액<목표금액]
  buyRes<-orderOverseasStocks(apiConfig,account,buySheet) #매수 다음
  sendMessage("Buy orders")
  for(i in nrow(buyRes)){
    row<-buyRes[i,]
    text<-paste0("rt_cd: ",row$rt_cd," msg_cd: ",row$msg_cd," msg: ",row$msg1," code: ",row$code," qty: ",row$qty," price: ",row$price)
    sendMessage(text,0)
    Sys.sleep(0.04)
  }
  
  
  print("failed stocks")
  if(!is.null(sellRes)) print(sellRes[rt_cd!='0'])
  if(!is.null(buyRes)) print(buyRes[rt_cd!='0'])
  
  cnt<-0
  failNum<-nrow(buyRes[rt_cd!='0'])
  rebuySheet<-buySheet
  rebuyRes<-buyRes
  while(failNum>0 & cnt<=10){
    cnt<-cnt+1
    rebuySheet<-rebuySheet[rebuyRes[rt_cd!='0']$idx]
    rebuyRes<-orderStocks(apiConfig,account,rebuySheet)
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
  
}




