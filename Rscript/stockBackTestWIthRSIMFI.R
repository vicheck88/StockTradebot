#setwd("/home/pi/stockInfoCrawler/StockTradebot/Rscript")
setwd("/Users/chhan/StockTradebot/Rscript")

library(data.table)
library(xts)
library(PerformanceAnalytics)
library(quantmod)

symbols = c('QQQ','TQQQ','QLD')
getSymbols(symbols, src = 'yahoo',from='2010-01-01')
prices = do.call(cbind,
                 lapply(symbols, function(x) Ad(get(x))))
rets = Return.calculate(prices)
QQQ.DT<-as.data.table(QQQ)
QQQ.DT[,TP:=(QQQ.High+QQQ.Low+QQQ.Close)/3]
for(i in 2:nrow(QQQ.DT)){
  QQQ.DT[i,TP_UP:=QQQ.DT[i,TP]>QQQ.DT[i-1,TP]]
  QQQ.DT[i,DIFF:=QQQ.DT[i,QQQ.Close]-QQQ.DT[i-1,QQQ.Close]]
}
for(i in 15:nrow(QQQ.DT)){
  subrets<-QQQ.DT[(i-13):i,]
  if(i==15){
    up_avg<-subrets[DIFF>0][,mean(DIFF)]
    down_avg<-abs(subrets[DIFF<=0][,mean(DIFF)])
  } else{
    diff<-QQQ.DT[i,DIFF]
    up_avg<-QQQ.DT[i-1,AU]
    down_avg<-QQQ.DT[i-1,AD]
    if(diff>0){
      up_avg<-(up_avg*13+diff)/14
      down_avg<-down_avg*13/14
    } else{
      up_avg<-up_avg*13/14
      down_avg<-(down_avg*13-diff)/14
    }
  }
  QQQ.DT[i,AU:=up_avg]
  QQQ.DT[i,AD:=down_avg]
  QQQ.DT[i,RSI:=100*up_avg/(up_avg+down_avg)]
  
  mf_up<-subrets[TP_UP==TRUE][,sum(QQQ.Volume*TP)]
  mf_down<-subrets[TP_UP==FALSE][,sum(QQQ.Volume*TP)]
  QQQ.DT[i,MFI:=100*mf_up/(mf_up+mf_down)]
}

tqqqnaRow<-sum(is.na(prices$TQQQ.Adjusted))
qldnaRow<-sum(is.na(prices$QLD.Adjusted))
prices<-as.data.table(prices)
rets<-as.data.table(rets)

rets[is.na(TQQQ.Adjusted),TQQQ.Adjusted:=QQQ.Adjusted*3]
rets[is.na(QLD.Adjusted),QLD.Adjusted:=QQQ.Adjusted*2]

for(i in tqqqnaRow:1){
  p<-prices[i+1,"TQQQ.Adjusted"]
  ratio<-rets[i+1,TQQQ.Adjusted]
  prices[i,TQQQ.Adjusted:=p/(1+ratio)]
}
for(i in qldnaRow:1){
  p<-prices[i+1,"QLD.Adjusted"]
  ratio<-rets[i+1,QLD.Adjusted]
  prices[i,QLD.Adjusted:=p/(1+ratio)]
}
#rets<-rets[-1,]

movingAvg<-NULL
for(i in c(5,10,20,60,100,200,300)){
  tbl<-as.xts(prices)
  tbl<-do.call(cbind,lapply(tbl,function(y)rollmean(y,i,align='right')))
  names(tbl)<-paste0(names(tbl),".MA.",i)
  movingAvg<-cbind(movingAvg,tbl)
}

priceWithMA<-cbind(as.xts(prices),movingAvg)
priceWithMA<-as.data.table(priceWithMA)

priceWith200MA<-priceWithMA[,.(index,QQQ.Adjusted,QLD.Adjusted,TQQQ.Adjusted,QQQ.Adjusted.MA.200)]
priceWith200MA[,QQQDisparity:=100*QQQ.Adjusted/QQQ.Adjusted.MA.200-100]
priceWith200MA[,c("RSI","MFI"):=list(QQQ.DT$RSI,QQQ.DT$MFI)]

priceWith200MA<-na.omit(as.xts(priceWith200MA))

rets<-rets[,-"QQQ.Adjusted"]
rets<-as.xts(rets)
rets$Cash<-0

getTQQQInvestRatio<-function(table){
  for(i in 1:nrow(table)){
    disparity<-table[i,]$QQQDisparity
    #TQQQratio
    addRatio<-floor(disparity)*0.5
    if(i>1){
      prevRatio<-table[i-1,]$investRatio
      if(addRatio>=0) addRatio<-max(prevRatio,addRatio)
      if(addRatio<0) addRatio<-min(1+addRatio,prevRatio)
    }
    newRatio<-min(1,addRatio)
    newRatio<-max(0,newRatio)
    table[i,]$TQQQinvestRatio<-newRatio
  }
  return(table)
}
getTQQQInvestRatio2<-function(table){
  for(i in 1:nrow(table)){
    disparity<-table[i,]$QQQDisparity
    RSI<-table[i,]$RSI
    MFI<-table[i,]$MFI
    dispRatio<-floor(disparity)*0.5
    oversellRatio<-0
    if(i>1){
      prevDispRatio<-table[i-1,]$dispRatio
      if(dispRatio>=0) dispRatio<-max(prevDispRatio,dispRatio)
      if(dispRatio<0) dispRatio<-min(1+dispRatio,prevDispRatio)
      
      prevOversellRatio<-table[i-1,]$oversellRatio
      if(dispRatio<0 && RSI<=20 && MFI<=15) oversellRatio<-prevOversellRatio+0.03
      else if(dispRatio>0) oversellRatio<-0
    }
    newDispRatio<-min(1,dispRatio)
    newDispRatio<-max(0,newDispRatio)
    
    newOversellRatio<-min(0.5,oversellRatio)
    table[i,]$dispRatio<-newDispRatio
    table[i,]$oversellRatio<-newOversellRatio
    table[i,]$TQQQinvestRatio<-min(1,newOversellRatio+newDispRatio)
  }
  return(table)
}

priceWithRatio<-as.data.table(priceWith200MA)
priceWithRatio[,TQQQinvestRatio:=0]
priceWithRatio[,CashinvestRatio:=0]
priceWithRatio[,dispRatio:=0]
priceWithRatio[,oversellRatio:=0]
priceWithRatio<-priceWithRatio[,getTQQQInvestRatio(.SD)]
priceWithRatio[,CashinvestRatio:=1-TQQQinvestRatio]
priceWithRatio<-as.xts(priceWithRatio)

Tactical = Return.portfolio(rets[,c("TQQQ.Adjusted","Cash")], priceWithRatio[,c("TQQQinvestRatio","CashinvestRatio")], verbose = TRUE)

portfolios = na.omit(cbind(rets[,1], Tactical$returns)) %>%
  setNames(c('Hold', 'MA strategy'))

charts.PerformanceSummary(portfolios, main = "Buy & Hold vs Tactical")

