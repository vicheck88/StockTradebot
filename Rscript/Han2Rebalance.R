#Sys.setlocale('LC_ALL','en_US.UTF-8')
source("~/StockTradebot/Rscript/Han2FunctionList.R") #macOS에서 읽는 경우
source("~/StockTradebot/Rscript/telegramAPI.R") #macOS에서 읽는 경우
#source("~/stockInfoCrawler/StockTradebot/Rscript/Han2FunctionList.R") #라즈베리에서 읽는 경우
#source("~/stockInfoCrawler/StockTradebot/Rscript/telegramAPI.R") #라즈베리에서 읽는 경우

pkg = c('stringr')

new.pkg = pkg[!(pkg %in% installed.packages()[, "Package"])]
if (length(new.pkg)) {
  install.packages(new.pkg, dependencies = TRUE)}
sapply(pkg,library,character.only=T)

config<-fromJSON("~/config.json")
#apiConfig<-config$api$config$dev
apiConfig<-config$api$config$prod

#account<-config$api$account$dev
account<-config$api$account$prod$main

today<-str_replace_all(Sys.Date(),"-","")
token<-getToken(apiConfig,account)
if(isKoreanHoliday(token,apiConfig,account,today)=="N") stop("Market closed")
