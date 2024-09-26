pkg = c('httr','data.table','jsonlite')

new.pkg = pkg[!(pkg %in% installed.packages()[, "Package"])]
if (length(new.pkg)) {
  install.packages(new.pkg, dependencies = TRUE)}
sapply(pkg,library,character.only=T)


getToken<-function(apiConfig,account){
  tokenUrl<-paste(apiConfig$url,'/oauth2/tokenP',sep="")
  headers = c(
    'Content-Type' = 'application/json',
    'charset' = 'UTF-8'
  )
  body<-list(grant_type='client_credentials',appkey=account$appkey,appsecret=account$appsecret)
  response<-POST(tokenUrl,add_headers(headers),body=toJSON(body,auto_unbox=T))
  return(content(response)$access_token)
}

revokeToken<-function(apiConfig,account,token){
  tokenUrl<-paste(apiConfig$url,'/oauth2/revokeP',sep="")
  headers = c(
    'Content-Type' = 'application/json',
    'charset' = 'UTF-8'
  )
  body<-list(appkey=account$appkey,appsecret=account$appsecret,token=token)
  response<-POST(tokenUrl,add_headers(headers),body=toJSON(body,auto_unbox=T))
  return(response$status_code==200)
}

getHashkey<-function(body){
  keyUrl<-paste(url,'/uapi/hashkey',sep="")
  headers<-c('Content-Type'='application/json',charset='UTF-8',appkey=appkey,appsecret=appsecret)
  response<-POST(keyUrl,add_headers(headers),body=body)
  return(content(response)$HASH)
}

isHoliday<-function(today){
  base="http://apis.data.go.kr/B090041/openapi/service/SpcdeInfoService/getRestDeInfo"
  year = year(Sys.Date())
  month = month(Sys.Date())
  key="PEWQgyukEMto9hnKQ1YpebLFfE%2F3VGib2d2TZ1XvjKICjFbNfZ8BeQNspNF9avuO%2B%2F4zqnDj2P4rgk2KjjkDgQ%3D%3D"
  url<-paste(base,'?serviceKey=',key,'&pageNo=1&numOfRows=10&solYear=',year,'&solMonth=',sprintf("%02d",month),sep="")
  data<-content(GET(url))$response$body
  holidayList<-c()
  if(data$totalCount>0){
    holidayList<-rbindlist(data$items$item)$locdate
  }
  return(today %in% holidayList)
}

isKoreanTradeOpen<-function(token,apiConfig,account,date){
  holidayUrl<-paste0(apiConfig$url,'/uapi/overseas-price/v1/quotations/price') 
  headers<-c(
    Authorization=paste('Bearer',token),
    appkey=account$appkey,
    appsecret=account$appsecret,
    tr_id='CTCA0903R',
    custtype='P'
  )
  query<-list(BASS_DT=date,CTX_AREA_NK='',CTX_AREA_FK='')
  response<-GET(holidayUrl,add_headers(headers),query=query)
  res<-fromJSON(rawToChar(response$content))
  #revokeToken(apiConfig,account,token)
  if(res$rt_cd!=0) return(-1)
  return(res$output[1,]$opnd_yn)
}

getCurrentOverseasPrice<-function(apiConfig, account, token, code, excdcode){
  priceUrl<-paste0(apiConfig$url,'/uapi/domestic-stock/v1/quotations/chk-holiday') 
  headers<-c(
    Authorization=paste('Bearer',token),
    appkey=account$appkey,
    appsecret=account$appsecret,
    tr_id=apiConfig$overseasCurrentStockPrice
  )
  query<-list(AUTH='',EXCD=excdcode,SYMB=code)
  response<-GET(priceUrl,add_headers(headers),query=query)
  res<-fromJSON(rawToChar(response$content))
  if(res$rt_cd!=0) return(-1)
  return(as.numeric(res$output$last))
}

