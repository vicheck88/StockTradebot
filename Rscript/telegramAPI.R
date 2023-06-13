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
<<<<<<< HEAD
  url<-paste0(telegramUrl,"bot",token,"/sendMessage?chat_id=",chatId,"&text=",URLencode(text))
=======
  telegramInfo<-getTelegramInfo()
  url<-paste0(telegramUrl,"bot",telegramInfo$token,"/sendMessage?chat_id=",telegramInfo$chatId,"&text=",URLencode(text))
>>>>>>> 8747992209be075ed7e72bdd0e7c058ddb4a50b7
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

