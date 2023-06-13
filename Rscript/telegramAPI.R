pkg = c('httr','data.table','jsonlite')
new.pkg = pkg[!(pkg %in% installed.packages()[, "Package"])]
if (length(new.pkg)) {
  install.packages(new.pkg, dependencies = TRUE)}
sapply(pkg,library,character.only=T)

config<-fromJSON("~/config.json")
telegramApi<-config$telegram
token<-telegramApi$token
chatId<-telegramApi$chatId

telegramUrl<-"https://api.telegram.org/"

sendMessage<-function(text,count=0){
  url<-paste0(telegramUrl,"bot",token,"/sendMessage?chat_id=",chatId,"&text=",URLencode(text))
  tryCatch(
    print(paste0("sendMessage: ",POST(url)$status_code)),
    error=function(e){
      print(paste0("error: ",e))
      print(paste0("send again: count ",count))
      Sys.sleep(2)
      if(count<10) sendMessage(text,count+1)
      }
    )
}