getCurrentPrice<-function(apiConfig,account, token, code){
  priceUrl<-paste0(apiConfig$url,'/uapi/domestic-stock/v1/quotations/inquire-price') 
  headers<-c(
    Authorization=paste('Bearer',token),
    appkey=account$appkey,
    appsecret=account$appsecret,
    tr_id='FHKST01010100'
  )
  query<-list(FID_COND_MRKT_DIV_CODE='J',FID_INPUT_ISCD=code)
  response<-GET(priceUrl,add_headers(headers),query=query)
  res<-fromJSON(rawToChar(response$content))
  if(res$rt_cd!=0) return(-1)
  return(as.numeric(res$output$stck_prpr))
}
getAvailablePurchaseAmount<-function(token,apiConfig,account){
  url<-paste0(apiConfig$url,'/uapi/overseas-stock/v1/trading/inquire-psamount') 
  headers<-c(
    Authorization=paste('Bearer',token),
    appkey=account$appkey,
    appsecret=account$appsecret,
    tr_id='TTTS3007R'
  )
  query<-list(CANO=substr(account$accNo,1,8),
              ACNT_PRDT_CD=substr(account$accNo,9,10),
              OVRS_EXCG_CD='AMEX',
              ITEM_CD='SPY',
              OVRS_ORD_UNPR='100'
  )
  response<-GET(url,add_headers(headers),query=query)
  res<-fromJSON(rawToChar(response$content))
  if(res$rt_cd!=0) return(-1)
  return(as.numeric(res$output$ovrs_ord_psbl_amt))
}
getPresentOverseasBalancesheet<-function(token,apiConfig,account){
  output<-NULL
  balanceUrl<-paste(apiConfig$url,'/uapi/overseas-stock/v1/trading/inquire-present-balance',sep='')
  #token<-getToken(apiConfig,account)
  headers<-c(
    Authorization=paste('Bearer',token),
    appkey=account$appkey,
    appsecret=account$appsecret,
    tr_id=apiConfig$overseasPresentBalanceTrid
  )
  
  query<-list(CANO=substr(account$accNo,1,8),
              ACNT_PRDT_CD=substr(account$accNo,9,10),
              WCRC_FRCR_DVSN_CD='02',
              NATN_CD='000',
              TR_MKET_CD='00',
              INQR_DVSN_CD='00'
  )
  response<-GET(balanceUrl,add_headers(headers),query=query)
  output$status_code<-response$status_code
  if(response$status_code!=200) return(output)
  res<-fromJSON(rawToChar(response$content))
  output$sheet<-as.data.table(res$output1)
  output$summary<-as.data.table(res$output2)
  output$summary2<-as.data.table(res$output3)
  return(output)
}
getOverseasBalancesheet<-function(token,apiConfig,account, tr_cont='',CTX_AREA_FK200='',CTX_AREA_NK200='',output=NULL){
  balanceUrl<-paste(apiConfig$url,'/uapi/overseas-stock/v1/trading/inquire-balance',sep='')
  #token<-getToken(apiConfig,account)
  headers<-c(
    Authorization=paste('Bearer',token),
    appkey=account$appkey,
    appsecret=account$appsecret,
    tr_id=apiConfig$overseasBalanceTrid,
    tr_cont=tr_cont
  )
  
  query<-list(CANO=substr(account$accNo,1,8),
              ACNT_PRDT_CD=substr(account$accNo,9,10),
              OVRS_EXCG_CD='NASD',
              TR_CRCY_CD='USD',
              CTX_AREA_FK200=CTX_AREA_FK200,
              CTX_AREA_NK200=CTX_AREA_NK200
  )
  response<-GET(balanceUrl,add_headers(headers),query=query)
  output$status_code<-response$status_code
  if(response$status_code!=200) return(output)
  #print(content(response))
  
  res<-fromJSON(rawToChar(response$content))
  output$sheet<-as.data.table(rbind(output$sheet,res$output1))
  tr_cont<-response$headers$tr_cont
  if(tr_cont=='D' | tr_cont=='E'){
    output$rt_cd<-res$rt_cd
    output$msg_cd<-res$msg_cd
    output$msg<-res$msg1
    output$summary<-res$output2
    #revokeToken(apiConfig,account,token)
    return(output)
  } else{
    return(getOverseasBalancesheet(apiConfig,account,'N',res$ctx_area_fk200,res$ctx_area_nk200,output))
  }
}
getBalancesheet<-function(token,apiConfig,account, tr_cont='',CTX_AREA_FK100='',CTX_AREA_NK100='',output=NULL){
  #/uapi/domestic-stock/v1/trading/inquire-balance-rlz-pl #실현손익 포함한 잔고조회
  balanceUrl<-paste(apiConfig$url,'/uapi/domestic-stock/v1/trading/inquire-balance',sep='')
  #token<-getToken(apiConfig,account)
  headers<-c(
             Authorization=paste('Bearer',token),
             appkey=account$appkey,
             appsecret=account$appsecret,
             tr_id=apiConfig$balanceTrid,
             tr_cont=tr_cont
             )
  
  query<-list(CANO=substr(account$accNo,1,8),
              ACNT_PRDT_CD=substr(account$accNo,9,10),
              AFHR_FLPR_YN='N',
              OFL_YN='',
              INQR_DVSN='02',
              UNPR_DVSN='01',
              FUND_STTL_ICLD_YN='N',
              FNCG_AMT_AUTO_RDPT_YN='N',
              PRCS_DVSN='01',
              CTX_AREA_FK100=CTX_AREA_FK100,
              CTX_AREA_NK100=CTX_AREA_NK100
              )
  response<-GET(balanceUrl,add_headers(headers),query=query)
  output$status_code<-response$status_code
  if(response$status_code!=200) return(output)
  #print(content(response))
  
  res<-fromJSON(rawToChar(response$content))
  output$sheet<-as.data.table(rbind(output$sheet,res$output1))
  tr_cont<-response$headers$tr_cont
  if(tr_cont=='D' | tr_cont=='E'){
    output$rt_cd<-res$rt_cd
    output$msg_cd<-res$msg_cd
    output$msg<-res$msg1
    output$summary<-res$output2
    #revokeToken(apiConfig,account,token)
    return(output)
  } else{
    return(getBalancesheet(apiConfig,account,'N',res$ctx_area_fk100,res$ctx_area_nk100,output))
  }
}
cancelAllOrders<-function(apiConfig,account,token){
  orderList<-viewAllOrders(apiConfig,account,token)$output
  #odno: 주문번호, psbl_qty: 취소가능수량
  orderNoList<-orderList$odno
  cancelUrl<-paste0(apiConfig$url,'/uapi/domestic-stock/v1/trading/order-rvsecncl') #취소주문
  headers<-c(
    Authorization=paste('Bearer',token),
    appkey=account$appkey,
    appsecret=account$appsecret,
    tr_id=apiConfig$cancelModifyOrderTrid
  )
  result<-NULL
  for(orderNo in orderNoList){
    body<-list(CANO=substr(account$accNo,1,8),
               ACNT_PRDT_CD=substr(account$accNo,9,10),
               KRX_FWDG_ORD_ORGNO="",
               ORGN_ODNO=orderNo,
               ORD_DVSN='00',
               RVSE_CNCL_DVSN_CD='02',
               ORD_QTY='0',
               ORD_UNPR='0',
               QTY_ALL_ORD_YN='Y'
    )
    response<-POST(cancelUrl,add_headers(headers),body=toJSON(body,auto_unbox=T))
    res<-fromJSON(rawToChar(response$content))
    result<-c(result,res)
  }
  return(result)
}
viewAllOrders<-function(apiConfig,account,token,CTX_AREA_FK100='',CTX_AREA_NK100='',output=NULL){
  viewUrl<-paste0(apiConfig$url,'/uapi/domestic-stock/v1/trading/inquire-psbl-rvsecncl') #취소가능한 주문목록
  headers<-c(
    Authorization=paste('Bearer',token),
    appkey=account$appkey,
    appsecret=account$appsecret,
    tr_id=apiConfig$viewAllOrdersTrid
  )
  query<-list(CANO=substr(account$accNo,1,8),
              ACNT_PRDT_CD=substr(account$accNo,9,10),
              CTX_AREA_FK100=CTX_AREA_FK100,
              CTX_AREA_NK100=CTX_AREA_NK100,
              INQR_DVSN_1=0,
              INQR_DVSN_2=0
  )
  response<-GET(viewUrl,add_headers(headers),query=query)
  output$status_code<-response$status_code
  if(response$status_code!=200) return(output)
  
  res<-fromJSON(rawToChar(response$content))
  output$sheet<-as.data.table(rbind(output$sheet,res$output))
  tr_cont<-response$headers$tr_cont
  if(tr_cont=='D' | tr_cont=='E'){
    output$rt_cd<-res$rt_cd
    output$msg_cd<-res$msg_cd
    output$msg<-res$msg1
    return(output)
  } else{
    return(getBalancesheet(apiConfig,account,'N',res$ctx_area_fk100,res$ctx_area_nk100,output))
  }
}

