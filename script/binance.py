#!/usr/bin/env python
# coding: utf-8

# In[1]:


import requests as rq
import hmac
import hashlib
import json
from datetime import datetime,timezone,timedelta
import time
import math
import traceback


# In[2]:


with open('/Users/chhan/config.json','r') as f: config=json.load(f)
telegramApi=config['telegram']
config=config['binance_key']
accessKey=config['access_key']
secretKey=config['secret_key']
futureURL = 'https://fapi.binance.com'
spotURL='https://api.binance.com'
headers = {
    'X-MBX-APIKEY': accessKey
}


# In[3]:


def sendMessage(message,count=0):
  url=f"https://api.telegram.org/bot{telegramApi['token']}/sendMessage?chat_id={telegramApi['chatId']}&text={message}"
  try:
    res=rq.post(url)
    print(f'sendMessage: {res.status_code}')
  except Exception as e:
    print(f'error: {e}')
    print(f'send again: count {count}')
    time.sleep(2)
    if count<10: sendMessage(message,count+1)


# In[4]:


def request(url,method):
  if method=='get': return rq.get(url,headers=headers)
  elif method=='post': return rq.post(url,headers=headers)
  elif method=='delete': return rq.delete(url,headers=headers)
def createSignature(message):
  return hmac.new(key=secretKey.encode('utf-8'), msg=message.encode('utf-8'),digestmod=hashlib.sha256).hexdigest()
def requestData(mainUrl,subUrl,method,message,addSignature=True):
  url = f'{mainUrl}{subUrl}?{message}'
  if addSignature: url+=f'&signature={createSignature(message)}'
  return request(url,method).json()


# In[5]:


def getCurrentTime():
  subUrl='/api/v3/time'
  return request(spotURL+subUrl,'get').json()['serverTime']
def getCoinPriceHistory(symbol,unit,count):
  msg=f'symbol={symbol}&interval={unit}&limit={count}'
  return requestData(spotURL,'/api/v3/klines','get',msg,addSignature=False)
def getCurrentPrice(symbol=None):
  msg='' if symbol==None else f'symbol={symbol}'
  return requestData(spotURL,'/api/v3/ticker/price','get',msg,addSignature=False)
def getCoinFutureMarkPriceHistory(symbol,unit,count):
  msg=f'symbol={symbol}&interval={unit}&limit={count}'
  return requestData(futureURL,'/fapi/v1/markPriceKlines','get',msg,addSignature=False)
def getCurrentFutureMarkPrice(symbol=None):
  msg='' if symbol==None else f'symbol={symbol}'
  return requestData(futureURL,'/fapi/v1/premiumIndex','get',msg,addSignature=False)
def getAccount():
  return requestData(spotURL,'/api/v3/account','get',f'omitZeroBalances=true&timestamp={getCurrentTime()}')
def getCurrentAssetBalance():
  return requestData(spotURL,'/sapi/v3/asset/getUserAsset','post',f'timestamp={getCurrentTime()}')
def getFutureAccount():
  return requestData(futureURL,'/fapi/v2/account','get',f'timestamp={getCurrentTime()}')
def getFutureBalance():
  return requestData(futureURL,'/fapi/v2/balance','get',f'timestamp={getCurrentTime()}')

def transfer(transferFrom:str,transferTo:str,asset,amount):
  t=f'{transferFrom.upper()}_{transferTo.upper()}'
  msg=f'asset={asset}&amount={amount}&type={t}&timestamp={getCurrentTime()}'
  return requestData(spotURL,'/sapi/v1/asset/transfer','post',msg)

def getFlexibleSimpleEarnList():
  return requestData(spotURL,'/sapi/v1/simple-earn/flexible/list','get',f'timestamp={getCurrentTime()}')
def getSimpleEarnAccount():
  return requestData(spotURL,'/sapi/v1/simple-earn/account','get',f'timestamp={getCurrentTime()}')
def getSimpleEarnPosition():
  return requestData(spotURL,'/sapi/v1/simple-earn/flexible/position','get',f'timestamp={getCurrentTime()}')
def subscribeFlexibleSimpleEarnProduct(prodId,amount):
  return requestData(spotURL,'/sapi/v1/simple-earn/flexible/subscribe','post',f'productId={prodId}&amount={amount}&timestamp={getCurrentTime()}')
