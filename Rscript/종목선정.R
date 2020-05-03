#함수 불러돌이기
source()
today<-recentBizDay()

#오늘 주식시장에 등록된 기업 목록, 섹터 정보
corpsInfoData<-mergeWICSKRX(today)
reducedCorpsInfoData<-subset(corpsInfoData,select=c(10,1,4,3,6,9))
codeList<-corpsInfoData$'종목코드'

#재무데이터 얻기
result1<-NULL
for(i in 1:nrow(corpsInfoData)){
#for(i in 1:100){
  tryCatch(
    {
      code<-codeList[i]
      result1<-rbind(result1,unlist(c(code=code,getCurrentValueQualityFactorQuarter(code))))
      Sys.sleep(0.5)
    },
    error=function(e) print(paste0("Fail to Read: ",code))
  )
}
result1<-as.data.table(result1)
result2<-result1[,lapply(.SD[,2:8], as.double)]
result2[,code:=result1$code]
result1<-setDT(merge(reducedCorpsInfoData,result2,by.x='종목코드',by.y='code'))

#모멘텀 구하기
result2<-NULL
for(i in 1:nrow(corpsInfoData)){
#for(i in 1:100){
  tryCatch(
    {
      code<-codeList[i]
      priceList<-adjustedPriceFromNaver('day',365,code)
      Return<-Return.calculate(priceList)
      Return<-Return[!is.na(Return)]
      volatility<-sd(Return)*sqrt(length(Return))
      
      monthPrice<-adjustedPriceFromNaver('month',14,code)[,1]
      latestValue<-monthPrice[13]
      monthlyMomentum<-latestValue/monthPrice[-12:-13]-1
      avgMomentum<-(mean(monthlyMomentum))/volatility
      result2<-rbind(result2,unlist(c('종목코드'=code,Momentum=avgMomentum)))
      Sys.sleep(0.5)
    },
    error=function(e) print(paste0("Fail to Read: ",code))
  )
}
result<-result1[as.data.table(result2),on='종목코드']
result$Momentum<-as.double(result$Momentum)
result$NCAV_Ratio<-result$NCAV/result$"시가총액(원)"
result <- result[NewFScore==3 & !is.na(PER) & !is.na(PBR) & !is.na(PCR) & !is.na(PSR) & NCAV_Ratio>=1]

result$PER<-winsorizing(result$PER)
result$PBR<-winsorizing(result$PBR)
result$PCR<-winsorizing(result$PCR)
result$PSR<-winsorizing(result$PSR)

result[,c("PER_N","PBR_N","PCR_N","PSR_N"):=
          list((PER-mean(PER,na.rm=TRUE))/sd(PER,na.rm=TRUE),
              (PBR-mean(PBR,na.rm=TRUE))/sd(PBR,na.rm=TRUE),
              (PCR-mean(PCR,na.rm=TRUE))/sd(PCR,na.rm=TRUE),
              (PSR-mean(PSR,na.rm=TRUE))/sd(PSR,na.rm=TRUE))]
result[,c("Value_Rank","Quality_Rank","Momentum_Rank"):=
         list(rank(PER_N+PBR_N+PCR_N+PSR_N),rank(GPA),rank(Momentum))]


result[,"total_Rank":=rank(
  (Value_Rank-mean(Value_Rank,na.rm=TRUE))/sd(Value_Rank,na.rm=TRUE)+
     (Quality_Rank-mean(Quality_Rank,na.rm=TRUE))/sd(Quality_Rank,na.rm=TRUE)+
        (Momentum_Rank-mean(Momentum_Rank,na.rm=TRUE))/sd(Momentum_Rank,na.rm=TRUE),ties.method = "average")]


result<-result[total_Rank<=10]
tmpcol<-colnames(result)
result$Date<-as.Date(today,"%Y%m%d")
setcolorder(result,c("Date",tmpcol))

#MVP 측정 위한 공분산 행렬 구하기
getCovarianceMarix<-function(codeList){
  return(cov(do.call(cbind,lapply(rep(code,10),function(x) Return.calculate(adjustedPriceFromNaver('day',365,x))[-1,]))))
}

