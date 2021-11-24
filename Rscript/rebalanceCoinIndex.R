setwd("/home/pi/stockInfoCrawler/StockTradebot/Rscript")
#setwd("C:/Users/vicen/Documents/Github/StockTradebot/Rscript")
#setwd("C:/Users/vicen/Documents/StockTradebot/Rscript")
source("./coinFunctionList.R",encoding="utf-8")

num<-5
coinNumLimit<-100
bandLimit<-0.5
currentBalance<-getCurrentBalance()
totalBalance<-currentBalance[,sum(balance)]
coinList<-getUpbitCoinListDetail(coinNumLimit)

#1. 전체 시장의 모멘텀 계산(3개월로 계산)
#전체 시장에서 상승하는 모멘텀의 개수비율로 코인과 현금의 비중 조절
#시총 상위 100개의 코인으로 모멘텀 계산산
#현금비중=100-margetStrength
momentumList<-getUpbitCoinMomentum("days","",c(100),c(1), coinList$symbol)
marketStrength<-NROW(momentumList[momentum>100])/NROW(momentumList)

#모멘텀 방식: 0 ~ 50%, 인덱스: 나머지
#지금 1달 간의 모멘텀 계산
#상위 5개의 코인 매입
momentumList<-getUpbitCoinMomentum("days","",c(10,20,30),c(0.5,0.3,0.2),getUpbitCoinList()$market)
momentumStrength<-NROW(momentumList[momentum>100])/NROW(momentumList)
momentumRatioLimit<-marketStrength*momentumStrength
momentumCoin<-getMomentumBalance(coinList,num,momentumRatioLimit,"EQUAL",momentumList)

#인덱스
#5개의 코인 구입
#비율:
indexLimitRatio <- marketStrength-momentumRatioLimit
indexCoin<-getIndexBalance(coinList[1:num,],indexLimitRatio,"MARKET")

coinMomentumUnionTable<-rbind(indexCoin,momentumCoin)
coinMomentumUnionTable<-coinMomentumUnionTable[,.(ratio=sum(ratio)),by=c("symbol","market","market_cap")]

balanceCombinedTable<-merge(coinMomentumUnionTable,currentBalance,by="market",all=TRUE)
balanceCombinedTable[,totalBalance:=totalBalance]
balanceCombinedTable<-balanceCombinedTable[market!="KRW-KRW"]
balanceCombinedTable[is.na(ratio)]$ratio<-0
balanceCombinedTable[is.na(balance)]$balance<-0
balanceCombinedTable[is.na(curvolume)]$curvolume<-0
balanceCombinedTable[,symbol:=sapply(strsplit(market,"-"),function(x)x[2])]
balanceCombinedTable[,targetBalance:=totalBalance*ratio]
balanceCombinedTable[,curRatio:=balance/totalBalance]
balanceCombinedTable[,diffRatio:=abs(curRatio-ratio)]
balanceCombinedTable[,outsideofBand:=diffRatio>ratio*bandLimit]

for(i in 1:5){
  if(length(failOrder)==0){
    failOrder<-c()
    if(sum(balanceCombinedTable$outsideofBand)){
      orderTable<-createOrderTable(balanceCombinedTable)
      failOrder<-orderCoin(orderTable)
    } else{
      logPath<-paste0(logDir,"coinLog.",Sys.Date(),".log")
      log_open(logPath)
      log_print("Every coins are in the band. Buy Nothing")
      log_close()
    }
  } else{
    orderTable<-orderTable[market %in% failOrder]
    failOrder<-orderCoin(orderTable)
  }
  if(length(failOrder)==0) break;
  Sys.sleep(60*10)
}