getOrderableAmount<-function(apiConfig,account,token,code){
  url<-paste0(apiConfig$url,'/uapi/domestic-stock/v1/trading/inquire-psbl-order') #현금주문
  headers<-c(
    Authorization=paste('Bearer',token),
    appkey=account$appkey,
    appsecret=account$appsecret,
    tr_id=apiConfig$getOrderableAmountTrid
  )
  query<-list(CANO=substr(account$accNo,1,8),
              ACNT_PRDT_CD=substr(account$accNo,9,10),
              PDNO=code,
              ORD_UNPR="",
              ORD_DVSN="00",
              CMA_EVLU_AMT_ICLD_YN="N",
              OVRS_ICLD_YN="Y"
  )
  response<-GET(url,add_headers(headers),query=query)
  response$status_code
  if(response$status_code!=200) return(NULL)
  
  res<-fromJSON(rawToChar(response$content))
  return(as.numeric(res$output$nrcvb_buy_amt))
}

orderStock<-function(apiConfig,account,token,code,qty,price){
  if(qty==0) return(NULL)
  if(qty>0) tr_id=apiConfig$buyTrid
  if(qty<0) tr_id=apiConfig$sellTrid
  
  orderUrl<-paste0(apiConfig$url,'/uapi/domestic-stock/v1/trading/order-cash') #현금주문
  headers<-c(
    Authorization=paste('Bearer',token),
    appkey=account$appkey,
    appsecret=account$appsecret,
    tr_id=tr_id
  )
  body<-list(CANO=substr(account$accNo,1,8),
              ACNT_PRDT_CD=substr(account$accNo,9,10),
              PDNO=code,
              ORD_DVSN='00',
              ORD_QTY=as.character(abs(qty)),
              ORD_UNPR=as.character(price)
  )
  response<-POST(orderUrl,add_headers(headers),body=toJSON(body,auto_unbox=T))
  res<-fromJSON(rawToChar(response$content))
  res$output<-NULL
  res$code<-code
  res$qty<-qty
  res$price<-price
  return(res)
}

