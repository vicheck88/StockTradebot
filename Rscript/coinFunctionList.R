#setwd("C:/Users/vicen/Documents/Github/StockTradebot/Rscript")

pkg = c('quantmod','jsonlite', 'stringr', 'logr',
        'jose','openssl','PerformanceAnalytics','xts','curl','data.table',
        'httr')
new.pkg = pkg[!(pkg %in% installed.packages()[, "Package"])]

logDir<-"/home/pi/stockInfoCrawler/StockTradebot/log"
#logDir<-"C:/coinTestLog"

if (length(new.pkg)) {
  install.packages(new.pkg, dependencies = TRUE)}
sapply(pkg,library,character.only=T)

getCoinMarketCapList<-function(num){
  coinMarket_api_key<-"7a53f6d1-41fd-4658-836a-b59e6432f5cf"
  url<-paste0("https://pro-api.coinmarketcap.com/v1/cryptocurrency/listings/latest?limit=",num)
  h<-new_handle()
  handle_setheaders(h, .list=list("X-CMC_PRO_API_KEY"=coinMarket_api_key, Accepts="application/json"))

  
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
getUpbitCoinListDetail<-function(num){
  coinMarketCapTable<-getCoinMarketCapList(num)
  #coinMarketCapTable$name<-toupper(coinMarketCapTable$name)
  upbitCoinTable<-getUpbitCoinList()
  #upbitCoinTable$english_name<-toupper(upbitCoinTable$english_name)
  coinTable<-coinMarketCapTable[upbitCoinTable,on=c(symbol="market")]
  coinTable<-coinTable[order(-market_cap)]
  coinTable<-unique(coinTable,fromLast=FALSE,by="symbol")
  coinTable<-na.omit(coinTable)
  coinTable<-subset(coinTable,select=-english_name)
  return(coinTable)
}
getTopNUpbitCoinList<-function(coinLimit, num){
  return(getUpbitCoinListDetail(coinLimit)[1:num,])
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
  #type: minutes, days, weeks, months
  #unit: 분봉(minutes), 상관없음(others)
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
  #priceType: opening_price, high_price, low_price, trade_price
  priceList<-getCoinPriceHistory(coinList,candleType,unit,count)
  priceList<-subset(priceList,select=c("market","candle_date_time_kst",priceType))
  priceList[,prevPrice:=shift(get(priceType),momentumPeriod,NA,"lead"),by=market]
  priceList<-na.omit(priceList)
  priceList[,momentum:=get(priceType)/prevPrice*100]
  return(subset(priceList,select=c("market","candle_date_time_kst","momentum")))
}
getUpbitCoinMomentum<-function(candleType,unit,momentumPeriod, coinList){
  coinList<-paste("KRW",coinList$symbol,sep="-")
  momentum<-getMomentumHistory(coinList,candleType,unit,momentumPeriod+1,"trade_price",momentumPeriod)
  return(momentum)
}

getCurrentBalance<-function(){
  logPath<-paste0(logDir,"coinLog.",Sys.Date(),".log")
  log_open(logPath)
  
  log_print("CURRENT BALANCE")
  krwCoinList<-getUpbitCoinList()
  balanceList<-getCurrentUpbitAccountInfo()
  
  KRWRow<-balanceList[1,]
  balanceList<-merge(balanceList,krwCoinList[,1],by.x="currency",by.y="market")
  balanceList<-rbind(KRWRow,balanceList)
  log_print(balanceList)
  
  balanceList[,market:=paste0("KRW-",currency)]
  log_print("CURRENT COIN PRICE")
  price=getCurrentUpbitPrice(balanceList$market[-1])
  price<-rbind(price,as.list(c("KRW-KRW",1)))
  
  balanceList<-merge(balanceList,price,by.x="market",by.y="market")
  balanceList[,trade_price:=as.double(trade_price)]
  curBalanceList<-balanceList[,.(market,currency,balance=balance*trade_price,curvolume=balance)]
  return(curBalanceList)
}

getMomentumBalance<-function(coinList,num,limitRatio,type,momentumList){
  momentumList[,symbol:=sapply(strsplit(market,"-"),function(x)x[2])]
  momentumList <- coinList[momentumList,on=c("symbol"),nomatch=0]
  momentumList<-na.omit(momentumList)
  momentumList<-momentumList[order(-momentum)]
  momentumList<-momentumList[,.(symbol,market,market_cap)]
  if(type=="MARKET"){
    momentumList[,ratio:=market_cap/sum(market_cap)*limitRatio]  
  } else if(type=="EQUAL"){
    momentumList[,ratio:=1/num*limitRatio]  
  }
  return(momentumList[1:num,])
}

getIndexBalance<-function(coinList, limitRatio, type){
  coinList[,market:=paste0("KRW-",symbol)]
  coinList<-coinList[,.(symbol,market,market_cap)]
  
  num<-NROW(coinList)
  if(type=="MARKET"){
    coinList[,ratio:=market_cap/sum(market_cap)*limitRatio]  
  } else if(type=="EQUAL"){
    coinList[,ratio:=1/num*limitRatio]  
  }
  return(coinList)
}
createOrderTable<-function(table,currentBalance){
  totalBalance<-sum(currentBalance$balance)
  balanceCombinedTable<-merge(table,currentBalance,by="market",all=TRUE)
  balanceCombinedTable[,totalBalance:=totalBalance]
  balanceCombinedTable<-balanceCombinedTable[market!="KRW-KRW"]
  balanceCombinedTable[,targetBalance:=totalBalance*ratio]
  
  minimumOrder<-getMinimumOrderUnit(balanceCombinedTable$market)
  balanceCombinedTable<-merge(balanceCombinedTable,minimumOrder,by.x="market",by.y="market",all=TRUE)
  
  balanceCombinedTable[is.na(balance)]$balance<-0
  balanceCombinedTable[is.na(targetBalance)]$targetBalance<-0
  balanceCombinedTable[is.na(ratio)]$ratio<-0
  balanceCombinedTable[is.na(curvolume)]$curvolume<-0
  balanceCombinedTable[,diff:=targetBalance-balance]
  
  balanceCombinedTable[diff<0][diff>ask_min]$targetBalance<-balanceCombinedTable[diff<0][diff>ask_min]$balance
  balanceCombinedTable[diff>0][diff<bid_min]$targetBalance<-balanceCombinedTable[diff>0][diff<bid_min]$balance
  balanceCombinedTable[,diff:=targetBalance-balance]
  balanceCombinedTable[,sellall:=targetBalance==0]
  
  
  remainedBalance<-totalBalance-balanceCombinedTable[diff==0][,sum(balance)]
  
  if(remainedBalance!=totalBalance){
    balanceCombinedTable[diff!=0]$targetBalance<-balanceCombinedTable[diff!=0][,ratio]*remainedBalance  
    balanceCombinedTable[,diff:=targetBalance-balance]
  }
  
  balanceCombinedTable<-balanceCombinedTable[,.(market,diff,curvolume,sellall)]
  names(balanceCombinedTable)<-c("market","buyamount","currentvolume","sellall")
  return(balanceCombinedTable)
}


rebalanceTable<-function(table){
  logPath<-paste0(logDir,"coinLog.",Sys.Date(),".log")
  log_open(logPath)
  table<-table[buyamount!=0]
  table$ord_type<-'limit'
  table$side<-'bid'
  table[buyamount<0]$side<-'ask'
  table[,buyamount:=abs(buyamount)]
  table[,price:=getCurrentUpbitPrice(table$market)$trade_price]
  table[,volume:=buyamount/price]
  table[sellall==T]$volume<-table[sellall==T]$currentvolume
  table[side=="ask"][currentvolume<volume]$volume<-table[side=="ask"][currentvolume<volume]$currentvolume
 
  log_open()
  
  table<-subset(table,select=c("market","side","volume","price","ord_type"))
  log_print("Final Table List")
  log_print(table)
  log_close()
  
  if(NROW(table[side=="ask"])>0){
    orderCoin(table[side=="ask"])
    Sys.sleep(5)
  }
  orderCoin(table[side=="bid"])
}

orderCoin<-function(order){
  logPath<-paste0(logDir,"coinLog.",Sys.Date(),".log")
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
