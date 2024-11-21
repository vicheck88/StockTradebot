#setwd("/home/pi/stockInfoCrawler/StockTradebot/script")
setwd("/Users/chhan/StockTradebot/script")
source("~/StockTradebot/script/Han2FunctionList.R") #macOS에서 읽는 경우
source("~/StockTradebot/script/telegramAPI.R") #macOS에서 읽는 경우
#source("~/stockInfoCrawler/StockTradebot/script/Han2FunctionList.R") #라즈베리에서 읽는 경우
#source("~/stockInfoCrawler/StockTradebot/script/telegramAPI.R") #라즈베리에서 읽는 경우

pkg = c('data.table','xts','quantmod','stringr','timeDate','lubridate')
new.pkg = pkg[!(pkg %in% installed.packages()[, "Package"])]
if (length(new.pkg)) {
  install.packages(new.pkg, dependencies = TRUE)}
sapply(pkg,library,character.only=T)

newYorkTime<-with_tz(Sys.time(),"America/New_York")
weekday<-as.POSIXlt(newYorkTime)$wday
holidays<-with_tz(holidayNYSE(year = getRmetricsOptions("currentYear"))@Data,"America/New_York")

if(weekday %in% c(0,6) | as.Date(newYorkTime) %in% as.Date(holidays)){
  stop("Today is weekend, or holiday")
}

config<-fromJSON("~/config.json")
#apiConfig<-config$api$config$dev
apiConfig<-config$api$config$prod
#account<-config$api$account$dev
account<-config$api$account$prod$main



symbols = c('TQQQ','QQQ','SPY')
getSymbols(symbols, src = 'yahoo')
prices = do.call(cbind,lapply(symbols, function(x) Ad(get(x))))
prices<-as.data.table(prices)

token<-getToken(apiConfig,account)

qqqPrice<-getCurrentOverseasPrice(apiConfig,account,token,"QQQ",'NAS')
tqqqPrice<-getCurrentOverseasPrice(apiConfig,account,token,"TQQQ",'NAS')
spyPrice<-getCurrentOverseasPrice(apiConfig,account,token,'SPY','AMS')
boxxPrice<-getCurrentOverseasPrice(apiConfig,account,token,"BOXX",'AMS')

prices<-as.xts(rbind(prices,data.table(index=Sys.Date(),TQQQ.Adjusted=tqqqPrice,QQQ.Adjusted=qqqPrice,SPY.Adjusted=spyPrice)))


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
print(currentPrice)
#currentDisparity<-currentPrice[,lapply(.SD,function(y) 100*TQQQ.Adjusted/y-100)]
currentDisparity<-currentPrice[,100*QQQ.Adjusted/QQQ.Adjusted.MA.200-100]



currentBalance<-getPresentOverseasBalancesheet(token,apiConfig,account)
if(currentBalance$status_code!='200'){
  stop("Fail to get current balance. Stop script")
}


totalBalanceSum<-floor((as.numeric(currentBalance$summary2[,"tot_asst_amt"])-as.numeric(currentBalance$summary2[,"wdrw_psbl_tot_amt"]))/as.numeric(currentBalance$summary[,"frst_bltn_exrt"]))
curTQQQRatio<-0
if(nrow(currentBalance$sheet)>0){
  curTQQQBalance<-as.numeric(currentBalance$sheet[pdno=="TQQQ",frcr_evlu_amt2])
  curTQQQRatio<-curTQQQBalance/totalBalanceSum
}

#TQQQratio
#TQQQGoalRatio<-floor(currentDisparity$TQQQ.Adjusted.MA.200)*0.5
TQQQGoalRatio<-abs(floor(currentDisparity)*0.5)
TQQQGoalRatio<-min(1,TQQQGoalRatio)
TQQQGoalRatio<-max(0,TQQQGoalRatio)

if(sign(currentDisparity)>=0) TQQQGoalRatio<-max(TQQQGoalRatio,curTQQQRatio)
if(sign(currentDisparity)<0) TQQQGoalRatio<-min(TQQQGoalRatio,curTQQQRatio)


