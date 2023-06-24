pkg = c('httr','data.table','jsonlite')
new.pkg = pkg[!(pkg %in% installed.packages()[, "Package"])]
if (length(new.pkg)) {
  install.packages(new.pkg, dependencies = TRUE)}
sapply(pkg,library,character.only=T)

getTelegramInfo<-function(){
  config<-fromJSON("~/config.json")
  telegramApi<-config$telegram
  telegramApi$telegramUrl<-"https://api.telegram.org/"
  return(telegramApi)
}

sendMessage<-function(text,count=0){
  telegramInfo<-getTelegramInfo()
  url<-paste0(telegramInfo$telegramUrl,"bot",telegramInfo$token,"/sendMessage?chat_id=",telegramInfo$chatId,"&text=",URLencode(text))
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

