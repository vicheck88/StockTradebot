import psycopg2
from sqlalchemy import create_engine
import pandas as pd
import OpenDartReader
from OpenDartReader import dart_finstate
import time
import io
import json

with open("config.json","r") as configjson:
    config=json.load(configjson)

dart_api=config["dart_api"]
dart=OpenDartReader(dart_api)
dbConfig=config['database']

conn=psycopg2.connect(host=dbConfig['host'],port=dbConfig['port'],
                      database=dbConfig['database'],
                      user=dbConfig['user'],password=dbConfig['password'])
#전체 기업목록
sql="select distinct 종목코드, 종목명 from metainfo.기업정보"
corpList=list(pd.read_sql_query(sql,conn)["종목코드"])

recordedCorpExists=True
cur=conn.cursor()
cur.execute("select * from information_schema.tables\
            where table_schema='metainfo' and table_name='재무상태표'")
recordedCorpExists=bool(cur.rowcount)
    
#현재 기록되어 있는 기업 목록
if recordedCorpExists==True:
    sql="select index,종목코드 from metainfo.재무상태표"
    recordedDataFrame=pd.read_sql_query(sql,conn)
    recordedCorpList=list(recordedDataFrame['종목코드'])
#새로 추가할 기업 목록
newCorpList=list(set(corpList)-set(recordedCorpList)) if recordedCorpExists==True else corpList
conn.close()
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

BS=pd.DataFrame(columns=['index','일자','종목코드','재무제표구분','계정명','금액'])
IS=pd.DataFrame(columns=['index','일자','종목코드','재무제표구분','계정명','금액'])
CF=pd.DataFrame(columns=['index','일자','종목코드','재무제표구분','계정명','금액'])

now=time.localtime()
year=now.tm_year
mon=now.tm_mon
quarter=int(mon/4)

yearRange=range(2015,year)
quarterList=['11013', '11012', '11014', '11011']

allRange=[y*10+c for y in yearRange for c in [1,2,3,4]]

callcount=0
f=open('failCorpYear.txt',mode='wt',encoding='utf-8')
#1사분기
for corp in corpList:
    if callcount>8900: break
    if corp in newCorpList: corpRange=allRange
    else:
        recordedSet=set(recordedDataFrame[recordedDataFrame['종목코드']==corp]['index'])
        corpRange=list(set(allRange)-recordedSet)
    for code in corpRange:
        year=int(code/10)
        q=quarterList[int(code%10)-1]

        frame=dart.finstate_all(corp,year,q)
        callcount=callcount+1
        if frame is None: 
            frame=dart_finstate.finstate_all(dart_api, dart.find_corp_code(corp), year, q, 'OFS')
            callcount=callcount+1
        if frame is None:
            f.writelines(str(year)+','+corp+'\n')
            continue;
        frame['index']=code
        frame['stock_code']=corp
        frame=frame[['index','rcept_no','stock_code','sj_div','account_nm',
                        'thstrm_amount','thstrm_add_amount']]
        frame=frame.rename(columns={'rcept_no':'일자','stock_code':'종목코드','sj_div':'재무제표구분',
                                    'account_nm':'계정명','thstrm_amount':'금액',
                                    'thstrm_add_amount':'누적금액'})
        frame['금액'] = pd.to_numeric(frame['금액'],errors='coerce')
        frame['누적금액'] = pd.to_numeric(frame['누적금액'],errors='coerce')
        frame['일자']=frame['일자'].str.slice(stop=6)
        
        BSCFframe=frame.drop(columns='누적금액')
        BS=pd.concat([BS,BSCFframe[BSCFframe['재무제표구분']=='BS']])
        CF=pd.concat([CF,BSCFframe[BSCFframe['재무제표구분']=='CF']])

        istmp=pd.concat([frame[frame['재무제표구분']=='IS'],frame[frame['재무제표구분']=='CIS']])
        istmp['재무제표구분']='IS'
        if q!='11011' :
            istmp=istmp.drop(columns='금액').drop_duplicates()
            istmp=istmp.rename(columns={'누적금액':'금액'})
        else:
            istmp=istmp.drop(columns='누적금액').drop_duplicates()

        IS=pd.concat([IS,istmp])    
        print("Finish: " + str(year) +" , " + corp)

f.close()

connstring='postgresql+psycopg2://%s:%s@%s/%s' % (dbConfig['user'],dbConfig['password'],dbConfig['host'],dbConfig['database'])
engine=create_engine(connstring)

BS.to_sql('재무상태표',schema='metainfo',con=engine,if_exists='append',index=False)
IS.to_sql('손익계산서',schema='metainfo',con=engine,if_exists='append',index=False)
CF.to_sql('현금흐름표',schema='metainfo',con=engine,if_exists='append',index=False)

