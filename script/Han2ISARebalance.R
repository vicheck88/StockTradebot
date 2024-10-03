#Sys.setlocale('LC_ALL','en_US.UTF-8')
source("~/StockTradebot/script/RQuantFunctionList.R") #macOS에서 읽는 경우
source("~/StockTradebot/script/Han2FunctionList.R") #macOS에서 읽는 경우
source("~/StockTradebot/script/telegramAPI.R") #macOS에서 읽는 경우

#source("~/stockInfoCrawler/StockTradebot/script/RQuantFunctionList.R") #macOS에서 읽는 경우
#source("~/stockInfoCrawler/StockTradebot/script/Han2FunctionList.R") #라즈베리에서 읽는 경우
#source("~/stockInfoCrawler/StockTradebot/script/telegramAPI.R") #라즈베리에서 읽는 경우


pkg = c('data.table','xts','quantmod','stringr','timeDate','lubridate')
new.pkg = pkg[!(pkg %in% installed.packages()[, "Package"])]
if (length(new.pkg)) {
  install.packages(new.pkg, dependencies = TRUE)}
sapply(pkg,library,character.only=T)

today<-str_replace_all(Sys.Date(),"-","")

if(wday(Sys.Date()) %in% c(1,7)) stop("Weekend")
if(isHoliday(today)) stop("Holiday")

config<-fromJSON("~/config.json")
#apiConfig<-config$api$config$dev
apiConfig<-config$api$config$prod

#account<-config$api$account$dev
account<-config$api$account$prod$isa

token<-getToken(apiConfig,account)
if(isKoreanTradeOpen(token,apiConfig,account,today)=="N") stop("Market closed")

cancelResult<-cancelAllOrders(apiConfig,account,token)
for(res in cancelResult) sendMessage(res)

trackCode<-'379810'
prices<-adjustedPriceFromNaver('day',200,trackCode)
averagePrice<-mean(prices[,1])
currentPrice<-tail(prices,1)[,1]
currentDisparity<-100*currentPrice/averagePrice-100

nasdaqLevCode<-'418660' #TIGER 미국나스닥100레버리지(합성)
sofrCode<-'456880' #ACE 미국달러SOFR금리(합성)

currentNasdaqPrice<-getCurrentPrice(apiConfig,account,token,nasdaqLevCode)
currentSofrPrice<-getCurrentPrice(apiConfig,account,token,sofrCode)

#disp 1 ~ 2: 0.5
#disp 2 ~ 20: 1
#disp 20 ~ : 0

goalRatio<-abs(floor(currentDisparity)*0.5)
goalRatio<-min(1,goalRatio)
goalRatio<-max(0,goalRatio)
if(currentDisparity>20) goalRatio<-0


currentBalance<-getBalancesheet(token,apiConfig,account)

if(currentBalance$status_code!='200'){
  stop("Fail to get current balance. Stop script")
}

totalBalanceSum<-currentBalance$sheet[,sum(as.numeric(evlu_amt))]+getOrderableAmount(apiConfig,account,token,nasdaqLevCode)

#totalBalanceSum<-as.numeric(currentBalance$summary$tot_evlu_amt)
#orderableAmount<-getOrderableAmount(apiConfig,account,token,nasdaqLevCode)

goalBalanceSum<-totalBalanceSum*goalRatio
bondBalanceSum<-totalBalanceSum-goalBalanceSum

goalBalanceSheet<-data.table(종목코드=nasdaqLevCode,종목명='TIGER 미국나스닥100레버리지(합성)',현재가=currentNasdaqPrice,목표금액=goalBalanceSum,signal=sign(currentDisparity),주문구분='00')
goalBalanceSheet<-rbind(goalBalanceSheet,data.table(종목코드=sofrCode,종목명='ACE 미국달러SOFR금리(합성)',현재가=currentSofrPrice,목표금액=bondBalanceSum,signal=0,주문구분='00'))


if(length(currentBalance$sheet)>0){
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

combinedSheet<-combinedSheet[(signal>0 & 목표금액>평가금액) | (signal<0 & 목표금액<평가금액) | (signal==0 & 평가금액!=목표금액)]

combinedSheet<-combinedSheet[,c('종목코드','종목명','보유수량','목표금액','평가금액')]

sendMessage("Stocks to buy")
for(i in 1:nrow(combinedSheet)){
  row<-combinedSheet[i,]
  text<-paste0("code: ",row$종목코드," name: ",row$종목명," qty: ",row$보유수량," goalPrice: ",row$목표금액," curPrice: ",row$평가금액)
  sendMessage(text,0)
  Sys.sleep(0.04)
}

sellSheet<-combinedSheet[평가금액>목표금액]
sellRes<-orderStocks(token,apiConfig,account,sellSheet) #매도 먼저

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
buyRes<-orderStocks(token,apiConfig,account,buySheet) #매수 다음
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
