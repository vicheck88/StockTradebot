pkg = c('httr','data.table','jsonlite')
new.pkg = pkg[!(pkg %in% installed.packages()[, "Package"])]
if (length(new.pkg)) {
  install.packages(new.pkg, dependencies = TRUE)}
sapply(pkg,library,character.only=T)

#config<-fromJSON("~/config.json")
#telegramApi<-config$telegram
#token<-telegramApi$token
#chatId<-telegramApi$charid

token<-'6037996673:AAFZKhcVpxI3ZmUAIp8nt8SBgmby6_p-0BI'
chatId<-'5889990804'

telegramUrl<-"https://api.telegram.org/"

sendMessage<-function(text){
  url<-paste0(telegramUrl,"bot",token,"/sendMessage?chat_id=",chatId,"&text=",text)
  response<-POST(url)
  print(paste0("sendMessage: ",response$status_code))
}
