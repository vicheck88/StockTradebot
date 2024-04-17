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