orderStocks<-function(token,apiConfig, account, stockTable){
  if(nrow(stockTable)==0) return(NULL)
  #token<-getToken(apiConfig,account)
  res<-NULL
  for(i in 1:nrow(stockTable)){
    code<-stockTable[i,]$종목코드
    price<-getCurrentPrice(apiConfig,account,token,code)
    curQty<-stockTable[i,]$보유수량
    priceSum<-min(getOrderableAmount(apiConfig,account,token,code), stockTable[i,]$목표금액-price*curQty)
    if(stockTable[i,]$목표금액==0) priceSum<-getOrderableAmount(apiConfig,account,token,code)
    qty<-floor(priceSum/price)
    if(qty==0){
      print(paste0(code,": qty 0"))
      next;
    }
    print(paste("code:",code," name:",stockTable[i,]$종목명," qty:",qty," price:",price, " ordersum:",qty*price))
    r<-orderStock(apiConfig,account,token,code,qty,price)
    r$idx<-i
    print(paste("rc_cd:",r$rt_cd," msg_cd:",r$msg_cd," msg:",r$msg1))
    res<-rbind(res,as.data.table(r))
    Sys.sleep(0.1)
  }
  #revokeToken(apiConfig,account,token)
  return(res)
}


orderOverseasStock<-function(apiConfig,account,token,excdcode,code,qty,price,ordertype){
  if(qty==0) return(NULL)
  if(qty>0) tr_id=apiConfig$buyOverseasTrid
  if(qty<0) tr_id=apiConfig$sellOverseasTrid
  
  #print(tr_id)
  orderUrl<-paste0(apiConfig$url,'/uapi/overseas-stock/v1/trading/order') #현금주문
  headers<-c(
    Authorization=paste('Bearer',token),
    appkey=account$appkey,
    appsecret=account$appsecret,
    tr_id=tr_id
  )
  body<-list(CANO=substr(account$accNo,1,8),
             ACNT_PRDT_CD=substr(account$accNo,9,10),
             OVRS_EXCG_CD=excdcode,
             PDNO=code,
             ORD_QTY=as.character(abs(qty)),
             OVRS_ORD_UNPR=as.character(round(price,2)),
             ORD_SVR_DVSN_CD='0',
             ORD_DVSN=as.character(ordertype)
  )
  response<-POST(orderUrl,add_headers(headers),body=toJSON(body,auto_unbox=T))
  res<-fromJSON(rawToChar(response$content))
  res$output<-NULL
  res$code<-code
  res$qty<-qty
  res$price<-price
  return(res)
}

orderOverseasStocks<-function(token,apiConfig, account, stockTable){
  if(nrow(stockTable)==0) return(NULL)
  #token<-getToken(apiConfig,account)
  res<-NULL
  for(i in 1:nrow(stockTable)){
    code<-stockTable[i,]$종목코드
    excdcode2<-stockTable[i,]$거래소_현재가
    excdcode<-stockTable[i,]$거래소
    ordertype<-stockTable[i,]$주문구분
    price<-getCurrentOverseasPrice(apiConfig,account,token,code,excdcode2)
    curQty<-stockTable[i,]$보유수량
    priceSum<-stockTable[i,]$목표금액-price*curQty
    priceSum<-min(priceSum,getAvailablePurchaseAmount(token,apiConfig,account))
    if(sign(priceSum)!=sign(stockTable[i,]$signal)) { next }
    if(ordertype=='34') price<-price*(1+sign(priceSum)/100) #LOC 매수/매도는 일부러 가격을 변경
    qty<-floor(priceSum/price)
    print(paste("code:",code," name:",stockTable[i,]$종목명," qty:",qty," price:",price, " ordersum:",qty*price))
    if(qty==0){
      print("skip order: qty is 0")
      next;
    }
    r<-orderOverseasStock(apiConfig,account,token,excdcode,code,qty,price,ordertype)
    r$idx<-i
    print(paste("rc_cd:",r$rt_cd," msg_cd:",r$msg_cd," msg:",r$msg1))
    res<-rbind(res,as.data.table(r))
    Sys.sleep(0.1)
  }
  #revokeToken(apiConfig,account,token)
  return(res)
}
