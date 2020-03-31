pkg = c('magrittr', 'quantmod', 'rvest', 'httr', 'jsonlite',
        'readr', 'readxl', 'stringr', 'lubridate', 'dplyr',
        'tidyr', 'ggplot2', 'corrplot', 'dygraphs',
        'highcharter', 'plotly', 'PerformanceAnalytics',
        'nloptr', 'quadprog', 'RiskPortfolios', 'cccp',
        'timetk', 'broom', 'stargazer','data.table')

new.pkg = pkg[!(pkg %in% installed.packages()[, "Package"])]
if (length(new.pkg)) {
  install.packages(new.pkg, dependencies = TRUE)}
sapply(pkg,library,character.only=T)

# 최근 영업일 구하기
recentBizDay <- function(){
  url = 'https://finance.naver.com/sise/sise_deposit.nhn'
  biz_day = GET(url) %>%
    read_html(encoding = 'EUC-KR') %>%
    html_nodes(xpath =
                 '//*[@id="time"]') %>% 
    html_text() %>%
    str_match(('[0-9]+.[0-9]+.[0-9]+') ) %>%
    str_replace_all('\\.', '')
}


KRXIndStat <- function(businessDay){
  # 산업별 현황 OTP 발급
  gen_otp_url =
    'http://marketdata.krx.co.kr/contents/COM/GenerateOTP.jspx'
  gen_otp_data = list(
    name = 'fileDown',
    filetype = 'csv',
    url = 'MKD/03/0303/03030103/mkd03030103',
    tp_cd = 'ALL',
    date = businessDay, # 최근영업일로 변경
    lang = 'ko',
    pagePath = '/contents/MKD/03/0303/03030103/MKD03030103.jsp')
  otp = POST(gen_otp_url, query = gen_otp_data) %>%
    read_html() %>%
    html_text()
  # 산업별 현황 데이터 다운로드
  down_url = 'http://file.krx.co.kr/download.jspx'
  down_sector = POST(down_url, query = list(code = otp),
                     add_headers(referer = gen_otp_url)) %>%
    read_html() %>%
    html_text() %>%
    read_csv()
}

KRXIndividualStat<-function(businessDay){
  # 개별종목 지표 OTP 발급
  gen_otp_url =
    'http://marketdata.krx.co.kr/contents/COM/GenerateOTP.jspx'
  gen_otp_data = list(
    name = 'fileDown',
    filetype = 'csv',
    url = "MKD/13/1302/13020401/mkd13020401",
    market_gubun = 'ALL',
    gubun = '1',
    schdate = businessDay, # 최근영업일로 변경
    pagePath = "/contents/MKD/13/1302/13020401/MKD13020401.jsp")
  
  otp = POST(gen_otp_url, query = gen_otp_data) %>%
    read_html() %>%
    html_text()
  
  # 개별종목 지표 데이터 다운로드
  down_url = 'http://file.krx.co.kr/download.jspx'
  down_ind = POST(down_url, query = list(code = otp),
                  add_headers(referer = gen_otp_url)) %>%
    read_html() %>%
    html_text() %>%
    read_csv()
}

KRXDataMerge<-function(businessDay){
  down_sector<-KRXIndStat(businessDay)
  down_ind<-KRXIndividualStat(businessDay)
  #데이터 정리(개별종목, 산업현황 데이터 병합)
  intersect(names(down_sector),names(down_ind)) #겹치는 항목
  setdiff(down_sector[,'종목명'],down_ind[,'종목명']) #겹치지 않은 종목 ->제외(일반적이지 않은 종목들)
  
  KOR_ticker = merge(down_sector, down_ind,
                     by = intersect(names(down_sector),
                                    names(down_ind)),
                     all = FALSE
  )
  setDT(KOR_ticker)
  setorder(KOR_ticker,'시가총액(원)') #시가총액으로 정렬
  
  KOR_ticker <- KOR_ticker[!grepl('스팩', KOR_ticker$'종목명'),] 
  KOR_ticker <- KOR_ticker[str_sub(KOR_ticker$'종목코드', -1, -1) == 0,] #우선주
}

