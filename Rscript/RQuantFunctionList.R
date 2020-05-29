pkg = c('magrittr', 'quantmod', 'rvest', 'httr', 'jsonlite',
        'readr', 'readxl', 'stringr', 'lubridate', 'dplyr',
        'tidyr', 'ggplot2', 'corrplot', 'dygraphs',
        'highcharter', 'plotly', 'PerformanceAnalytics',
        'nloptr', 'quadprog', 'RiskPortfolios', 'cccp',
        'timetk', 'broom', 'stargazer','data.table', 'lubridate')

new.pkg = pkg[!(pkg %in% installed.packages()[, "Package"])]
if (length(new.pkg)) {
  install.packages(new.pkg, dependencies = TRUE)}
sapply(pkg,library,character.only=T)

# 최근 영업일 구하기
recentBizDay <- function(){
  url = 'https://finance.naver.com/sise/sise_index.nhn?code=KOSPI'
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
    
    data_IS$name<-'포괄손익계산서'
    data_BS$name<-'재무상태표'
    data_CF$name<-'현금흐름표'
    data_fs<-rbind(data_IS,data_BS,data_CF)
    # 데이터 클랜징
    data_fs[, 1] = gsub('계산에 참여한 계정 펼치기','',data_fs[, 1])
    data_fs = data_fs[!duplicated(data_fs[, 1]), ]
    rownames(data_fs) = NULL
    ftype<-data_fs[,1]
    data_fs<-data_fs[,-1]
    
    Name<-data_fs[,length(names(data_fs))]
    data_fs<-data_fs[,-length(names(data_fs))]
    
    data_fs = sapply(data_fs, function(x) {
      str_replace_all(x, ',', '') %>%
        as.numeric()
    }) %>%
      data.frame(., row.names = rownames(data_fs))
    
    data_fs$'계정'<-ftype
    data_fs$code<-code
    data_fs$'항목'<-Name
    data_fs<-subset(data_fs,select=c(6,7,5,1,2,3,4))
    
    date<-names(data_fs)[4:7]
    date<-str_replace_all(date,'[X]','')
    names(data_fs)[4:7]<-date
    if(type=='Q') {names(data_fs)[4:7]<-date} else{
      month<-substr(date,6,7)
      if(month[length(date)]!=month[1]) data_fs<-data_fs[,-length(names(data_fs))]
    }
    
    data_fs<-as.data.table(data_fs)
    data_fs<-melt.data.table(data_fs,1:3)
    
    names(data_fs)<-c("종목코드","종류","계정","일자","값")
    data_fs$값<-data_fs$값*100000000
    data_fs<-data_fs[!is.na(data_fs$값),]
    return(data_fs)
  })
}

getRecentFSFromFnGuide<-function(type,code){
  data<-getFSFromFnGuide(type,code)
  data$일자<-as.character(data$일자)
  data<-data[data[,일자==max(data$일자)]]
  return(data)
}

getAllCorpsCode<-function(businessDay){
  tickerFrame<-KRXDataMerge(businessDay)
  return(tickerFrame$'종목코드')
}


