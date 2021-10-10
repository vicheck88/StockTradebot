setwd("/home/pi/stockInfoCrawler/StockTradebot/Rscript")
#setwd("C:/Users/vicen/Documents/Github/StockTradebot/Rscript")
#setwd("C:/Users/vicen/Documents/StockTradebot/Rscript")
source("./coinFunctionList.R",encoding="utf-8")

num<-5
coinNumLimit<-1000
currentBalance<-getCurrentBalance()
totalBalance<-currentBalance[,sum(balance)]
coinList<-getUpbitCoinListDetail(coinNumLimit)

#1. 전체 시장의 모멘텀 계산(3개월로 계산)
#전체 시장에서 상승하는 모멘텀의 개수비율로 코인과 현금의 비중 조절
#현금비중=100-margetStrength
momentumList<-getUpbitCoinMomentum("months","",3, coinList)
marketStrength<-NROW(momentumList[momentum>100])/NROW(momentumList)

#모멘텀 방식: 0 ~ 50%, 인덱스: 나머지
#모든 항목의 모멘텀이 100 밑일 경우 인덱스도 전부 뺌
#지금 1달 간의 모멘텀 계산
#상위 5개의 코인 매입
momentumList<-getUpbitCoinMomentum("months","",1,coinList)
momentumStrength<-NROW(momentumList[momentum>100])/NROW(momentumList)
momentumRatioLimit<-marketStrength*momentumStrength*0.5
momentumCoin<-getMomentumBalance(coinList,num,momentumRatioLimit,"EQUAL",momentumList)

#인덱스
#5개의 코인 구입
#비율:
indexLimitRatio <- marketStrength-momentumRatioLimit
indexCoin<-getIndexBalance(coinList[1:num,],indexLimitRatio,"MARKET")

coinMomentumUnionTable<-rbind(indexCoin,momentumCoin)
coinMomentumUnionTable<-coinMomentumUnionTable[,ratio:=sum(ratio),by=c("symbol","market","market_cap")]

orderTable<-createOrderTable(coinMomentumUnionTable,currentBalance)

rebalanceTable(orderTable)