def redeemFlexibleSimpleEarnProduct(prodId,amount=0,destAccount='SPOT'):
  msg=f'productId={prodId}&destAccount={destAccount}&timestamp={getCurrentTime()}'
  if amount>0: msg+=f'&amount={amount}'
  else: msg+='&redeemAll=true'
  return requestData(spotURL,'/sapi/v1/simple-earn/flexible/redeem','post',msg)
def getAccountSnapshot(accType):
  return requestData(spotURL,'/sapi/v1/accountSnapshot','get',f'type={accType}&timestamp={getCurrentTime()}')
def changeFutureLeverage(symbol,lev):
  return requestData(futureURL,'/fapi/v1/leverage','post',f'symbol={symbol}&leverage={lev}&timestamp={getCurrentTime()}')
def orderFutureWithTimeLimit(symbol,side,quantity,price,timeLimit):
  limitDate=datetime.now()+timedelta(timeLimit)
  return requestData(futureURL,'/fapi/v1/order','post',f'symbol={symbol}&side={side}&type=LIMIT&quantity={quantity}&price={price}&timeInForce=GTD&goodTillDate={int(limitDate.timestamp()*1000)}&timestamp={getCurrentTime()}')
def orderFutureMarketType(symbol,side,quantity):
  return requestData(futureURL,'/fapi/v1/order','post',f'symbol={symbol}&side={side}&type=MARKET&quantity={quantity}&timestamp={getCurrentTime()}')
def setStopMarketPrice(symbol,side,stopPrice,quantity,workingType):
  return requestData(futureURL,'/fapi/v1/order','post',f'symbol={symbol}&side={side}&type=STOP_MARKET&stopPrice={stopPrice}&quantity={quantity}&reduceOnly=false&workingType={workingType}&timestamp={getCurrentTime()}')
def setPositionClosePrice(symbol,side,stopPrice,workingType):
  return requestData(futureURL,'/fapi/v1/order','post',f'symbol={symbol}&side={side}&type=STOP_MARKET&stopPrice={stopPrice}&closePosition=true&workingType={workingType}&timestamp={getCurrentTime()}')
def setStopLimitPrice(symbol,side,stopPrice,quantity,workingType,priceMatch):
  return requestData(futureURL,'/fapi/v1/order','post',f'symbol={symbol}&side={side}&type=STOP&stopPrice={stopPrice}&quantity={quantity}&reduceOnly=false&workingType={workingType}&priceMatch={priceMatch}&timestamp={getCurrentTime()}')
def getCurrentPosition():
  return requestData(futureURL,'/fapi/v3/positionRisk','get',f'timestamp={getCurrentTime()}')
def getAllOpenOrders():
  return requestData(futureURL,'/fapi/v1/openOrders','get',f'timestamp={getCurrentTime()}')
def closeAllOpenOrders():
  openOrderSymbolList=set([v['symbol'] for v in getAllOpenOrders()])
  for symbol in openOrderSymbolList:
    requestData(futureURL,'/fapi/v1/allOpenOrders','delete',f'symbol={symbol}&timestamp={getCurrentTime()}')


# In[6]:


def getCoinMovingAvg(symbol,unit,count):
  history=getCoinPriceHistory(symbol,unit,count)
  closePriceHistory=[float(d[4]) for d in history]
  return sum(closePriceHistory)/len(closePriceHistory)
def getCoinFutureMarkMovingAvg(symbol,unit,count):
  history=getCoinFutureMarkPriceHistory(symbol,unit,count)
  closePriceHistory=[float(d[4]) for d in history]
  return sum(closePriceHistory)/len(closePriceHistory)
def getCurrentDisparity(symbol,unit,count):
  curPrice=float(getCurrentPrice(symbol)['price'])
  avgPrice=getCoinMovingAvg(symbol,unit,count)
  return curPrice/avgPrice*100
def getCurrentFutureMarkDisparity(symbol,unit,count):
  curPrice=float(getCurrentFutureMarkPrice(symbol)['markPrice'])
  avgPrice=getCoinFutureMarkMovingAvg(symbol,unit,count)
  return curPrice/avgPrice*100
