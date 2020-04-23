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