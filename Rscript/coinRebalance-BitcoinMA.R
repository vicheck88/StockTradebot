#setwd("/home/pi/stockInfoCrawler/StockTradebot/Rscript")
setwd("/Users/chhan/StockTradebot/Rscript")
source("~/StockTradebot/Rscript/telegramAPI.R") #macOS에서 읽는 경우
#source("~/stockInfoCrawler/StockTradebot/Rscript/telegramAPI.R") #라즈베리에서 읽는 경우
source("./coinFunctionList.R",encoding="utf-8")

num<-1
coinNumLimit<-1
bandLimit<-0.3
changeThreshold<-0.05

currentBalance<-getCurrentBalance()
totalBalance<-currentBalance[,sum(balance)]
coinList<-getUpbitCoinListDetail(coinNumLimit)


#1.가장 시가총액이 높은 두 코인의 이동평균선 계산
#시가총액 비율:
indexCoin<-getIndexBalance(coinList[1:num,],1,"MARKET")
#이평선
type<-"days"
movingAvgDay<-30
unit<-60
count<-200
coinPriceHistory<-getCoinPriceHistory(indexCoin$market,type,unit,count)
coinPriceHistory<-coinPriceHistory[,.(market,candle_date_time_kst,trade_price)]
setkeyv(coinPriceHistory,c("market","candle_date_time_kst"))
#현재가격 추가하기
curCoinPrices<-getCurrentUpbitPrice(indexCoin$market)
curCoinPrices[,candle_date_time_kst:=format(Sys.time(),'%Y-%m-%dT%H:%M:%S')]
coinPriceHistory<-rbind(coinPriceHistory,curCoinPrices)


#이동평균선 구하기
movingAvg<-coinPriceHistory[,.(movingAvg=frollmean(trade_price,movingAvgDay,align="right")),by=market]
coinPriceHistory<-cbind(coinPriceHistory,movingAvg=movingAvg$movingAvg)
coinPriceHistory[,disparity:=trade_price/movingAvg*100-100]
coinPriceHistory<-na.omit(coinPriceHistory)

getInvestRatio<-function(table){
  for(i in 1:nrow(table)){
    disparity<-table[i,]$disparity
    
    if(disparity>0) {
      addRatio<-floor(disparity)*0.5
    }  else addRatio<-floor(disparity)*0.25
    if(i>1){
      prevRatio<-table[i-1,]$ratio
      if(addRatio>=0) addRatio<-max(prevRatio,addRatio)
      if(addRatio<0) addRatio<-min(1+addRatio,prevRatio)
    }
    newRatio<-min(1,addRatio)
    newRatio<-max(0,newRatio)
    table$ratio[i]<-newRatio
  }
  return(table)
}

coinPriceHistory<-coinPriceHistory[,getInvestRatio(.SD),by=market]
currentRatio<-coinPriceHistory[,tail(.SD,1),by=market][,.(market,ratio)]

latestCoinPriceHistory<-tail(coinPriceHistory,1)
#sendMessage
message<-paste0("Bitcoin price: ",latestCoinPriceHistory$trade_price)
message<-paste0(message,"\nBitcoin 30 MA: ",round(latestCoinPriceHistory$movingAvg))
message<-paste0(message,"\nBitcoin Disparity: ", round(latestCoinPriceHistory$disparity))
message<-paste0(message,"\nBitcoin Ratio: ",latestCoinPriceHistory$ratio)
sendMessage(message)


failOrder<-c()
balanceCombinedTable<-merge(currentRatio,currentBalance,by="market",all=TRUE)
balanceCombinedTable[,totalBalance:=totalBalance]
balanceCombinedTable<-balanceCombinedTable[market!="KRW-KRW"]
balanceCombinedTable[is.na(ratio)]$ratio<-0
balanceCombinedTable[is.na(balance)]$balance<-0
balanceCombinedTable[is.na(curvolume)]$curvolume<-0
balanceCombinedTable[,symbol:=sapply(strsplit(market,"-"),function(x)x[2])]
balanceCombinedTable[,targetBalance:=totalBalance*ratio]

failOrder<-c()
orderTable<-createOrderTable(balanceCombinedTable)
if(nrow(orderTable)>0){
  for(i in 1:5){
    if(length(failOrder)==0){
      failOrder<-orderCoin(orderTable[side=="ask"])
      failOrder<-c(failOrder,orderCoin(orderTable[side=="bid"]))
    } else{
      orderTable<-orderTable[market %in% failOrder]
      sendMessage(paste0("Fail to order: ",paste(failOrder,collapse=",")))
      failOrder<-orderCoin(orderTable)
    }
    if(length(failOrder)==0) {
      sendMessage("Coin order complete")
      break;
    }
    Sys.sleep(60*10)
  }
}