def getTotalBalance(*symbols):
  balanceDict={}
  spotAccount=getAccount()
  futureAccount=getFutureAccount()
  spotBalance=[d for d in spotAccount['balances'] if d['asset'] in symbols]
  futureBalance=[d for d in futureAccount['assets'] if d['asset'] in symbols]
  totalSpotBalance=0
  totalFutureBalance=0
  for asset in spotBalance:
    price=float(getCurrentPrice(f'{asset["asset"]}USDT')['price']) if asset['asset']!='USDT' else 1
    totalSpotBalance+=price*float(asset['free'])
  for asset in futureBalance:
    price=float(getCurrentPrice(f'{asset["asset"]}USDT')['price']) if asset['asset']!='USDT' else 1
    totalFutureBalance+=price*float(asset['walletBalance'])
  balanceDict['spot']=totalSpotBalance
  balanceDict['future']=totalFutureBalance
  balanceDict['total']=totalSpotBalance+totalFutureBalance
  return balanceDict

def getCurrentInvestInfo(coinSymbols,cashSymbols):
  coinBalance=getTotalBalance(*coinSymbols)
  cashBalance=getTotalBalance(*cashSymbols)
  earnBalance=float(getSimpleEarnAccount()['totalAmountInUSDT'])
  totalBalance=coinBalance['total']+cashBalance['total']+earnBalance
  totalSpot=coinBalance['spot']+cashBalance['spot']
  totalFuture=coinBalance['future']+cashBalance['future']
  investRatio=coinBalance['total']/totalBalance
  return {'spot':totalSpot,'future':totalFuture,'earn':earnBalance,'total':totalBalance,'investRatio':investRatio}

def convertAccountUnit(asset,investInfo):
  ratio=float(getCurrentPrice(f'{asset}USDT')['price'])
  for asset in investInfo: investInfo[asset]*=ratio
  return investInfo
  
def determineInvestInfo(disparity,currentInvestInfo,maxLeverage):
  d=disparity-100
  ratio=math.floor(d)/2
  #ratio=math.floor((d+1)/2)/maxLeverage
  newRatio=min(ratio,1) if d>0 else 0
  ret={}
  ret['investRatio']=newRatio
  ret['total']=currentInvestInfo['total']
  ret['future']=ret['total']*newRatio
  ret['earn']=ret['total']-ret['future']
  ret['spot']=0
  return ret
def getAccountChange(coinsymbols,cashsymbols,disparity,maxLeverage):
  investInfo=convertAccountUnit(cashsymbols[0],getCurrentInvestInfo(coinsymbols,cashsymbols))
  goalInvestInfo=determineInvestInfo(disparity,investInfo,maxLeverage)
  accountChangeInfo=goalInvestInfo
  accountChangeInfo['spot']-=investInfo['spot']
  accountChangeInfo['future']-=investInfo['future']
  accountChangeInfo['earn']-=investInfo['earn']
  return accountChangeInfo


# In[7]:


def getConvertPairInfo(fromAsset,toAsset):
  subUrl='/sapi/v1/convert/exchangeInfo'
  return requestData(spotURL,subUrl,'get',f'fromAsset={fromAsset}&toAsset={toAsset}',False)
def applyConversion(fromAsset,toAsset,fromAmount):
  subUrl='/sapi/v1/convert/getQuote'
  return requestData(spotURL,subUrl,'post',f'fromAsset={fromAsset}&toAsset={toAsset}&fromAmount={fromAmount}&timestamp={getCurrentTime()}')


# In[8]:


'''
스크립트 실행 로직
1. 현재 이동평균선 및 현재 계좌 자산 합 확인 후 투자 비율 계산
2-1. 만약 계산 양보다 많은 값이 선물시장에 있을 경우
 1) 이미 stop에 의해 팔린 돈을 spot으로 이동
 2) simple earn에 남는 양만큼 입금
2-2. 만약 계산 양보다 적은 값이 선물시장에 있을 경우
 1) spot에서 필요한 양만큼 redeem
 2) 여유분을 선물로 이동
 3) 여유분만큼 매수(매수는 지정가)
3-1. 현재 포지션이 있을경우
 1) 모든 open order close
 2) 현재 가격과 평균가에 맞춰 stop price 설정
3-2. 모든 포지션이 닫혀있는 경우, 스크립트 종료
'''


# In[9]:


def floorToDecimal(num,ndigits):
  return math.floor(num*(10**ndigits))/(10**ndigits)


