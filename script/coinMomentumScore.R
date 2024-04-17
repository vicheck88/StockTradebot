source("upbitMarketCap.R")
pkg = c('jose','openssl','PerformanceAnalytics','xts')
new.pkg = pkg[!(pkg %in% installed.packages()[, "Package"])]
if (length(new.pkg)) {
  install.packages(new.pkg, dependencies = TRUE)}

sapply(pkg,library,character.only=T)

upbitConfig<-fromJSON("./config.json")$upbit_key
uuid<-as.character(as.numeric(Sys.time()))
query_hash_alg<-"SHA512"

jwtClaimWithoutQuery<-jwt_claim(access_key=upbitConfig$access_key,nonce=uuid)
jwtTokenWithoutQuery<-jwt_encode_hmac(jwtClaimWithoutQuery,upbitConfig$secret_key,256)

#쵀근 12주 시세 조회
coinNum<-15
weekNum<-14
coinList<-paste("KRW",coinTable[1:coinNum,]$symbol,sep="-")
url <- paste0('https://api.upbit.com/v1/candles/weeks?market=',coinList,'&count=',weekNum)
h<-new_handle()
handle_setheaders(h, .list=list(Accepts="application/json"))

res<-list()
for(u in url){
  res[[u]] <- fromJSON(rawToChar(curl_fetch_memory(u, h)$content))
  Sys.sleep(0.1)
}
priceList<-rbindlist(res)
closePrice<-subset(priceList,select=c(candle_date_time_kst,market,trade_price))
names(closePrice)<-c("time","symbol","price")
closePrice[,time:=as_datetime(time,tz="Asia/Seoul")]
closePrice<-dcast(closePrice,time~symbol,value.var = "price")

momentumScoreTable<-apply(closePrice,2,function(x) as.integer(x<=x[14]))
momentumScoreTable<-momentumScoreTable[-c(13,14),][,-1]
totalscore<-colSums(momentumScoreTable)/12