WICSSectorInfo<-function(businessDay){
  #각 섹터별로 정보 얻기
  # 10: 에너지, 15: 소재, 20: 산업재, 25: 경기관련소비재, 30: 필수소비재, 35: 건강관리
  # 40: 금융, 45: IT, 50: 커뮤니케이션서비스, 55: 유틸리티
  sector_code = c('G25', 'G35', 'G50', 'G40', 'G10',
                  'G20', 'G55', 'G30', 'G15', 'G45')
  data_sector = list()
  for (i in sector_code) {
    url = paste0(
      'http://www.wiseindex.com/Index/GetIndexComponets',
      '?ceil_yn=0&dt=',businessDay,'&sec_cd=',i)
    data = fromJSON(url)
    data = data$list
    
    data_sector[[i]] = data
    
    Sys.sleep(1)
  }
  data_sector = do.call(rbind, data_sector)
}

#KRX 데이터와 WICS데이터 조인 -> 특정 날에 존재한 기업에 대한 정보 획득
mergeWICSKRX<-function(businessDay){
  KRX<-KRXDataMerge(businessDay)
  WICS<-WICSSectorInfo(businessDay)[,c(1,2,4)]
  table<-merge(WICS,KRX,by.x="CMP_CD",by.y="종목코드")
  setnames(table,old=c("CMP_CD","IDX_CD","IDX_NM_KOR"),new=c("종목코드","섹션IDX","섹션"))
  return(table)
}


adjustedPriceFromNaver<-function(interval, cnt, code){
    # 오류 발생 시 이를 무시하고 다음 루프로 진행
    tryCatch({
      # url 생성
      url = paste0(
        'https://fchart.stock.naver.com/sise.nhn?symbol='
        ,code,'&timeframe=',interval,'&count=',cnt,'&requestType=0')
      
      # 이 후 과정은 위와 동일함
      # 데이터 다운로드
      data = GET(url)
      data_html = read_html(data, encoding = 'EUC-KR') %>%
        html_nodes("item") %>%
        html_attr("data") 
      
      # 데이터 나누기
      price = read_delim(data_html, delim = '|')
      
      # 필요한 열만 선택 후 클렌징
      price = price[c(1, 5)] 
      price = data.frame(price)
      colnames(price) = c('Date', code)
      price[, 1] = ymd(price[, 1])
      
      rownames(price) = price[, 1]
      price[, 1] = NULL
      return(price)
      
    }, error = function(e) {
      # 오류 발생시 해당 종목명을 출력
      warning(paste0("Error in Ticker: ", code))
    })
}

#각 월별 마지막 거래일 출력
getLastBizdayofMonth<-function(cnt){
  return(rownames(adjustedPriceFromNaver('month',cnt,'005930')))
}


getFSFromFnGuide <- function(type, code){
  if(type=="Y") r=1 else r=2
  data_fs = c()
  data_value = c()
  tryCatch({
    Sys.setlocale('LC_ALL', 'English')
    # url 생성
    url = paste0(
      'https://comp.fnguide.com/SVO2/ASP/'
      ,'SVD_Finance.asp?pGB=1&gicode=A',
      code)
    # 이 후 과정은 위와 동일함
    # 데이터 다운로드 후 테이블 추출
    data = GET(url) %>%
      read_html() %>%
      html_table()
    
    Sys.setlocale('LC_ALL', 'Korean')
    
    idxList<-0:2*2+r

    # 3개 재무제표를 하나로 합치기    
    data_IS<-data[[idxList[1]]]
    data_BS<-data[[idxList[2]]]
    data_CF<-data[[idxList[3]]]
    data_IS<-data_IS[, 1:(ncol(data_IS)-2)]
    data_fs<-rbind(data_IS,data_BS,data_CF)
    
    # 데이터 클랜징
    data_fs[, 1] = gsub('계산에 참여한 계정 펼치기','',data_fs[, 1])
    data_fs = data_fs[!duplicated(data_fs[, 1]), ]
    rownames(data_fs) = NULL
    rownames(data_fs) = data_fs[, 1]
    data_fs[, 1] = NULL
    
    data_fs = sapply(data_fs, function(x) {
      str_replace_all(x, ',', '') %>%
        as.numeric()
    }) %>%
      data.frame(., row.names = rownames(data_fs))
    
    return(data_fs)
  })
}

