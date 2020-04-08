import psycopg2
import pandas as pd
import OpenDartReader

dart_api='0b70879ad253ac720b75b0629a25e613b92614ee'
dart=OpenDartReader(dart_api)

conn=psycopg2.connect(host="203.243.21.33",port=5432,database="stocks",user="postgres",password="12dnjftod")
sql="select distinct 종목코드, 종목명 from metainfo.기업정보"
corpList=list(pd.read_sql_query(sql,conn)["종목코드"])
'''
rcept_no: 접수번호
corp_code: 사업 연도
stock_code: 종목 코드
reprt_code: 보고서 코드 -> 11013: 1분기, 11012: 2분기, 11014: 3분기 11011: 4분기
account_nm: 계정명 (예: 자본총계)
fs_div: 개별/연결구분 ('CFS'=연결재무제표, 'OFS'=재무제표)
fs_nm: 개별/연결명 ('연결재무제표' 또는 '재무제표')
sj_div: 재무제표구분 ('BS'=재무상태표, 'IS'=손익계산서, 'CIS'=포괄손익계산서, 'CF'=현금흐름표, 'SCE'=자본변동표)
sj_nm: 재무제표명 ( '재무상태표' 또는 '손익계산서')
thstrm_nm: 당기명
thstrm_dt: 당기일자
thstrm_amount: 당기금액
thstrm_add_amount: 당기누적금액
frmtrm_nm: 전기명
frmtrm_dt: 전기일자
frmtrm_amount: 전기금액
frmtrm_add_amount: 전기누적금액
bfefrmtrm_nm: 전전기명
bfefrmtrm_dt: 전전일자
bfefrmtrm_amount: 전전기금액
ord: 계정과목 정렬순서
'''

corp=corpList[1]