def setCurrentTakeProfitLimitPrice(symbol,curPrice,currentPosition,averagePrice,timeLimit):
  midPrice=floorToDecimal(averagePrice*1.01,1)
  fullPrice=floorToDecimal(averagePrice*1.02,1)
  availablePosition=currentPosition
  priceList=[]
  if midPrice>curPrice:
    print(f'set takeProfit price at {midPrice}')
    print(orderFutureWithTimeLimit(symbol,'BUY',floorToDecimal(currentPosition/2,3),midPrice,timeLimit))
    availablePosition-=floorToDecimal(currentPosition/2,3)
    priceList.append(midPrice)
  if fullPrice>curPrice:
    print(f'set takeProfit price at {fullPrice}')
    print(orderFutureWithTimeLimit(symbol,'BUY',availablePosition,fullPrice,timeLimit)) 
    priceList.append(fullPrice)
  print(f"buy setting finished: price at {','.join(str(v) for v in [midPrice,fullPrice])}")

def setCurrentStopLimitPrice(symbol,curPrice,levelNum,currentPosition,averagePrice,priceMatch):
  if curPrice>averagePrice:
    print(f'set stopPrice at {averagePrice}')
    print(setStopLimitPrice(symbol,'SELL',averagePrice,floorToDecimal(currentPosition/2,3),'MARK_PRICE',priceMatch))
  print(f'set stopPrice at {math.floor(averagePrice*0.99)}: close price')
  print(setPositionClosePrice(symbol,'SELL',math.floor(averagePrice*0.99),'MARK_PRICE'))
  print(f"stopmarket setting finished: price at {','.join(str(v) for v in [averagePrice,math.floor(averagePrice*0.99)])}")
  
def setCurrentStopmarketPrice(symbol,curPrice,maxLeverage,totalPositionAmount,averagePrice):
  amountPerStop=floorToDecimal(totalPositionAmount/maxLeverage,3)
  stopPriceList=[round(averagePrice*(1+r/100),1) for r in range(maxLeverage*2-1,1,-2)]
  realStopPriceList=[]
  for price in stopPriceList:
    if(curPrice>price): 
      print(f'set stopPrice at {price}')
      print(setStopMarketPrice(symbol,'SELL',price,amountPerStop,'MARK_PRICE'))
      realStopPriceList.append(price)
  print(f'set stopPrice at {averagePrice}')
  print(setStopMarketPrice(symbol,'SELL',averagePrice,floorToDecimal(amountPerStop/2,3),'MARK_PRICE'))
  print(f'set stopPrice at {math.floor(averagePrice*0.99)}: close price')
  print(setPositionClosePrice(symbol,'SELL',math.floor(averagePrice*0.99),'MARK_PRICE'))
  print(f"stopmarket setting finished: price at {','.join(str(v) for v in realStopPriceList+[averagePrice,math.floor(averagePrice*0.99)])}")


# In[23]:


coinsymbols=['BTC']
cashsymbols=['USDC']
symbol=coinsymbols[0]+cashsymbols[0]
leverage=3
stopLimitLevelNum=2
avoidInsufficientErrorRatio=0.98
minOrderQuantityLimit=0.005

