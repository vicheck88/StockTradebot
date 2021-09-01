source("coinMarketCap.R")

#upbit 리스트조회
url<-'https://api.upbit.com/v1/market/all?isDetails=false'
h<-new_handle()
handle_setheaders(h, .list=list(Accepts="application/json"))
r <- curl_fetch_memory(url, h)
upbitCoinTable<-rawToChar(r$content)
Encoding(upbitCoinTable)<-"UTF-8"
upbitCoinTable<-as.data.table(fromJSON(upbitCoinTable))
upbitCoinTable<-upbitCoinTable[substr(market,1,3)=="KRW"]
upbitCoinTable[,market:=str_replace(market,"KRW-","")]

#coinmarketcap과 join
coinTable<-coinMarketTable[upbitCoinTable,on=c(symbol="market"),nomatch=0]
coinTable<-coinTable[order(-market_cap)]
coinTable<-subset(coinTable,select=-english_name)




