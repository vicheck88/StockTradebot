#setwd("/home/pi/stockInfoCrawler/StockTradebot/Rscript")
setwd("/Users/chhan/StockTradebot/Rscript")

library(data.table)
library(xts)
library(PerformanceAnalytics)
library(quantmod)

symbols = c('QQQ','TQQQ','SQQQ')
getSymbols(symbols, src = 'yahoo',from='1990-01-01')
prices = do.call(cbind,
                 lapply(symbols, function(x) Ad(get(x))))
rets = Return.calculate(prices)

tqqqnaRow<-sum(is.na(prices$TQQQ.Adjusted))
prices<-as.data.table(prices)
rets<-as.data.table(rets)
rets[is.na(TQQQ.Adjusted),TQQQ.Adjusted:=QQQ.Adjusted*3]
rets[is.na(SQQQ.Adjusted),SQQQ.Adjusted:=-3*QQQ.Adjusted]

for(i in tqqqnaRow:1){
  p<-prices[i+1,"TQQQ.Adjusted"]
  ratio<-rets[i+1,TQQQ.Adjusted]
  prices[i,TQQQ.Adjusted:=p/(1+ratio)]
  
  pp<-prices[i+1,SQQQ.Adjusted]
  rratio<-rets[i+1,SQQQ.Adjusted]
  prices[i,SQQQ.Adjusted:=pp/(1+rratio)]
}
rets<-rets[-1,]

movingAvg<-NULL
for(i in c(5,10,20,60,100,200)){
  tbl<-as.xts(prices)
  tbl<-do.call(cbind,lapply(tbl,function(y)rollmean(y,i,align='right')))
  names(tbl)<-paste0(names(tbl),".MA.",i)
  movingAvg<-cbind(movingAvg,tbl)
}

priceWithMA<-cbind(as.xts(prices),movingAvg)
priceWithMA<-as.data.table(priceWithMA)

priceWith200MA<-priceWithMA[,.(index,QQQ.Adjusted,SQQQ.Adjusted,TQQQ.Adjusted,QQQ.Adjusted.MA.200)]
priceWith200MA[,QQQDisparity:=100*QQQ.Adjusted/QQQ.Adjusted.MA.200-100]
priceWith200MA<-na.omit(as.xts(priceWith200MA))

rets<-rets[,-"QQQ.Adjusted"]
rets<-as.xts(rets)
rets$Cash<-0

getTQQQInvestRatio<-function(table,nrow){
  for(i in 1:nrow(table)){
    disparity<-table[i,]$QQQDisparity
    if(is.na(disparity)) next
    if(disparity>0) next
  
    regTable<-tail(table[index<=table[i,index]],nrow)
    regression<-summary(lm(regTable$QQQ.Adjusted~seq(1,nrow(regTable))))
    coef<-regression$coefficients[2,1]
    pval<-regression$coefficients[2,4]
    signal<- pval<0.01 & coef<0 & disparity<=(-15)
    
    if(signal) {
      ratio<-min(floor(-(disparity+15)/3)*0.05+0.2,1)
      table[i,]$disparityFlag<-F
    } else if(i>1 & disparity< -3){
        prevRatio<-table[i-1,]$TQQQinvestRatio
        prevDisparityFlag<-table[i-1,]$disparityFlag
        if(disparity> -9 & prevDisparityFlag==F) {
          ratio <- prevRatio*0.5
          table[i,]$disparityFlag=T
        } else ratio<-prevRatio
    }
    else ratio<-0
    
    table[i,]$TQQQinvestRatio<-ratio
  }
  return(table)
}

priceWithRatio<-as.data.table(priceWith200MA)
priceWithRatio[,TQQQinvestRatio:=0]
priceWithRatio[,SQQQinvestRatio:=0]
priceWithRatio[,CashinvestRatio:=0]
priceWithRatio[,disparityFlag:=F]

priceWithRatio<-priceWithRatio[,getTQQQInvestRatio(.SD,100)]
priceWithRatio[,CashinvestRatio:=1-TQQQinvestRatio]
priceWithRatio[,-disparityFlag]
priceWithRatio<-as.xts(priceWithRatio)

Tactical = Return.portfolio(rets[,c("TQQQ.Adjusted","Cash")], priceWithRatio[,c("TQQQinvestRatio","CashinvestRatio")], verbose = TRUE)

portfolios = na.omit(cbind(rets[,1], Tactical$returns))

charts.PerformanceSummary(portfolios, main = "Buy & Hold vs Tactical")
