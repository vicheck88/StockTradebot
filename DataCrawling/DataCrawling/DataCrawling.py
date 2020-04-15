import psycopg2
import pandas as pd
import OpenDartReader
import time

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

BS=pd.DataFrame(columns=['index','종목코드','재무제표구분','계정명','금액'])
IS=pd.DataFrame(columns=['index','종목코드','재무제표구분','계정명','금액'])
CF=pd.DataFrame(columns=['index','종목코드','재무제표구분','계정명','금액'])

yearRange=range(2015,2020)
quarterlist=['11013', '11012', '11014', '11011']
callcount=0
f=open('failCorpYear.txt',mode='wt',encoding='utf-8')
#1사분기
for corp in corpList:
    for year in yearRange:
        prevCF=[]
        for i, q in enumerate(quarterlist):
            code=year*10+i+1
            frame=dart.finstate_all(corp,year,q)
            if callcount==10000 : 
                time.sleep(60*60*24)
                callcount=0
            if frame==None:
                f.writelines('Fail to Read: ' + corp + ', ' + str(code) + '\n')
            callcount=callcount+1
            frame['index']=code
            frame['stock_code']=corp
            frame=frame[['index','stock_code','sj_div','account_nm','thstrm_amount']]
            frame=frame.rename(columns={'stock_code':'종목코드','sj_div':'재무제표구분','account_nm':'계정명','thstrm_amount':'금액'})
            frame['금액'] = pd.to_numeric(frame['금액'])
            BS=pd.concat([BS,frame[frame['재무제표구분']=='BS']])
            istmp=pd.concat([frame[frame['재무제표구분']=='IS'],frame[frame['재무제표구분']=='CIS']])
            istmp['재무제표구분']='IS'
            istmp=istmp.drop_duplicates()
            IS=pd.concat([IS,istmp])
            CFtmp=frame[frame['재무제표구분']=='CF']
            if i==0: CF=pd.concat([CF,CFtmp])
            if len(prevCF)==0: prevCF = CFtmp
            else:
                CFtmp=CFtmp[['계정명','금액']]
                newCFtmp=prevCF.merge(CFtmp,on='계정명')
                newCFtmp['금액_x']=newCFtmp['금액_y']-newCFtmp['금액_x']
                prevCF=newCFtmp.drop(columns='금액_x')
                prevCF=prevCF.rename(columns={'금액_y':'금액'})
                newCFtmp=newCFtmp.drop(columns='금액_y')
                newCFtmp=newCFtmp.rename(columns={'금액_x':'금액'})
                CF=pd.concat([CF,newCFtmp])

f.close()
BS.to_sql('재무상태표',schema='meatinfo',con=conn,if_exists='replace',index=False)
IS.to_sql('손익계산서',schema='meatinfo',con=conn,if_exists='replace',index=False)
CF.to_sql('현금흐름표',schema='meatinfo',con=conn,if_exists='replace',index=False)