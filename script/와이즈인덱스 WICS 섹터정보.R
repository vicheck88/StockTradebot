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
