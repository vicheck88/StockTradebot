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

#quantmod: 주식 데이터 다운로드 API
library(quantmod)
getSymbols('EDV')
chart_Series(Ad(EDV)) #Ad: 수정주가, Chart_Series: 시계열 그래프

data = getSymbols('AAPL',
                  from = '2018-01-01', auto.assign = FALSE)
chart_Series(Ad(data))

#한국 주식: 티커.KS(코스피), 티커.KQ(코스닥)
getSymbols('005930.KS')
chart_Series(Cl(`005930.KS`))

#FRED자료 얻기->티커: FRED 사이트에서 표시가능
#미 국채 10년
getSymbols('DGS10',src='FRED')
chart_Series(DGS10)
#원/달러 환율
getSymbols('DEXKOUS',src='FRED')
chart_Series(DEXKOUS)


#한국산업거래소 데이터 크롤링
library(httr)
library(rvest)
library(stringr)
library(readr)

# 최근 영업일 구하기
url = 'https://finance.naver.com/sise/sise_deposit.nhn'

biz_day = GET(url) %>%
  read_html(encoding = 'EUC-KR') %>%
  html_nodes(xpath =
               '//*[@id="type_1"]/div/ul[2]/li/span') %>%
  html_text() %>%
  str_match(('[0-9]+.[0-9]+.[0-9]+') ) %>%
  str_replace_all('\\.', '')

# 산업별 현황 OTP 발급
gen_otp_url =
  'http://marketdata.krx.co.kr/contents/COM/GenerateOTP.jspx'
gen_otp_data = list(
  name = 'fileDown',
  filetype = 'csv',
  url = 'MKD/03/0303/03030103/mkd03030103',
  tp_cd = 'ALL',
  date = biz_day, # 최근영업일로 변경
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

# 개별종목 지표 OTP 발급
gen_otp_url =
  'http://marketdata.krx.co.kr/contents/COM/GenerateOTP.jspx'
gen_otp_data = list(
  name = 'fileDown',
  filetype = 'csv',
  url = "MKD/13/1302/13020401/mkd13020401",
  market_gubun = 'ALL',
  gubun = '1',
  schdate = biz_day, # 최근영업일로 변경
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

#스팩, 우선주 제거
library(stringr)
KOR_ticker <- KOR_ticker[!grepl('스팩', KOR_ticker$'종목명'),] 
KOR_ticker <- KOR_ticker[str_sub(KOR_ticker$'종목코드', -1, -1) == 0,] #우선주

#와이즈인덱스 WICS 섹터 정보 크롤링
library()
url = paste0('http://www.wiseindex.com/Index/GetIndexComponets?ceil_yn=0&dt=',biz_day,'&sec_cd=G10')
data = fromJSON(url)


#각 섹터별로 정보 얻기
# 10: 에너지, 15: 소재, 20: 산업재, 25: 경기관련소비재, 30: 필수소비재, 35: 건강관리
# 40: 금융, 45: IT, 50: 커뮤니케이션서비스, 55: 유틸리티
sector_code = c('G25', 'G35', 'G50', 'G40', 'G10',
                'G20', 'G55', 'G30', 'G15', 'G45')
data_sector = list()

for (i in sector_code) {
  url = paste0(
    'http://www.wiseindex.com/Index/GetIndexComponets',
    '?ceil_yn=0&dt=',biz_day,'&sec_cd=',i)
  data = fromJSON(url)
  data = data$list
  
  data_sector[[i]] = data
  
  Sys.sleep(1)
}
data_sector = do.call(rbind, data_sector)

#수정주가정보(네이버)
#전 종목 주가 크롤링
library(httr)
library(rvest)
library(stringr)
library(xts)
library(lubridate)
library(readr)

KOR_ticker$'종목코드'<-str_pad(KOR_ticker$'종목코드',6,side=c('left'),pad='0') #종목코드 변경

for(i in 1 : nrow(KOR_ticker) ) {
  
  price = xts(NA, order.by = Sys.Date()) # 빈 시계열 데이터 생성
  name = KOR_ticker$'종목코드'[i] # 티커 부분 선택
  
  # 오류 발생 시 이를 무시하고 다음 루프로 진행
  tryCatch({
    # url 생성
    url = paste0(
      'https://fchart.stock.naver.com/sise.nhn?symbol='
      ,name,'&timeframe=day&count=500&requestType=0')
    
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
    colnames(price) = c('Date', 'Price')
    price[, 1] = ymd(price[, 1])
    
    rownames(price) = price[, 1]
    price[, 1] = NULL
    
  }, error = function(e) {
    
    # 오류 발생시 해당 종목명을 출력하고 다음 루프로 이동
    warning(paste0("Error in Ticker: ", name))
  })
  # 타임슬립 적용
  Sys.sleep(2)
}

#재무제표 크롤링(fnGuide)
library(httr)
library(rvest)

Sys.setlocale("LC_ALL", "English")

url = paste0('http://comp.fnguide.com/SVO2/ASP/SVD_Finance.asp?pGB=1&gicode=A005930')

#데이터 크롤링
#총 6개의 리스트로 구성: 1. 포괄손익계산서(연), 2.포괄손익계산서(분기), 3. 재무상태표(연)
#4. 재무상태표(분기), 5. 현금흐름표(연), 6. 현금흐름표(분기)
data = GET(url)
data = data %>%
  read_html() %>%
  html_table()

Sys.setlocale("LC_ALL", "Korean")
lapply(data, function(x) {
  head(x, 3)})

data_IS = data[[1]]
data_BS = data[[3]]
data_CF = data[[5]]

print(names(data_IS))
data_IS = data_IS[, 1:(ncol(data_IS)-2)]

data_fs = rbind(data_IS, data_BS, data_CF)
data_fs[, 1] = gsub('계산에 참여한 계정 펼치기',
                    '', data_fs[, 1])
data_fs = data_fs[!duplicated(data_fs[, 1]), ]

rownames(data_fs) = NULL
rownames(data_fs) = data_fs[, 1]
data_fs[, 1] = NULL


data_fs = data_fs[, substr(colnames(data_fs), 6,7) == '12']

sapply(data_fs,typeof)

library(stringr)

data_fs = sapply(data_fs, function(x) {
  str_replace_all(x, ',', '') %>%
    as.numeric()
}) %>%
  data.frame(., row.names = rownames(data_fs))

#가치지표 구하기(PER, PBR, PSR, PCR)
#분모 구하기
value_type<-c('지배주주순이익',
              '자본',
              '영업활동으로인한현금흐름',
              '매출액')
value_index<-data_fs[match(value_type,rownames(data_fs)),ncol(data_fs)]

#분자 구하기
