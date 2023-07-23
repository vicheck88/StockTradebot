#setwd("/home/pi/stockInfoCrawler/StockTradebot/Rscript")
setwd("/Users/chhan/StockTradebot/Rscript")
source("./coinFunctionList.R",encoding="utf-8")

library(data.table)
library(xts)
library(PerformanceAnalytics)
library(quantmod)
library(lubridate)



num<-1
coinNumLimit<-2
bandLimit<-0.3

#1.가장 시가총액이 높은 두 코인의 이동평균선 계산
#시가총액 비율:
coinList<-getUpbitCoinListDetail(coinNumLimit)
indexCoin<-getIndexBalance(coinList[1:num,],1,"MARKET")
#이평선
#type<-"days"
type<-"minutes"
movingAvgDay<-30
unit<-60
#unit<-240
count<-200

#과거 가격들 구하기(2000일)
date<-Sys.Date()+1
coinPriceHistory<-NULL
curRowNum<-0
for(i in 1:1000){
  if(type=="days"){
    toDate<-paste0(as.Date(date)-1,'T09:00:00')
  } else if(type=="minutes"){
    toDate<-as_datetime(date)-60
    toDate<-str_replace(toDate," ","T")
  }
  coinPriceHistory<-rbind(coinPriceHistory,getCoinPriceHistory(indexCoin$market,type,unit,count,toDate))
  coinPriceHistory<-unique(coinPriceHistory)
  date<-coinPriceHistory[,min(candle_date_time_kst)]
  if(nrow(coinPriceHistory)==curRowNum) {break}
  curRowNum<-nrow(coinPriceHistory)
}

coinPriceHistory<-coinPriceHistory[,.(market,candle_date_time_kst,trade_price)]
setkeyv(coinPriceHistory,c("market","candle_date_time_kst"))
coinPriceHistory[candle_date_time_kst %like% "T09:00:00",isDayStart:=T]

#이동평균선 구하기(Day 기준)
movingAvg<-coinPriceHistory[isDayStart==T,.(movingAvg=frollmean(trade_price,movingAvgDay,align='right')),by=market]
movingAvg$candle_date_time_kst<-coinPriceHistory[isDayStart==T,candle_date_time_kst]
coinPriceHistory<-movingAvg[coinPriceHistory,on=c("market","candle_date_time_kst")]

for(i in 1:nrow(coinPriceHistory)){
  row<-coinPriceHistory[i,]
  time<-row$candle_date_time_kst
  subTable<-coinPriceHistory[isDayStart==T][time>=candle_date_time_kst]
  if(nrow(subTable)<movingAvgDay) next
  subTable<-rbind(subTable,row)
  subTable<-subTable[(nrow(subTable)-movingAvgDay):nrow(subTable),]
  v<-last(subTable[,frollmean(trade_price,movingAvgDay,align="right")])
  coinPriceHistory[i,]$movingAvg<-v
}


minDay<-min(coinPriceHistory[is.na(movingAvg)==F,candle_date_time_kst])
coinPriceHistory<-coinPriceHistory[candle_date_time_kst>=minDay]


#for(i in 2:nrow(coinPriceHistory)){
#  if(is.na(coinPriceHistory[i,]$movingAvg)) 
#    coinPriceHistory[i,]$movingAvg=coinPriceHistory[i-1]$movingAvg
#}
coinPriceHistory[,disparity:=trade_price/movingAvg*100-100]

#이평선과 비교해 높을 경우 매수, 낮을 경우 매도
#구입: 1%부터 1%당 현금 10%씩
#판매: -1%부터 1%당 현금 20%씩. 단, 10% 떨어지는 경우는 전부 손절

targetRatio<-1
coinPriceHistory$investRatio<-0

getInvestRatio<-function(table){
  for(i in 1:nrow(table)){
    disparity<-table[i,]$disparity
    
    if(disparity>0) {
      addRatio<-floor(disparity)*0.5
    }  else addRatio<-floor(disparity)*0.25
    if(i>1){
      prevRatio<-table[i-1,]$investRatio
      if(addRatio>=0) addRatio<-max(prevRatio,addRatio)
      if(addRatio<0) addRatio<-min(1+addRatio,prevRatio)
    }
    newRatio<-min(1,addRatio)
    newRatio<-max(0,newRatio)
    table[i,]$investRatio<-newRatio
  }
  return(table)
}
coinPriceHistory<-coinPriceHistory[,getInvestRatio(.SD),by=market]

#시간단위일 경우 시간변경 필요
#coinPriceHistory[,candle_date_time_kst:=as.Date(coinPriceHistory[,min(candle_date_time_kst)])+(.I-1)*2]

coinRatioTable<-coinPriceHistory[market=="KRW-BTC",.(candle_date_time_kst,investRatio)]
coinRatioTable[,candle_date_time_kst:=as_datetime(candle_date_time_kst,tz=Sys.timezone())]
coinRatioTable[,cashRatio:=1-investRatio]

coinAdjusted<-coinPriceHistory[market=="KRW-BTC",.(candle_date_time_kst,trade_price)]
coinAdjusted<-coinAdjusted[,candle_date_time_kst:=as_datetime(candle_date_time_kst,tz=Sys.timezone())]
coinAdjusted[,prevValue:=shift(trade_price,1)]
coinAdjusted[,adjustedPrice:=(trade_price/prevValue)-1]
coinAdjusted<-coinAdjusted[,.(candle_date_time_kst,adjustedPrice)]
coinAdjusted$adjustedCache<-0

rets<-as.xts(coinAdjusted)
rets<-na.omit(rets)
coinRatioTable<-coinRatioTable[-1,]
coinRatioTable<-as.xts(coinRatioTable)
Tactical = Return.portfolio(rets, coinRatioTable, verbose = TRUE)

portfolios = na.omit(cbind(rets[,1], Tactical$returns)) %>%
  setNames(c('매수 후 보유', '시점 선택 전략'))

charts.PerformanceSummary(portfolios,
                          main = "Buy & Hold vs Tactical")
