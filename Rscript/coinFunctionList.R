#setwd("C:/Users/vicen/Documents/Github/StockTradebot/Rscript")

pkg = c('quantmod','jsonlite', 'stringr', 
        'jose','openssl','PerformanceAnalytics','xts','curl','data.table',
        'httr')
new.pkg = pkg[!(pkg %in% installed.packages()[, "Package"])]
if (length(new.pkg)) {
  install.packages(new.pkg, dependencies = TRUE)}
sapply(pkg,library,character.only=T)

getCoinMarketCapList<-function(){
  coinMarket_api_key<-"7a53f6d1-41fd-4658-836a-b59e6432f5cf"
  h<-new_handle()
  handle_setheaders(h, .list=list("X-CMC_PRO_API_KEY"=coinMarket_api_key, Accepts="application/json"))
  url<-"https://pro-api.coinmarketcap.com/v1/cryptocurrency/listings/latest"
  r <- curl_fetch_memory(url, h)
  result<-fromJSON(rawToChar(r$content))$data
  priceList<-result$quote$USD
  coinMarketTable<-data.table(name=result$name,symbol=result$symbol,priceList)
  return(coinMarketTable[order(-market_cap)])
}
getUpbitCoinList<-function(){
  url<-'https://api.upbit.com/v1/market/all?isDetails=false'
  h<-new_handle()
  handle_setheaders(h, .list=list(Accepts="application/json"))
  r <- curl_fetch_memory(url, h)
  upbitCoinTable<-rawToChar(r$content)
  Encoding(upbitCoinTable)<-"UTF-8"
  upbitCoinTable<-as.data.table(fromJSON(upbitCoinTable))
  upbitCoinTable<-upbitCoinTable[substr(market,1,3)=="KRW"]
  upbitCoinTable[,market:=str_replace(market,"KRW-","")]
  return(upbitCoinTable)
}
getTopNUpbitCoinList<-function(num){
  coinMarketCapTable<-getCoinMarketCapList()
  upbitCoinTable<-getUpbitCoinList()
  coinTable<-coinMarketCapTable[upbitCoinTable,on=c(symbol="market"),nomatch=0]
  coinTable<-coinTable[order(-market_cap)]
  coinTable<-subset(coinTable,select=-english_name)
  return(coinTable[1:num,])
}
createJwtToken<-function(query){
  upbitConfig<-fromJSON("./config.json")$upbit_key
  uuid<-as.character(as.numeric(Sys.time()))
  query_hash_alg<-"SHA512"
  if(is.null(query)){
    jwtClaim<-jwt_claim(access_key=upbitConfig$access_key,nonce=uuid)
    jwtToken<-jwt_encode_hmac(jwtClaim,upbitConfig$secret_key,256)  
  } else{
    q<-as.character(sha512(query))
    jwtClaim<-jwt_claim(iat=NULL,
                        access_key=upbitConfig$access_key,
                        nonce=uuid,
                        query_hash=q,
                        query_hash_alg=query_hash_alg)
    jwtToken<-jwt_encode_hmac(jwtClaim,upbitConfig$secret_key,256)
  }
  return(jwtToken)
}
getResponseParam<-function(url, query){
  jwtToken<-createJwtToken(query)
  h<-new_handle()
  handle_setheaders(h, .list=list(Accept="application/json", 
                                  Authorization=paste0("Bearer ",jwtToken)))
  return(fromJSON(rawToChar(curl_fetch_memory(url, h)$content)))
}
getCurrentUpbitAccountInfo<-function(){
  url<-"https://api.upbit.com/v1/accounts"
  result<-getResponseParam(url,NULL)
  result$balance<-as.numeric(result$balance)
  result$avg_buy_price<-as.numeric(result$avg_buy_price)
  setDT(result)
  return(result)
}
getCurrentUpbitPrice<-function(coinList){
  krwCoinString=paste(coinList,collapse=',')
  url <- paste0('https://api.upbit.com/v1/ticker?markets=',krwCoinString,'&count=',1)
  h<-new_handle()
  handle_setheaders(h, .list=list(Accepts="application/json"))
  priceList<-as.data.table(fromJSON(rawToChar(curl_fetch_memory(url, h)$content)))
  priceList<-priceList[,.(market,trade_price)]
  return(priceList)
}
getCoinPriceHistory<-function(coinList,type,unit,count){
  #coinList<-paste("KRW",coinList,sep="-")
  if(type=="minutes") {
    candle<-paste0("minutes/",unit)
  } else {candle<-type}
  url <- paste0('https://api.upbit.com/v1/candles/'
                ,candle,'?market=',coinList,'&count=',count)
  h<-new_handle()
  handle_setheaders(h, .list=list(Accepts="application/json"))
  
  res<-list()
  for(u in url){
    res[[u]] <- fromJSON(rawToChar(curl_fetch_memory(u, h)$content))
    Sys.sleep(0.1)
  }
  return(rbindlist(res))
}
getMomentumHistory<-function(coinList,candleType,unit,count,priceType,momentumPeriod){
  priceList<-getCoinPriceHistory(coinList,candleType,unit,count)
  priceList<-subset(priceList,select=c("market","candle_date_time_kst",priceType))
  priceList[,prevPrice:=shift(get(priceType),momentumPeriod,NA,"lead"),by=market]
  priceList<-na.omit(priceList)
  priceList[,momentum:=get(priceType)/prevPrice*100]
  return(subset(priceList,select=c("market","candle_date_time_kst","momentum")))
}
getEqualWeightBalanceDiff<-function(num){
  topNCoinList<-getTopNUpbitCoinList(num)
  balanceList<-getCurrentUpbitAccountInfo()
  balanceList[avg_buy_price==0]$avg_buy_price<-1
  totalBalance<-balanceList[,sum(balance*avg_buy_price)]
  topNCoinList$targetbalance<-rep(totalBalance/num,num)
  topNCoinList<-topNCoinList[,.(name,symbol,price,targetbalance)]
  curBalanceList<-balanceList[,.(currency,balance=balance*avg_buy_price)]
  joinList<-merge(topNCoinList,curBalanceList,by.x="symbol",by.y="currency",all=TRUE)
  joinList<-joinList[symbol!="KRW"]
  joinList[is.na(balance)]$balance<-0
  joinList[is.na(targetbalance)]$targetbalance<-0
  joinList[,diff:=targetbalance-balance]
  joinList<-joinList[,.(symbol,diff)]
  names(joinList)<-c("market","buyamount")
  return(joinList)
}
rebalanceWeight<-function(table){
  table<-table[buyamount!=0]
  table[,market:=paste("KRW",market,sep="-")]
  table$ord_type<-'limit'
  table$side<-'bid'
  table[buyamount<0]$side<-'ask'
  table[,buyamount:=abs(buyamount)]
  table[,price:=getCurrentUpbitPrice(table$market)$trade_price]
  table[,volume:=buyamount/price]
  table<-subset(table,select=c("market","side","volume","price","ord_type"))
  orderCoin(table)
}
getOrderList<-function(status){
  query<-paste0("state=",status)
  url<-"https://api.upbit.com/v1/orders"
  
  
}
orderCoin<-function(order){
  query<-paste0("market=",order$market,"&side=",order$side,"&volume=",order$volume,"&price=",order$price,"&ord_type=",order$ord_type)
  tokenList<-sapply(query,function(x) createJwtToken(x)) 
  url<-"https://api.upbit.com/v1/orders"
  for(i in 1:NROW(order)){
    res<-POST(url,add_headers(Authorization=paste0("Bearer ",tokenList[i])),body=as.list(order[i,]),encode='json')  
    print(res$status_code)
    print(rawToChar(res$content))
    Sys.sleep(0.5)
  }
}

