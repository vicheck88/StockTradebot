#setwd("C:/Users/vicen/Documents/Github/StockTradebot/Rscript")

pkg = c('quantmod','jsonlite', 'stringr', 'logr',
        'jose','openssl','PerformanceAnalytics','xts','curl','data.table',
        'httr')
new.pkg = pkg[!(pkg %in% installed.packages()[, "Package"])]

logDir<-"/home/pi/stockInfoCrawler/StockTradebot/log"

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
createJwtToken<-function(query,random){
  upbitConfig<-fromJSON("./config.json")$upbit_key
  uuid<-as.character(as.numeric(Sys.time())*random)
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
  jwtToken<-createJwtToken(query,runif(1,1000,23455))
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
  priceList[,trade_price:=as.double(trade_price)]
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
  logPath<-paste0(logDir,"coinLog.",Sys.Date(),".log")
  log_open(logPath)
  
  log_print(paste0("TOP ",num,"COIN LIST:"))
  topNCoinList<-getTopNUpbitCoinList(num)
  log_print(topNCoinList)
  topNCoinList[,market:=paste0("KRW-",symbol)]
  
  log_print("CURRENT BALANCE")
  krwCoinList<-getUpbitCoinList()
  balanceList<-getCurrentUpbitAccountInfo()
  
  KRWRow<-balanceList[1,]
  balanceList<-merge(balanceList,krwCoinList[,1],by.x="currency",by.y="market")
  balanceList<-rbind(KRWRow,balanceList)
  log_print(balanceList)
  
  balanceList[,market:=paste0("KRW-",currency)]
  topNCoinList<-topNCoinList[,.(name,symbol,price)]
  log_print("CURRENT COIN PRICE")
  price=getCurrentUpbitPrice(balanceList$market[-1])
  price<-rbind(price,as.list(c("KRW-KRW",1)))
  
  balanceList<-merge(balanceList,price,by.x="market",by.y="market")
  balanceList[,trade_price:=as.double(trade_price)]
  curBalanceList<-balanceList[,.(market,currency,balance=balance*trade_price,curvolume=balance)]
  totalBalance<-curBalanceList[,sum(balance)]
  topNCoinList$targetbalance<-totalBalance/num
  
  joinList<-merge(topNCoinList,curBalanceList,by.x="symbol",by.y="currency",all=TRUE)
  joinList<-joinList[symbol!="KRW"]
  joinList[,market:=paste0("KRW-",symbol)]
  minimumOrder<-getMinimumOrderUnit(joinList$market)
  joinList<-merge(joinList,minimumOrder,by.x="market",by.y="market",all=TRUE)
  joinList[is.na(balance)]$balance<-0
  joinList[is.na(targetbalance)]$targetbalance<-0
  joinList[,diff:=targetbalance-balance]
  
  joinList[diff<0][diff>ask_min]$targetbalance<-joinList[diff<0][diff>ask_min]$balance
  joinList[diff>0][diff<bid_min]$targetbalance<-joinList[diff>0][diff<bid_min]$balance
  joinList[,diff:=targetbalance-balance]
  remainedBalance<-totalBalance-joinList[diff==0][,sum(balance)]
  joinList[diff!=0][targetbalance>0]$targetbalance<-remainedBalance/NROW(joinList[diff!=0][targetbalance>0])
  joinList[,diff:=targetbalance-balance]
  
  joinList<-joinList[,.(symbol,diff,curvolume,price)]
  names(joinList)<-c("market","buyamount","currentvolume","price")
  log_print("COIN LIST FOR ORDER")
  log_print(joinList)
  log_close()
  return(joinList)
}
rebalanceWeight<-function(table){
  logPath<-paste0(logDir,"coinLog.",Sys.Date(),".log")
  log_open(logPath)
  
  table<-table[buyamount!=0]
  table[,market:=paste("KRW",market,sep="-")]
  table$ord_type<-'limit'
  table$side<-'bid'
  table[buyamount<0]$side<-'ask'
  table[,buyamount:=abs(buyamount)]
  table[,price:=getCurrentUpbitPrice(table$market)$trade_price]
  table[,volume:=buyamount/price]
  table[side=="ask"][currentvolume<volume]$volume<-table[side=="ask"][currentvolume<volume]$currentvolume
  table<-subset(table,select=c("market","side","volume","price","ord_type"))
  
  log_print("FINAL ORDER LIST")
  log_print(table)
  log_close()  
  if(NROW(table[side=="ask"])>0){
    orderCoin(table[side=="ask"])
    Sys.sleep(3)
  }
  orderCoin(table[side=="bid"])
}
getOrderList<-function(status){
  query<-paste0("state=",status)
  url<-"https://api.upbit.com/v1/orders"
}
orderCoin<-function(order){
  log_open(logPath)
  query<-paste0("market=",order$market,"&side=",order$side,"&volume=",order$volume,"&price=",order$price,"&ord_type=",order$ord_type)
  tokenList<-sapply(query,function(x) createJwtToken(x,runif(1,1000,33553))) 
  url<-"https://api.upbit.com/v1/orders"
  for(i in 1:NROW(order)){
    res<-POST(url,add_headers(Authorization=paste0("Bearer ",tokenList[i])),body=as.list(order[i,]),encode='json')  
    log_print(query)
    log_print(res$status_code)
    log_print(rawToChar(res$content))
    Sys.sleep(0.3)
  }
  log_close()
}
getMinimumOrderUnit<-function(coinList){
  table<-NULL
  query<-paste0("market=",coinList)
  tokenList<-sapply(query,function(x) createJwtToken(x,runif(1,1000,33553)))
  url<-paste0("https://api.upbit.com/v1/orders/chance?",query)
  for(i in 1:length(coinList)){
    res<-GET(url[i],add_headers(Authorization=paste0("Bearer ",tokenList[i])))
    if(res$status_code==200){
      list<-fromJSON(rawToChar(res$content))
      table<-rbind(table,c(coinList[i],list$market$ask$min_total,list$market$bid$min_total))  
    }
  }
  table<-as.data.table(table)
  names(table)<-c("market","ask_min","bid_min")
  table[,ask_min:=as.double(ask_min)]
  table[,bid_min:=as.double(bid_min)]
  table[,ask_min:=-ask_min]
  return(table)
}
