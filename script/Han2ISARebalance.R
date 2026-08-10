#Sys.setlocale('LC_ALL','en_US.UTF-8')
source("~/StockTradebot/script/RQuantFunctionList.R") #라즈베리에서 읽는 경우
source("~/StockTradebot/script/Han2FunctionList.R") #라즈베리에서 읽는 경우
source("~/StockTradebot/script/telegramAPI.R") #라즈베리에서 읽는 경우

#source("~/stockInfoCrawler/StockTradebot/script/RQuantFunctionList.R") #macOS에서 읽는 경우
#source("~/stockInfoCrawler/StockTradebot/script/Han2FunctionList.R") #macOS에서 읽는 경우
#source("~/stockInfoCrawler/StockTradebot/script/telegramAPI.R") #macOS에서 읽는 경우


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

symbols = c('QQQ','SPY','SOXX','MAGS')
getSymbols(symbols, src = 'yahoo')
qqqPrices = tail(Ad(QQQ),200)
spyPrices = tail(Ad(SPY),200)
soxxPrices = tail(Ad(SOXX),200)
magsPrices = tail(Ad(MAGS),200)
currentQQQPrice=as.numeric(tail(qqqPrices,1))
currentSPYPrice=as.numeric(tail(spyPrices,1))
currentSOXXPrice=as.numeric(tail(soxxPrices,1))
currentMAGSPrice=as.numeric(tail(magsPrices,1))
QQQ.Adjusted.MA.200<-mean(qqqPrices)
SPY.Adjusted.MA.200<-mean(spyPrices)
SOXX.Adjusted.MA.200<-mean(soxxPrices)
MAGS.Adjusted.MA.200<-mean(magsPrices)
QQQcurrentDisparity<-(100*currentQQQPrice/QQQ.Adjusted.MA.200)-100
SPYcurrentDisparity<-(100*currentSPYPrice/SPY.Adjusted.MA.200)-100
SOXXcurrentDisparity<-(100*currentSOXXPrice/SOXX.Adjusted.MA.200)-100
MAGScurrentDisparity<-(100*currentMAGSPrice/MAGS.Adjusted.MA.200)-100



nasdaqLevCode<-'418660' #TIGER 미국나스닥100레버리지(합성)
top7LevCode<-'465610' #ACE 미국빅테크TOP7 Plus레버리지(합성)
semiconductorLevCode<-'423920' #TIGER 미국필라델피아반도체레버리지(합성)
sofrCode<-'456880' #ACE 미국달러SOFR금리(합성)
highYieldCode<-'468380' #KODEX iShares미국하이일드액티브

currentTop7LevPrice<-getCurrentPrice(apiConfig,account,token,top7LevCode)
currentNasdaqLevPrice<-getCurrentPrice(apiConfig,account,token,nasdaqLevCode)
currentSemiconductorLevPrice<-getCurrentPrice(apiConfig,account,token,semiconductorLevCode)
currentSofrPrice<-getCurrentPrice(apiConfig,account,token,sofrCode)
currentHighyieldPrice<-getCurrentPrice(apiConfig,account,token,highYieldCode)

currentBalance<-getBalancesheet(token,apiConfig,account)

if(currentBalance$status_code!='200'){
  stop("Fail to get current balance. Stop script")
}

totalBalanceSum<-currentBalance$sheet[,sum(as.numeric(evlu_amt))]+getOrderableAmount(apiConfig,account,token,nasdaqLevCode)
curStockRatio<-0
if(nrow(currentBalance$sheet)>0){
  curStockBalance<-sum(as.numeric(currentBalance$sheet[pdno %in% c('418660','465610','423920'),evlu_amt]))
  if(length(curStockBalance)>0) curStockRatio<-curStockBalance/totalBalanceSum
}


# QQQ 괴리율로 전체 주식 비중 결정
stockRatio<- 0.5*(ifelse(QQQcurrentDisparity>0, ceiling(QQQcurrentDisparity), floor(QQQcurrentDisparity)))
if(stockRatio>=1) {
  stockRatio<-1
}else if(stockRatio<=-1){
    stockRatio<-0
}else if(stockRatio<0){
    stockRatio<-min(abs(stockRatio),curStockRatio)
} else{
    stockRatio<-max(abs(stockRatio),curStockRatio)
}

# QQQ 괴리율 15~25% 구간에서 전체 주식 비중을 점진적으로 축소
overheatRatio<-max(0,min(1,(25-QQQcurrentDisparity)/10))
# 과열로 주식 비중이 0이 된 뒤에는 QQQ 괴리율이 20% 이하가 될 때까지 재진입하지 않음
if(curStockRatio==0 && QQQcurrentDisparity>20) overheatRatio<-0
stockRatio<-stockRatio*overheatRatio

# 위성종목 괴리율에서 QQQ 괴리율을 뺀 상대 강도로 위성 비중 결정
top7Spread<-MAGScurrentDisparity-QQQcurrentDisparity
semiconductorSpread<-SOXXcurrentDisparity-QQQcurrentDisparity

# MAGS: 8~10%p에서 최대 20%, 15%p에서 0%
top7SatelliteRatio<-max(0,min(0.2,top7Spread/8*0.2,(15-top7Spread)/5*0.2))
# SOXX: 10%p 이상에서 최대 30%
semiconductorSatelliteRatio<-max(0,min(0.3,semiconductorSpread/10*0.3))