#sendMessage
message<-paste0("SPY price: ",currentPrice$SPY.Adjusted)
message<-paste0(message,"\nQQQ price: ",currentPrice$QQQ.Adjusted)
message<-paste0(message,"\nTQQQ price: ",currentPrice$TQQQ.Adjusted)
sendMessage(message)
message<-paste0("\nSPY 200 MA: ",round(currentPrice$SPY.Adjusted.MA.200,2))
message<-paste0(message,"\nQQQ 200 MA: ",round(currentPrice$QQQ.Adjusted.MA.200,2))
message<-paste0(message,"\nTQQQ 200 MA: ",round(currentPrice$TQQQ.Adjusted.MA.200,2))
sendMessage(message)
message<-paste0("\nSPY Disparity: ", round(currentPrice[,100*SPY.Adjusted/SPY.Adjusted.MA.200-100],2))
message<-paste0(message,"\nQQQ Disparity: ", round(currentPrice[,100*QQQ.Adjusted/QQQ.Adjusted.MA.200-100],2))
message<-paste0(message,"\nTQQQ Disparity: ", round(currentPrice[,100*TQQQ.Adjusted/TQQQ.Adjusted.MA.200-100],2))
sendMessage(message)
message<-paste0("\nToday TQQQ Ratio: ",TQQQGoalRatio)
sendMessage(message)


goalBalanceSum<-totalBalanceSum*TQQQGoalRatio
bondBalanceSum<-totalBalanceSum-goalBalanceSum

goalBalanceSheet<-data.table(종목코드=c('TQQQ'),거래소_현재가='NAS',거래소='NASD',현재가=tqqqPrice,목표금액=goalBalanceSum,signal=sign(currentDisparity),주문구분='00')
goalBalanceSheet<-rbind(goalBalanceSheet,data.table(종목코드=c('BOXX'),거래소_현재가='AMS',거래소='AMEX',현재가=boxxPrice,목표금액=bondBalanceSum,signal=0,주문구분='00'))

if(length(currentBalance$sheet)>0){
  currentBalanceSheet<-currentBalance$sheet[,c('pdno','prdt_name','ovrs_excg_cd','ccld_qty_smtl1','frcr_evlu_amt2','buy_crcy_cd')]  
  names(currentBalanceSheet)<-c('종목코드','종목명','거래소','보유수량','평가금액','매수통화코드')
  combinedSheet<-merge(goalBalanceSheet,currentBalanceSheet,by=c('종목코드','거래소'),all=T)
} else{
  totalBalanceSum<-0
  combinedSheet<-goalBalanceSheet
  combinedSheet[,c('평가금액','보유수량'):=0]
  combinedSheet[,매수통화코드:='USD']
}

combinedSheet[,평가금액:=as.numeric(평가금액)]
combinedSheet[,보유수량:=as.numeric(보유수량)]
combinedSheet[is.na(목표금액)]$목표금액<-0
combinedSheet[is.na(평가금액)]$평가금액<-0
combinedSheet[is.na(보유수량)]$보유수량<-0
combinedSheet[is.na(매수통화코드)]$매수통화코드<-"USD"

combinedSheet<-combinedSheet[(signal>0 & 목표금액>평가금액) | (signal<0 & 목표금액<평가금액) | (signal==0 & 평가금액!=목표금액)]

print("Final stock list")
print(combinedSheet)


sellSheet<-combinedSheet[평가금액>목표금액]
sellRes<-orderOverseasStocks(token,apiConfig,account,sellSheet) #매도 먼저

if(length(sellRes)>0){
  sendMessage("Sell orders")
  for(i in nrow(sellRes)){
    row<-sellRes[i,]
    text<-paste0("rt_cd: ",row$rt_cd," msg_cd: ",row$msg_cd," msg: ",row$msg1," code: ",row$code," qty: ",row$qty," price: ",row$price)
    sendMessage(text,0)
    Sys.sleep(0.04)
  }
  Sys.sleep(30)
}

buySheet<-combinedSheet[평가금액<=목표금액]
buyRes<-orderOverseasStocks(token,apiConfig,account,buySheet) #매수 다음

if(length(buyRes)>0){
  print("Buy orders")
  sendMessage("Buy orders")
  for(i in nrow(buyRes)){
    row<-buyRes[i,]
    text<-paste0("rt_cd: ",row$rt_cd," msg_cd: ",row$msg_cd," msg: ",row$msg1," code: ",row$code," qty: ",row$qty," price: ",row$price)
    sendMessage(text,0)
    Sys.sleep(0.04)
  }
}

revokeToken(apiConfig,account,token)
