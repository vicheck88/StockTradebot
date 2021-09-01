pkg = c('curl','data.table')

new.pkg = pkg[!(pkg %in% installed.packages()[, "Package"])]
if (length(new.pkg)) {
  install.packages(new.pkg, dependencies = TRUE)}
sapply(pkg,library,character.only=T)

coinMarket_api_key<-"7a53f6d1-41fd-4658-836a-b59e6432f5cf"

h<-new_handle()
handle_setheaders(h, .list=list("X-CMC_PRO_API_KEY"=coinMarket_api_key, Accepts="application/json"))
url<-"https://pro-api.coinmarketcap.com/v1/cryptocurrency/listings/latest"
r <- curl_fetch_memory(url, h)
result<-fromJSON(rawToChar(r$content))$data
priceList<-result$quote$USD
coinMarketTable<-data.table(name=result$name,symbol=result$symbol,priceList)
coinMarketTable<-coinMarketTable[order(-market_cap)]
