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


KRXIndStat <- function(businessDay,type){
  # 산업별 현황 OTP 발급
  gen_otp_url =
    'http://data.krx.co.kr/comm/fileDn/GenerateOTP/generate.cmd'
  gen_otp_data = list(
    mktId = type,
    trdDd = businessDay,
    money = '1',
    csvxls_isNo = 'false',
    name = 'fileDown',
    url='dbms/MDC/STAT/standard/MDCSTAT03901'
    )
  otp = POST(gen_otp_url, query = gen_otp_data) %>%
    read_html() %>%
    html_text()
  # 산업별 현황 데이터 다운로드
  down_url = 'http://data.krx.co.kr/comm/fileDn/download_csv/download.cmd'
  down_sector = POST(down_url, query = list(code = otp)) %>%
    read_html(.,encoding='cp949') %>%
    html_text() %>%
    read_csv()
}
KRXIndividualStat<-function(businessDay){
  # 개별종목 지표 OTP 발급
  gen_otp_url =
    'http://data.krx.co.kr/comm/fileDn/GenerateOTP/generate.cmd'
  gen_otp_data = list(
    searchType = '1',
    mktId = 'ALL',
    csvxls_isNo = "false",
    name = 'fileDown',
    url = 'dbms/MDC/STAT/standard/MDCSTAT03501',
    trdDd = businessDay # 최근영업일로 변경
    )
  
  otp = POST(gen_otp_url, query = gen_otp_data) %>%
    read_html() %>%
    html_text()
  
  # 개별종목 지표 데이터 다운로드
  down_url = 'http://data.krx.co.kr/comm/fileDn/download_csv/download.cmd'
  down_ind = POST(down_url, query = list(code = otp)) %>%
    read_html(.,encoding='cp949') %>%
    html_text() %>%
    read_csv()
}
KRXMonitoringStat<-function(){
  # 개별종목 지표 OTP 발급
  gen_otp_url =
    'http://data.krx.co.kr/comm/fileDn/GenerateOTP/generate.cmd'
  gen_otp_data = list(
    mktId = 'ALL',
    csvxls_isNo = "false",
    name = 'fileDown',
    url = 'dbms/MDC/STAT/standard/MDCSTAT02001'
  )
  
  otp = POST(gen_otp_url, query = gen_otp_data) %>%
    read_html() %>%
    html_text()
  
  # 개별종목 지표 데이터 다운로드
  down_url = 'http://data.krx.co.kr/comm/fileDn/download_csv/download.cmd'
  down_ind = POST(down_url, query = list(code = otp)) %>%
    read_html(.,encoding='cp949') %>%
    html_text() %>%
    read_csv()
}

KRXDataMerge<-function(businessDay){
  down_sector_KOSPI<-KRXIndStat(businessDay,'STK')
  down_sector_KOSDAQ<-KRXIndStat(businessDay,'KSQ')
  down_sector<-rbind(down_sector_KOSPI,down_sector_KOSDAQ)
  
  down_monitoring<-KRXMonitoringStat()
  down_monitoring$관리종목<-str_replace_all(down_monitoring$관리종목,'O','관리종목')
  down_monitoring$관리종목<-str_replace_all(down_monitoring$관리종목,'X','-')
  down_monitoring<-down_monitoring[,c(1,2,5)]
  
  down_ind<-KRXIndividualStat(businessDay)
  #데이터 정리(개별종목, 산업현황 데이터 병합)
  setdiff(down_sector[,'종목명'],down_ind[,'종목명']) #겹치지 않은 종목 ->제외(일반적이지 않은 종목들)
  
  KOR_ticker = merge(down_sector, down_ind,
                     by = intersect(names(down_sector),names(down_ind)),
                     all = FALSE
  )
  KOR_ticker<-merge(KOR_ticker,down_monitoring,by=c("종목코드","종목명"),all=FALSE)
  setDT(KOR_ticker)
  setorder(KOR_ticker,'시가총액') #시가총액으로 정렬
  
  KOR_ticker <- KOR_ticker[!grepl('스팩', KOR_ticker$'종목명'),] 
  KOR_ticker <- KOR_ticker[str_sub(KOR_ticker$'종목코드', -1, -1) == 0,] #우선주
  KOR_ticker$일자<-as.Date(businessDay,format='%Y%m%d')
  KOR_ticker<-subset(KOR_ticker,select = c('일자','종목코드','종목명','시장구분','업종명','종가','시가총액',
                                           '주당배당금','배당수익률','관리종목'))
  names(KOR_ticker)<-c('일자','종목코드','종목명','시장구분','산업분류','현재가(종가)','시가총액',
                       '주당배당금','배당수익률','관리여부')
  return(KOR_ticker)
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
        ,code,'&timeframe=',interval,'&count=',cnt+1,'&requestType=0')
      
      # 이 후 과정은 위와 동일함
      # 데이터 다운로드
      data = GET(url)
      data_html = read_html(data, encoding = 'EUC-KR') %>%
        html_nodes("item") %>%
        html_attr("data") 
      
      # 데이터 나누기
      price = read_delim(I(data_html), delim = '|')
      
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