getCurrentPrice<-function(code){
  url = paste0('https://comp.fnguide.com/SVO2/ASP/SVD_main.asp?pGB=1&gicode=A',code)
  data = GET(url)
  
  price = read_html(data) %>%
    html_node(xpath = '//*[@id="svdMainChartTxt11"]') %>%
    html_text() %>%
    parse_number()
  return(price)
}
#현재 주식 수
getCurrentStockNumbers<-function(code){
  url = paste0('https://comp.fnguide.com/SVO2/ASP/SVD_main.asp?pGB=1&gicode=A',code)
  data = GET(url)
  share = read_html(data) %>%
    html_node(xpath = '//*[@id="svdMainGrid1"]/table/tbody/tr[7]/td[1]') %>%
    html_text() %>%
    strsplit('/') %>%
    unlist() %>%
    parse_number()
  return(share)
}
#현재 보통주 수
getCurrentOrdinaryStockNumbers<-function(code){
  return(getCurrentStockNumbers(code)[1])
}
#현재 우선주 수
getCurrentPreferredStockNumbers<-function(code){
  return(getCurrentStockNumbers(code)[2])
}
#PER, PBR, PCR, PSR, NCAV + 신F스코어, GPA 계산(분기)
getCurrentValueQualityFactorQuarter<-function(code){
  fs <- getFSFromFnGuide('Q',code)
  value_type <- c('지배주주순이익','자본','영업활동으로인한현금흐름','매출액','유상증자','매출총이익')
  
  ordinaryStockNums<-getCurrentOrdinaryStockNumbers(code)
  curPrice<-getCurrentPrice(code)
  
  value_index<-c()
  tmp<-rowSums(fs[value_type,])
  value_index['PER']<-tmp['지배주주순이익']
  value_index['PBR']<-fs['자본',4]
  value_index['PCR']<-tmp['영업활동으로인한현금흐름']
  value_index['PSR']<-tmp['매출액']
  
  data_value<-curPrice/(value_index*100000000/ordinaryStockNums)
  data_value['NCAV']<-(fs['유동자산',]-fs['부채',])[4]*100000000
  
  data_value['NewFScore']<-(tmp['지배주주순이익']>0) + (tmp['영업활동으로인한현금흐름']>0) + (all(is.na(tmp['유상증자'])))
  data_value['GPA']<-tmp['매출총이익']/fs['자산',4]
  
  data_value[data_value<0]<-NA
  return(data_value)
}

winsorizing<-function(val){
  newval<-ifelse(percent_rank(val)>0.99,
                 quantile(val,0.99,na.rm=TRUE),val)
  return(newval)
}
objective = function(w) {
  obj = t(w) %*% covmat %*% w
  return(obj)
}
hin.objective = function(w) {
  return(w)
}
heq.objective = function(w) {
  sum_w = sum(w)
  return( sum_w - 1 )
}

getMVPRatio<-function(resulTable){
  covmat<-getCovarianceMarix(result$'종목코드')
  result = slsqp( x0 = rep(0.1, 10),
                  fn = objective,
                  hin = hin.objective,
                  heq = heq.objective)
  resulTable$'투자비율'<-round(result$par,4)
  return(resultTable)
}