getAllFS<-function(type, codeList){
  data<-NULL
  for(code in codeList){
    rbind(data,getFSFromFnGuide(type,code))
  }
  return(data)
}
getAllRecentFS<-function(type,codeList, recentDates){
  data<-NULL
  for(code in codeList){
    recentDate<-recentDates[recentDates[,종목코드==code]]$최신일자
    dat <- getRecentFSFromFnGuide(type,code)
    dat <- dat[dat[,일자>recentDate]]
    data<-rbind(data,dat)
  }
  return(data)
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

getPriceList<-function(businessDay, codeList){
  result<-c()
  for(code in codeList){
    result[code]=getCurrentPrice(code)
  }
  return(result)
}

getStockNumberList<-function(businessDay, codeList){
  result<-data.frame(ordinary=double(),preferred=double())
  for(code in codeList){
    result[code,] <- getCurrentStockNumbers(code)
  }
  return(result)
}

cleanDataAndGetFactor<-function(corpData, yearData, quarterData){
  result<-NULL
  tryCatch(
    {
      businessDate<-as.Date(corpData[[1]],format='%Y-%m-%d')
      code<-corpData[[2]]
      yData<-yearData[yearData$종목코드==code,]
      qData<-quarterData[quarterData$종목코드==code,]
      yDate<-as.Date(paste0(yData$일자,'.01'),format='%Y.%m.%d')
      qDate<-as.Date(paste0(qData$일자,'.01'),format='%Y.%m.%d')
      
      monthCrit<-month(yDate[1])
      monthTerm<-rep(3,12)
      monthTerm[monthCrit]<-4
      
      month(yDate)<-month(yDate)+4
      month(qDate)<-month(qDate)+monthTerm[month(qDate)]
      lastYearDate<-businessDate
      year(lastYearDate)<-year(businessDate)-1
      lastlastYearDate<-lastYearDate
      year(lastlastYearDate)<-year(lastYearDate)-1
      
      yData<-yData[yDate<=businessDate & yDate>=lastlastYearDate]
      qData<-qData[qDate<=businessDate & qDate>=lastlastYearDate]
      
      yDate<-yData$일자
      qDate<-qData$일자
      qRank<-frank(-as.double(qDate),ties.method="dense")
      yRank<-frank(-as.double(yDate),ties.method="dense")
      
      if(nrow(yData) == 0 & nrow(qData) == 0){return(result)}
      if(length(unique(qDate))>=4){
        data<-qData[qRank<=4]
      } else{ data<-yData[yRank==1] }
      if(length(unique(qDate))>=5){
        previousData<-qData[qRank>=2 & qRank<=5]
      } else if(length(unique(yDate))>=2) { 
        previousData<-yData[yRank==2] } else{
          previousData<-NULL
        }

      result <- unlist(c(corpData,getCurrentValueQualityFactorQuarter(corpData, data, previousData)))
    },
    error=function(e) print(paste0("Fail to Read: ",code," Date:",businessDate))
  )
  return(result)
}

sumQuarterData<-function(data){
  fs<-data[data$종류=='재무상태표']
  data<-data[data$종류!='재무상태표']
  fs<-fs[fs$일자==max(fs$일자)]
  fs<-fs[,-'일자']
  if(length(unique(data$일자))>1) data<-data[,.(값=sum(값)),by=c('종목코드','종류','계정')] else{
    data<-data[,-'일자']
  }
  names(fs)<-names(data)
  data<-rbind(data,fs)
  return(data)
}

#PER, PBR, PCR, PSR, NCAV, GPA 계산(분기)
getCurrentValueQualityFactorQuarter<-function(corpData, data, previousData){
  
  marketPrice<-corpData$시가총액
  code<-corpData$종목코드
  data<-data[data$종목코드==code]
  
  if(length(unique(data$일자))==4){
    data<-sumQuarterData(data)
  }
  if(!is.null(previousData) & length(unique(previousData$일자))==4){
    previousData<-sumQuarterData(data)
  }
  
  value_index<-c()
  value_type <- c('지배주주순이익','자본','영업활동으로인한현금흐름','매출액','유상증자','매출총이익','영업이익',
                  '유동자산','부채','유상증자','자산','유동부채')

  
  if(!is.null(previousData)){
    tmp<-previousData[previousData[,계정 %in% value_type]]$값
    names(tmp)<-previousData[previousData[,계정 %in% value_type]]$계정
    value_index<-c()
    
    last_value_index<-c()
    last_value_index['지배주주순이익']<-tmp['지배주주순이익'] #수익
    last_value_index['영업활동으로인한현금흐름']<-tmp['영업활동으로인한현금흐름'] #영업현금흐름
    last_value_index['ROA']<-tmp['자산']/tmp['지배주주순이익'] #ROA 증가
    last_value_index['영업활동으로인한현금흐름증가']<-tmp['영업활동으로인한현금흐름']-tmp['지배주주순이익'] #영업현금흐름크기
    last_value_index['부채비율']<-tmp['부채']/tmp['자본'] #부채비율 증가
    last_value_index['유동비율']<-tmp['유동자산']/tmp['유동부채'] #유동비율
    last_value_index['자본']<-tmp['자본'] #신규주식발행
    last_value_index['매출총이익']<-tmp['매출총이익']
    last_value_index['자산회전율']<-tmp['매출액']/tmp['자산']
  }
  
  tmp<-data[data[,계정 %in% value_type]]$값
  names(tmp)<-data[data[,계정 %in% value_type]]$계정
  
  if(!is.na(tmp['지배주주순이익'])){
    value_index['PER']<-tmp['지배주주순이익'] 
  } else if(!is.na(tmp['당기순이익'])){
    value_index['PER']<-tmp['당기순이익']
  }
  value_index['PBR']<-tmp['자본']
  value_index['PCR']<-tmp['영업활동으로인한현금흐름']
  value_index['PSR']<-tmp['매출액']
  value_index['POR']<-tmp['영업이익']
  data_value<-marketPrice/value_index
  data_value['NCAV']<-tmp['유동자산']-tmp['부채']
  if(!is.na(tmp['자산'])) data_value['GPA']<-tmp['매출총이익']/tmp['자산']
  if(!is.na(data_value['PER'])) data_value['ROE']<-data_value['PBR']/data_value['PER']
  if(!is.na(tmp['자본'])) data_value['ROA']<-data_value['ROE']*tmp['자산']/tmp['자본']
  data_value['NCAV_Ratio']<-data_value['NCAV']/marketPrice
  
  
  fscore<-0
  newfscore<-0

  if(!is.na(tmp['지배주주순이익']) & tmp['지배주주순이익']>0) {fscore<-fscore+1; newfscore<-newfscore+1;}
  if(!is.na(tmp['영업활동으로인한현금흐름']) & tmp['영업활동으로인한현금흐름']>0) {fscore<-fscore+1; newfscore<-newfscore+1;}
  if(!is.na(tmp['영업활동으로인한현금흐름']) & !is.na(tmp['지배주주순이익']) 
     & tmp['영업활동으로인한현금흐름']>tmp['지배주주순이익']) fscore<-fscore+1
  
  if(!is.null(previousData)){
    if(!is.na(last_value_index['ROA']) & last_value_index['ROA']<data_value['ROA']) fscore<-fscore+1
    if(!is.na(last_value_index['부채비율']) & !is.na(tmp['자본']) & last_value_index['부채비율']>tmp['부채']/tmp['자본']) fscore<-fscore+1
    if(!is.na(last_value_index['유동비율']) & !is.na(tmp['유동부채'] & last_value_index['유동비율']<tmp['유동자산']/tmp['유동부채'])) fscore<-fscore+1
    if(!is.na(last_value_index['자본']) & last_value_index['자본']==tmp['자본']) {fscore<-fscore+1; newfscore<-newfscore+1;}
    if(!is.na(last_value_index['매출총이익']) & last_value_index['매출총이익']<tmp['매출총이익']) fscore<-fscore+1
    if(!is.na(last_value_index['자산회전율']) & !is.na(tmp['자산']) & last_value_index['자산회전율']<tmp['매출액']/tmp['자산']) fscore<-fscore+1
    
  }

  data_value['F-score']<-fscore
  data_value['New F-score']<-newfscore
  
  return(data_value)
}

addMomentum<-function(businessDay, codeList){
  result<-NULL
  for(code in codeList){
    tryCatch(
      {
        priceList<-adjustedPriceFromNaver('day',365,code)
        Return<-Return.calculate(priceList)
        Return<-Return[!is.na(Return)]
        volatility<-sd(Return)*sqrt(length(Return))
        
        monthPrice<-adjustedPriceFromNaver('month',14,code)[,1]
        latestValue<-monthPrice[13]
        monthlyMomentum<-latestValue/monthPrice[-12:-13]-1
        avgMomentum<-(mean(monthlyMomentum))/volatility
        result2<-rbind(result,unlist(c('종목코드'=code,Momentum=avgMomentum)))
        Sys.sleep(0.3)
      },
      error=function(e) print(paste0("Fail to Read: ",code))
    )
  }
  return(result)
}

winsorizing<-function(val){
  newval<-ifelse(percent_rank(val)>0.99,
                 quantile(val,0.99,na.rm=TRUE),val)
  return(newval)
}