if(top7Spread>=semiconductorSpread){
  top7InvestRatio<-top7SatelliteRatio*stockRatio
  semiconductorInvestRatio<-0
} else{
  top7InvestRatio<-0
  semiconductorInvestRatio<-semiconductorSatelliteRatio*stockRatio
}
nasdaqInvestRatio<-stockRatio-top7InvestRatio-semiconductorInvestRatio


if(hour(Sys.time())==12){
  message<-paste0("QQQ 가격: ",round(currentQQQPrice,2)," | 200 MA: ",round(QQQ.Adjusted.MA.200,2)," | 괴리율: ",round(QQQcurrentDisparity,2),"%\n")
  message<-paste0(message,"SPY 가격: ",round(currentSPYPrice,2)," | 200 MA: ",round(SPY.Adjusted.MA.200,2)," | 괴리율: ",round(SPYcurrentDisparity,2),"%\n")
  message<-paste0(message,"SOXX 가격: ",round(currentSOXXPrice,2)," | 200 MA: ",round(SOXX.Adjusted.MA.200,2)," | 괴리율: ",round(SOXXcurrentDisparity,2),"%\n")
  message<-paste0(message,"MAGS 가격: ",round(currentMAGSPrice,2)," | 200 MA: ",round(MAGS.Adjusted.MA.200,2)," | 괴리율: ",round(MAGScurrentDisparity,2),"%\n\n")
  message<-paste0(message,"SOXX-QQQ 괴리율 차이: ",round(semiconductorSpread,2),"%p\n")
  message<-paste0(message,"MAGS-QQQ 괴리율 차이: ",round(top7Spread,2),"%p\n")
  message<-paste0(message,"전체 주식 비율: ",round(stockRatio,4),"\n\n")
  message<-paste0(message,"TIGER 미국나스닥100레버리지 비율: ",nasdaqInvestRatio,"\n")
  message<-paste0(message,"ACE 미국빅테크TOP7 Plus레버리지 비율: ",top7InvestRatio,"\n")
  message<-paste0(message,"TIGER 미국필라델피아반도체레버리지 비율: ",semiconductorInvestRatio)
  sendMessage(message)
}


nasdaqBalanceSum<-totalBalanceSum*nasdaqInvestRatio
top7BalanceSum<-totalBalanceSum*top7InvestRatio
semiconductorBalanceSum<-totalBalanceSum*semiconductorInvestRatio
bondBalanceSum<-totalBalanceSum-top7BalanceSum-nasdaqBalanceSum-semiconductorBalanceSum

goalBalanceSheet<-data.table(종목코드=top7LevCode,종목명='ACE 미국빅테크TOP7 Plus레버리지(합성)',현재가=currentTop7LevPrice,목표금액=top7BalanceSum,주문구분='00')
goalBalanceSheet<-rbind(goalBalanceSheet,data.table(종목코드=nasdaqLevCode,종목명='TIGER 미국나스닥100레버리지(합성)',현재가=currentNasdaqLevPrice,목표금액=nasdaqBalanceSum,주문구분='00'))
goalBalanceSheet<-rbind(goalBalanceSheet,data.table(종목코드=semiconductorLevCode,종목명='TIGER 미국필라델피아반도체레버리지(합성)',현재가=currentSemiconductorLevPrice,목표금액=semiconductorBalanceSum,주문구분='00'))
goalBalanceSheet<-rbind(goalBalanceSheet,data.table(종목코드=sofrCode,종목명='ACE 미국달러SOFR금리(합성)',현재가=currentSofrPrice,목표금액=bondBalanceSum,주문구분='00'))
goalBalanceSheet<-rbind(goalBalanceSheet,data.table(종목코드=highYieldCode,종목명='KODEX iShares미국하이일드액티브',현재가=currentHighyieldPrice,목표금액=0,주문구분='00'))


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

residualCode<-sofrCode
stockCodes<-c(top7LevCode,nasdaqLevCode,semiconductorLevCode)
combinedSheet[,allocationOrder:=fifelse(종목코드 %in% stockCodes,1L,fifelse(종목코드==residualCode,2L,3L))]
setorder(combinedSheet,allocationOrder,-목표금액)
remainingPortion<-totalBalanceSum
for(i in 1:nrow(combinedSheet)){
  row<-combinedSheet[i,]
  remTable<-combinedSheet[-(1:i),]
  if(row$종목코드==residualCode){
    qty<-row[,floor((remainingPortion-평가금액)/현재가)]
    combinedSheet[i,목표금액:=row$평가금액+qty*row$현재가]
  } else if(row$목표금액>0){
    availableAmount<-min(row$목표금액,remainingPortion)
    qty<-row[,floor((availableAmount-평가금액)/현재가)]
    combinedSheet[i,목표금액:=row$평가금액+qty*row$현재가]
  } else{
    combinedSheet[i,목표금액:=0]
  }
  remainingPortion<-remainingPortion-combinedSheet[i,목표금액]
}
combinedSheet<-combinedSheet[,c('종목코드','종목명','보유수량','목표금액','평가금액')]

buySheet<-combinedSheet[평가금액<목표금액]
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
