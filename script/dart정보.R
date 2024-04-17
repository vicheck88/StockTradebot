dart_api <- '0b70879ad253ac720b75b0629a25e613b92614ee'

library(jsonlite)
library(RPostgres)
library(DBI)

#공시정보 불러오기
#- 당일 접수 10건
#http://dart.fss.or.kr/api/search.json?auth=xxx
#- 당일 접수 100건
#http://dart.fss.or.kr/api/search.json?auth=xxx&page_set=100
#- 회사의 당일 접수 10건
#http://dart.fss.or.kr/api/search.json?auth=xxx&crp_cd=xxx
#- 회사의 당일 접수 최종보고서만 10건
#http://dart.fss.or.kr/api/search.json?auth=xxx&crp_cd=xxx&fin_rpt=Y
#- 회사의 전체(19990101~당일) 공시 10건
#http://dart.fss.or.kr/api/search.json?auth=xxx&crp_cd=xxx&start_dt=19990101
#- 회사의 전체 정기공시 10건
#http://dart.fss.or.kr/api/search.json?auth=xxx&crp_cd=xxx&start_dt=19990101&dsp_tp=A
#- 회사의 전체 사업+반기+분기보고서 10건


#DB 접속
conn<-dbConnect(RPostgres::Postgres(),dbname='stocks',host='203.243.21.33',port='5432',user='postgres',password='rlghlsms1qjs!@')
codeList<-dbGetQuery(conn,"select distinct 종목코드 from metainfo.기업정보")
recordedCorpList<-dbGetQuery(conn,"select index, 종목코드 from metainfo.재무상태표 group by index, 종목코드")
year<-2015:2019
quarter<-1:4
yearList<-c()
for(y in year){
  for(q in quarter){
    tmp<-year*10+q
    
  }
}


#연도별 rcp_no 리스트 구하기(api 개수 체크 필요)
year_seq<-seq(2015,2021,by=2)
day<-'0101'
rcpList<-NULL
api_count<-0
for(year in year_seq){
  from<-paste0(year,day)
  end<-paste0(year+2,day)
  for(code in codeList[,1]){
    url = paste0('http://dart.fss.or.kr/api/search.json?auth=',dart_api,
                 '&crp_cd=',code,'&start_dt=',from,'&end_dt=',end,'&bsn_tp=A001&bsn_tp=A002&bsn_tp=A003')
    dart_discl = fromJSON(url)
    if(nrow(dart_discl$list)>0) rcpList<-rbind(rcpList,dart_discl$list)
    api_count<-api_count+1
    if(api_count==10000) Sys.sleep(60*60*24)
  }
}

rcp_no<-rcpList$rcp_no
discl_url<-paste0('http://dart.fss.or.kr/dsaf001/main.do?rcpNo=', rcp_no)
code<-rcpList$crp_cd
quarter<-rcpList$rpt_nm
quarter<-str_extract_all(quarter,'[[:digit:]]',simplify=TRUE)
quarter<-as.double(apply(quarter,1,function(x) paste0(x,collapse="")))


report_data<-lapply(discl_url,function(x) html_node(read_html(x),xpath='//*[@id="north"]/div[2]/ul/li[1]/a'))
dcm_no<-unlist(lapply(report_data,function(x) tail(unlist(str_match_all(html_attr(x,'onclick'),'[0-9]+')),1)))

#rcp_no,dcm_no 정보 획득
noList<-cbind(rcp_no,dcm_no,code)
#엑셀 파일로 받기
excel_data<-apply(noList,1,function(x){
  list(POST('http://dart.fss.or.kr/pdf/download/excel.do',
       query = list(
         rcp_no = x[1],
         dcm_no = x[2],
         lang = 'ko'
       )),x[1],x[2],code)
})

#엑셀파일 저장
library(readxl)
lapply(excel_data, function(x){
  writeBin(content(x[[1]],'raw'),paste0(x[[4]],"_",x[[2]],"_",x[[3]],'.xls'))
})

fileList<-sapply(excel_data,function(x) paste0(x[[4]],"_",x[[2]],"_",x[[3]],'.xls'))


for(file in fileList){
  sheets<-excel_sheets(path=file)
  
  sheet<-read_excel()
  sheetName<-names(sheet)[1]
  financialData<-as.data.frame(sheet)
}


a<-read_excel(fileList[1],sheet=5)

print(excel_data)
writeBin(content(excel_data, 'raw'), '003310_20181114000837.xls')
a<-read_excel('005930_20190401004781.xls',sheet=2)

balanceSheet<-NULL
IncomeStatement<-NULL
CashFlow<-NULL

#sheet 이름 검색
excel_sheets()
sheetNum<-2:7
sheet<-read_excel()
sheetName<-names(sheet)[1]

excelFrame<-as.data.frame(sheet)
colList<-excelFrame[,1]
valList<-excelFrame[,2]
# 단위화폐 구하기
startCurrencyRow<-which(grepl('단위',colList))
currencyUnit<-colList[startCurrencyRow]
currencyUnit<-str_remove_all(currencyUnit,'[()]')
currencyUnit<-str_remove_all(currencyUnit,'단위 : ')
currencyUnit<-str_remove_all(currencyUnit,'원')

currencyUnitInt<- ifelse(grepl("억",currencyUnit), 100000000,
                   ifelse(grepl("백만",currencyUnit), 1000000,
                    ifelse(grepl("천",currencyUnit), 1000)))
#시작 row 구하기
startRow<-which(grepl('제',valList))
endRow<-length(colList)
colNum<-2
data<-excelFrame[startRow:endRow,1:colNum]
tmpdata<-data[3:nrow(data),]
rownames(tmpdata)<-tmpdata[,1]
tmpdata<-subset(tmpdata,select=-1)
data<-tmpdata
data[,1]<-as.double(data[,1])*currencyUnitInt
colnames(data)<-"Value"


