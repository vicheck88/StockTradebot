#setwd("/home/pi/stockInfoCrawler/StockTradebot/Rscript")
setwd("/Users/chhan/StockTradebot/Rscript")

library(data.table)
library(xts)
library(PerformanceAnalytics)
library(quantmod)

symbols = c('QQQ','TQQQ','SQQQ','QLD')
getSymbols(symbols, src = 'yahoo',from='1990-01-01')
prices = do.call(cbind,lapply(symbols, function(x) Ad(get(x))))
rets = Return.calculate(prices)

tqqqnaRow<-sum(is.na(prices$TQQQ.Adjusted))
qldnaRow<-sum(is.na(prices$QLD.Adjusted))
prices<-as.data.table(prices)
rets<-as.data.table(rets)
rets[is.na(TQQQ.Adjusted),TQQQ.Adjusted:=QQQ.Adjusted*3]
rets[is.na(QLD.Adjusted),QLD.Adjusted:=QQQ.Adjusted*2]
rets[is.na(SQQQ.Adjusted),SQQQ.Adjusted:=-3*QQQ.Adjusted]

for(i in tqqqnaRow:1){
  p<-prices[i+1,"TQQQ.Adjusted"]
  ratio<-rets[i+1,TQQQ.Adjusted]
  prices[i,TQQQ.Adjusted:=p/(1+ratio)]
  
  pp<-prices[i+1,SQQQ.Adjusted]
  rratio<-rets[i+1,SQQQ.Adjusted]
  prices[i,SQQQ.Adjusted:=pp/(1+rratio)]
}
rets<for(i in qldnaRow:1){
  p<-prices[i+1,"QLD.Adjusted"]
  ratio<-rets[i+1,QLD.Adjusted]
  prices[i,QLD.Adjusted:=p/(1+ratio)]
}
rets[-1,]

movingAvg<-NULL
for(i in c(5,10,20,60,100,200,300)){
  tbl<-as.xts(prices)
  tbl<-do.call(cbind,lapply(tbl,function(y)rollmean(y,i,align='right')))
  names(tbl)<-paste0(names(tbl),".MA.",i)
  movingAvg<-cbind(movingAvg,tbl)
}

priceWithMA<-cbind(as.xts(prices),movingAvg)
priceWithMA<-as.data.table(priceWithMA)

priceWith200MA<-priceWithMA[,.(index,QQQ.Adjusted,QLD.Adjusted,TQQQ.Adjusted,QQQ.Adjusted.MA.200,QLD.Adjusted.MA.200,TQQQ.Adjusted.MA.200)]
priceWith200MA[,QLDDisparity:=100*QLD.Adjusted/QLD.Adjusted.MA.200-100]
priceWith200MA[,QQQDisparity:=100*QQQ.Adjusted/QQQ.Adjusted.MA.200-100]
priceWith200MA[,TQQQDisparity:=100*TQQQ.Adjusted/TQQQ.Adjusted.MA.200-100]
priceWith200MA<-na.omit(as.xts(priceWith200MA))

rets<-rets[,-"QQQ.Adjusted"]
rets<-as.xts(rets)
rets$Cash<-0

getQLDInvestRatio<-function(table){
  for(i in 1:nrow(table)){
    disparity<-table[i,]$QLDDisparity
    #disparity<-table[i,]$QQQDisparity
    #disparity<-table[i,]$TQQQDisparity
    #TQQQratio
    addRatio<-floor(disparity)*0.5
    if(i>1){
      prevRatio<-table[i-1,]$investRatio
      if(addRatio>=0) addRatio<-max(prevRatio,addRatio)
      if(addRatio<0) addRatio<-min(1+addRatio,prevRatio)
    }
    newRatio<-min(1,addRatio)
    newRatio<-max(0,newRatio)
    table[i,]$QLDinvestRatio<-newRatio
  }
  return(table)
}

priceWithRatio<-as.data.table(priceWith200MA)
priceWithRatio[,QLDinvestRatio:=0]
priceWithRatio[,CashinvestRatio:=0]
priceWithRatio<-priceWithRatio[,getQLDInvestRatio(.SD)]
priceWithRatio[,CashinvestRatio:=1-QLDinvestRatio]
priceWithRatio<-as.xts(priceWithRatio)

Tactical = Return.portfolio(rets[,c("QLD.Adjusted","Cash")], priceWithRatio[,c("QLDinvestRatio","CashinvestRatio")], verbose = TRUE)

portfolios = na.omit(cbind(rets[,1], Tactical$returns)) %>%
  setNames(c('Hold', 'MA strategy'))

charts.PerformanceSummary(portfolios, main = "Buy & Hold vs Tactical")