#Fnguide에서 데이터 받기
getFSHtmlFromFnGuide<-function(codeList){
  htmlData<-list()
  i<-1
  for(code in codeList){
    url = paste0(
      'https://comp.fnguide.com/SVO2/ASP/'
      ,'SVD_Finance.asp?pGB=1&gicode=A',
      code)
    # 이 후 과정은 위와 동일함
    # 데이터 다운로드 후 테이블 추출
    data = GET(url) %>%
      read_html() %>%
      html_table()
    htmlData[[code]]<-data
    print(paste0(Sys.time()," : [",i,"/",length(codeList),"] Success: ",code))
    i<-i+1
  }
  return(htmlData)
}
#Fnguide에서 받은 데이터 정리하기
cleanFSHtmlToDataFrame<-function(type,htmlData){
  data<-htmlData[[1]]
  if(length(data)==0) return(NULL)
  if(type=="Y") r=1 else r=2
  idxList<-0:2*2+r
  # 3개 재무제표를 하나로 합치기    
  data_IS<-data[[idxList[1]]]
  data_BS<-data[[idxList[2]]]
  data_CF<-data[[idxList[3]]]
  data_IS<-data_IS[, 1:(ncol(data_IS)-2)]
  
  data_IS$name<-'포괄손익계산서'
  data_BS$name<-'재무상태표'
  data_CF$name<-'현금흐름표'
  data_fs<-as.data.table(rbind(data_IS,data_BS,data_CF))
  # 데이터 클랜징
  data_fs[, 1] = gsub('계산에 참여한 계정 펼치기','',data_fs[,1][[1]])
  
  rownames(data_fs) = NULL
  ftype<-data_fs[,1][[1]]
  data_fs<-data_fs[,-1]
  
  Name<-data_fs[,length(names(data_fs)),with=FALSE][[1]]
  data_fs<-data_fs[,-length(names(data_fs)),with=FALSE]
  data_fs<-data_fs[,lapply(.SD,function(x){as.numeric(str_replace_all(x,',',''))})]
  data_fs[,c("계정","항목","code"):=list(ftype,Name,names(htmlData))]
  data_fs<-subset(data_fs,select=c(7,6,5,1,2,3,4))
  date<-names(data_fs)[4:7]
  date<-str_replace_all(date,'/','.')
  names(data_fs)[4:7]<-date
  if(type=='Q') {names(data_fs)[4:7]<-date} else{
    month<-substr(date,6,7)
    if(month[length(date)]!=month[1]) data_fs<-data_fs[,-length(names(data_fs)),with=FALSE]
  }
  data_fs<-melt.data.table(data_fs,1:3)
  names(data_fs)<-c("종목코드","종류","계정","일자","값")
  data_fs<-na.omit(data_fs)
  data_fs$값<-data_fs$값*100000000
  data_fs<-data_fs[,.(값=sum(값)),by=eval(names(data_fs)[-5])]
  data_fs<-data_fs[!duplicated(data_fs), ]
  return(data_fs)
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

cleanDataAndExtractEntitiesFromFS<-function(corpData,yearData,quarterData,isNew){
  result<-NULL
  tryCatch(
    {
      businessDate<-as.Date(corpData[[1]],format='%Y-%m-%d')
      code<-corpData[[2]]
      yData<-yearData[종목코드==code]
      qData<-quarterData[종목코드==code]
      
      lastYearDate<-businessDate %m+% months(-12)
      
      yData<-yData[등록일자>=lastYearDate]
      qData<-qData[등록일자>=lastYearDate]
      
      if(!isNew){
        yData<-yData[등록일자<=businessDate]
        qData<-qData[등록일자<=businessDate]
      }
      
      yDate<-as.character(yData$일자)
      qDate<-as.character(qData$일자)
      
      qRank<-frank(-as.double(qDate),ties.method="dense")
      yRank<-frank(-as.double(yDate),ties.method="dense")
      
      if(length(yRank) == 0 & length(unique(qRank)) < 4 ){return(result)}
      
      curQRange<-diff(range(as.double(qDate)[qRank<5]))
      
      if(length(unique(qDate))>=4 & curQRange<=1){
        data<-qData[qRank<=4]
      } else{ data<-yData[yRank==1] }
      data$일자<-as.character(data$일자)
      result <- extractFSEntities(corpData, data)
    },
    error=function(e) print(paste0("Fail to Read: ",code," Date:",businessDate))
  )
  return(result)
}

sumQuarterData<-function(data){
  fs<-data[data$종류=='재무상태표']
  data<-data[data$종류!='재무상태표']
  fs<-fs[fs$일자==max(fs$일자)]
  fs<-fs[,-c('일자','등록일자')]
  if(length(unique(data$일자))>1) data<-data[,.(값=sum(값)),by=c('종목코드','종류','계정')] else{
    data<-data[,-c('일자','등록일자')]
  }
  names(fs)<-names(data)
  data<-rbind(data,fs)
  return(data)
}

extractFSEntities<-function(corpData,data){
  marketPrice<-corpData$시가총액
  code<-corpData$종목코드
  data<-data[data$종목코드==code]
  data<-unique(data,by=c("종목코드","종류","계정","일자"),fromLast=T)
  
  if(length(unique(data$일자))==4){
    data<-sumQuarterData(data)
  }

#  data[,일자:=corpData[[1]]]
#  data<-subset(data,select=c(5,1,2,3,4))
  ocf<-data[계정=="영업활동으로인한현금흐름"]$값
  if(length(ocf)>0){
    capex<-data[계정 %in% c("유형자산의증가","무형자산의증가")][,sum(값)]-data[계정 %in% c("유형자산의감소","무형자산의감소")][,sum(값)]
    if(!is.na(capex)) fcf<-ocf-capex
  } else fcf<-0
  
  
  value_type <- c('지배주주순이익','자본','자본금','영업활동으로인한현금흐름',
                  '재무활동으로인한현금흐름','투자활동으로인한현금흐름','매출액','매출총이익','영업이익',
                  '유동자산','부채','유상증자','자산','유동부채','당기순이익')
  
  tmp<-data[data[,계정 %in% value_type]]$값
  names(tmp)<-data[data[,계정 %in% value_type]]$계정
  
  corpData[,':='(자산=tmp['자산'],유동자산=tmp['유동자산'],부채=tmp['부채'],유동부채=tmp['유동부채'],
                   자본=tmp['자본'],자본금=tmp['자본금'],매출액=tmp['매출액'],매출총이익=tmp['매출총이익'],
                   영업이익=tmp['영업이익'],지배주주순이익=tmp['지배주주순이익'],당기순이익=tmp['당기순이익'],
                   영업활동으로인한현금흐름=tmp['영업활동으로인한현금흐름'],
                   재무활동으로인한현금흐름=tmp['재무활동으로인한현금흐름'],
                   투자활동으로인한현금흐름=tmp['투자활동으로인한현금흐름'],
                   잉여현금흐름=fcf,
                   유상증자=tmp['유상증자'])]
  
  return(corpData)
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