try:
  #현재 이동평균선 확인 후 투자 비율 계산
  print('start program')
  disparity=getCurrentFutureMarkDisparity(symbol,'1d',30)
  accountChangeInfo=getAccountChange(coinsymbols,cashsymbols,disparity,leverage)
  minOrderLimit=float(getCurrentPrice(symbol)['price'])*minOrderQuantityLimit
  minEarnLimit=0.1
  curPrice=floorToDecimal(float(getCurrentPrice(symbol)['price']),1)

  transferrableList=[v for v in getFutureAccount()['assets'] if float(v['availableBalance'])>0 and v['asset']!='BNB']
  for asset in transferrableList: transfer('umfuture','main',asset['asset'],float(asset['availableBalance']))

  if accountChangeInfo['earn']<0 and abs(accountChangeInfo['earn'])>minOrderLimit:
    print('redeem simple earn assets and transfer it into spot account')
    prodId=[v for v in getFlexibleSimpleEarnList()['rows'] if v['asset'] in cashsymbols][0]['productId']
    amount= 0 if accountChangeInfo['investRatio']==1 else -accountChangeInfo['earn']
    sendMessage(redeemFlexibleSimpleEarnProduct(prodId,floorToDecimal(amount,8)))

  freeBalances=[v for v in getAccount()['balances'] if v['free']!='0']
  print(f'free balances: {freeBalances}')
  updatedChangeInfo=getAccountChange(coinsymbols,cashsymbols,disparity,leverage)
  print(f'balance change: {updatedChangeInfo}')

  if updatedChangeInfo['future']>0 and updatedChangeInfo['future']>minOrderLimit:
    sendMessage("binance future BUY")
    sendMessage(f'disparity: {disparity}')
    sendMessage(updatedChangeInfo)
    
    print('transfer spot into future')
    for b in freeBalances: 
      print(f"transfer asset: {b['asset']}")
      sendMessage(transfer('main','umfuture',b['asset'],float(b['free'])))
    assetList=[v for v in getFutureAccount()['assets'] if float(v['availableBalance'])>0 and v['asset'] in cashsymbols]
    if assetList:
      asset=assetList[0]
      newPositionAmount=floorToDecimal(float(asset['availableBalance'])*leverage/curPrice*avoidInsufficientErrorRatio,3)
      averagePrice=floorToDecimal(getCoinFutureMarkMovingAvg(symbol,'1d',30),1)
      
      sendMessage(f'averagePrice: {averagePrice}')
      sendMessage(f'price: {curPrice} newPositionAmount: {newPositionAmount}')
      
      print('order new position')
      orderResponse=orderFutureWithTimeLimit(symbol,'BUY',newPositionAmount,curPrice,1000)
      sendMessage(orderResponse)
      print(f'order response: {orderResponse}')
      #transfer remaining amount to spot
      print('transfer remaining future assets into spot account')
      transfer('umfuture','main',asset['asset'],float(asset['availableBalance']))
      time.sleep(100)
      
  averagePrice=floorToDecimal(getCoinFutureMarkMovingAvg(symbol,'1d',30),1)
  positionAmountList=[v for v in getCurrentPosition() if v['symbol']==symbol and float(v['positionAmt'])>0]
  maximumPositionAmount=floorToDecimal(float(updatedChangeInfo['total'])*leverage/curPrice,3)
  if len(positionAmountList)>0:
    closeAllOpenOrders()
    print('set stopmarket order')
    for position in positionAmountList:
      # currentLeverage=updatedChangeInfo['investRatio']*leverage
      # currentPositionAmount=floorToDecimal(float(updatedChangeInfo['total'])*currentLeverage/curPrice,3)
      setCurrentStopLimitPrice(position['symbol'],curPrice,stopLimitLevelNum,float(position['positionAmt']),averagePrice,'OPPONENT')
      # setCurrentStopmarketPrice(symbol,curPrice,leverage,maximumPositionAmount,averagePrice)
  
  earnList=dict([(v['asset'],v['productId']) for v in getFlexibleSimpleEarnList()['rows']])
  futureBalances=dict([(v['asset'],float(v['availableBalance'])) for v in getFutureAccount()['assets'] if float(v['availableBalance'])>0 and v['asset'] in cashsymbols])
  currentEarnAmount=getSimpleEarnPosition()

  for asset,amt in futureBalances.items():
    if asset in earnList:    
      if amt<0.1:
        amount=amt
        earnAsset=[v for v in currentEarnAmount['rows'] if v['asset']==asset]  
        if earnAsset and float(earnAsset[0]['totalAmount'])>0.1:
          redeemFlexibleSimpleEarnProduct(earnAsset[0]['productId'],0.1)
          transfer('main','umfuture',asset,0.1)
          amount+=0.1
      sendMessage(transfer('umfuture','main',asset,amount))
      
  currentEarnAmount=getSimpleEarnPosition()
  spotBalances=dict([(v['asset'],float(v['free'])) for v in getAccount()['balances'] if float(v['free'])>0])
  for asset,amt in spotBalances.items():
    if asset not in earnList: continue
    if amt<0.1:
      amount=amt
      earnAsset=[v for v in currentEarnAmount['rows'] if v['asset']==asset]
      if earnAsset and float(earnAsset[0]['totalAmount'])>0.1:
          redeemFlexibleSimpleEarnProduct(earnAsset[0]['productId'],0.1)
          amount+=0.1
      sendMessage(f"Subscribe simple earn: {asset}, amount: {amount}")
      sendMessage(subscribeFlexibleSimpleEarnProduct(earnList[asset],amount))
  print('Finish the program')
except Exception as e:
  msg=f'Failed to finish the program: {traceback.format_exc()}'
  sendMessage(msg)
  print(msg)

