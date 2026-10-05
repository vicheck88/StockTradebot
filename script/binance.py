#!/usr/bin/env python3
# coding: utf-8

# In[3]:


import requests as rq
import hmac
import hashlib
import json
from datetime import datetime,timezone,timedelta
import time
import math
import traceback
import numpy as np


# In[2]:


telegramApi={}
accessKey=''
secretKey=''
headers={}

def loadConfig():
  global telegramApi,accessKey,secretKey,headers
  with open('/home/pi/config.json','r') as f: config=json.load(f)
  telegramApi=config['telegram']
  config=config['binance_key']
  accessKey=config['access_key']
  secretKey=config['secret_key']
  headers={'X-MBX-APIKEY':accessKey}
futureURL = 'https://fapi.binance.com'
spotURL='https://api.binance.com'
headers = {
    'X-MBX-APIKEY': accessKey
}
requestTimeout = (5, 15)
signedRequestRecvWindow = 10000
readRequestAttempts = 3


class BinanceAPIError(RuntimeError):
  def __init__(self,statusCode,code,message):
    self.statusCode=statusCode
    self.code=code
    if code is None: text=f'Binance API HTTP {statusCode}: {message}'
    else: text=f'Binance API error {code}: {message}'
    super().__init__(text)


# In[3]:


def sendMessage(message,count=0):
  url=f"https://api.telegram.org/bot{telegramApi['token']}/sendMessage?chat_id={telegramApi['chatId']}&text={message}"
  try:
    res=rq.post(url,timeout=requestTimeout)
    res.raise_for_status()
    print(f'sendMessage: {res.status_code}')
  except Exception as e:
    print(f'error: {e}')
    print(f'send again: count {count}')
    time.sleep(2)
    if count<10: sendMessage(message,count+1)


# In[4]:


def request(url,method):
  response=rq.request(method.upper(),url,headers=headers,timeout=requestTimeout)
  if not response.ok:
    try:
      error=response.json()
    except ValueError:
      raise BinanceAPIError(response.status_code,None,response.reason)
    raise BinanceAPIError(response.status_code,error.get('code'),error.get('msg'))
  return response
def createSignature(message):
  return hmac.new(key=secretKey.encode('utf-8'), msg=message.encode('utf-8'),digestmod=hashlib.sha256).hexdigest()
def requestData(mainUrl,subUrl,method,message,addSignature=True):
  method=method.upper()
  attempts=readRequestAttempts if method=='GET' else 1
  for attempt in range(attempts):
    currentMessage=message
    if attempt>0 and addSignature:
      currentMessage='&'.join([
        f'timestamp={getCurrentTime()}' if part.startswith('timestamp=') else part
        for part in message.split('&')
      ])
    if addSignature:
      currentMessage+=f'&recvWindow={signedRequestRecvWindow}'
    url=f'{mainUrl}{subUrl}'
    if currentMessage: url+=f'?{currentMessage}'
    if addSignature: url+=f'&signature={createSignature(currentMessage)}'
    try:
      return request(url,method).json()
    except BinanceAPIError as e:
      retryable=e.code==-1021 or e.statusCode>=500
      if not retryable or attempt==attempts-1: raise
    except rq.RequestException:
      if attempt==attempts-1: raise
    except ValueError as e:
      if attempt==attempts-1:
        raise RuntimeError(f'Binance returned invalid JSON for {subUrl}') from e
    time.sleep(attempt+1)


# In[5]:


def getCurrentTime():
  subUrl='/api/v3/time'
  return requestData(spotURL,subUrl,'get','',addSignature=False)['serverTime']
def getCoinPriceHistory(symbol,unit,count):
  msg=f'symbol={symbol}&interval={unit}&limit={count}'
  return requestData(spotURL,'/api/v3/klines','get',msg,addSignature=False)
def getCurrentPrice(symbol=None):
  msg='' if symbol==None else f'symbol={symbol}'
  return requestData(spotURL,'/api/v3/ticker/price','get',msg,addSignature=False)
def getSpotExchangeInfo(symbol):
  return requestData(spotURL,'/api/v3/exchangeInfo','get',f'symbol={symbol}',addSignature=False)
def getSpotOrder(symbol,clientOrderId):
  return requestData(spotURL,'/api/v3/order','get',f'symbol={symbol}&origClientOrderId={clientOrderId}&timestamp={getCurrentTime()}')
def cancelSpotOrder(symbol,orderId=None,clientOrderId=None):
  orderRef=f'orderId={orderId}' if orderId is not None else f'origClientOrderId={clientOrderId}'
  return requestData(spotURL,'/api/v3/order','delete',f'symbol={symbol}&{orderRef}&timestamp={getCurrentTime()}')
def getSpotUserTrades(symbol,orderId):
  return requestData(spotURL,'/api/v3/myTrades','get',f'symbol={symbol}&orderId={orderId}&timestamp={getCurrentTime()}')
def orderSpotMarketByQuoteAmount(symbol,quoteAmount,clientOrderId):
  msg=f'symbol={symbol}&side=BUY&type=MARKET&quoteOrderQty={quoteAmount}&newOrderRespType=FULL&newClientOrderId={clientOrderId}&timestamp={getCurrentTime()}'
  return requestData(spotURL,'/api/v3/order','post',msg)
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
  amount=floorToDecimal(float(amount),8)
  amountText=f'{amount:.8f}'
  msg=f'asset={asset}&amount={amountText}&type={t}&timestamp={getCurrentTime()}'
  return requestData(spotURL,'/sapi/v1/asset/transfer','post',msg)

def getFlexibleSimpleEarnList(asset):
  return requestData(spotURL,'/sapi/v1/simple-earn/flexible/list','get',f'asset={asset}&timestamp={getCurrentTime()}')
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
def orderFutureWithTimeLimit(symbol,side,quantity,price,timeLimit,clientOrderId=None):
  limitDate=datetime.now()+timedelta(timeLimit)
  clientIdParam=f'&newClientOrderId={clientOrderId}' if clientOrderId else ''
  return requestData(futureURL,'/fapi/v1/order','post',f'symbol={symbol}&side={side}&type=LIMIT&quantity={quantity}&price={price}&timeInForce=GTD&goodTillDate={int(limitDate.timestamp()*1000)}{clientIdParam}&timestamp={getCurrentTime()}')
def orderFutureMarketType(symbol,side,quantity):
  return requestData(futureURL,'/fapi/v1/order','post',f'symbol={symbol}&side={side}&type=MARKET&quantity={quantity}&timestamp={getCurrentTime()}')
def getFutureOrder(symbol,orderId=None,clientOrderId=None):
  orderRef=f'orderId={orderId}' if orderId is not None else f'origClientOrderId={clientOrderId}'
  return requestData(futureURL,'/fapi/v1/order','get',f'symbol={symbol}&{orderRef}&timestamp={getCurrentTime()}')
def getFutureUserTrades(symbol,orderId):
  return requestData(futureURL,'/fapi/v1/userTrades','get',f'symbol={symbol}&orderId={orderId}&timestamp={getCurrentTime()}')
def cancelFutureOrder(symbol,orderId=None,clientOrderId=None):
  orderRef=f'orderId={orderId}' if orderId is not None else f'origClientOrderId={clientOrderId}'
  return requestData(futureURL,'/fapi/v1/order','delete',f'symbol={symbol}&{orderRef}&timestamp={getCurrentTime()}')
def setStopMarketPrice(symbol,side,stopPrice,quantity,workingType):
  return requestData(futureURL,'/fapi/v1/algoOrder','post',f'algoType=CONDITIONAL&symbol={symbol}&side={side}&type=STOP_MARKET&triggerPrice={stopPrice}&quantity={quantity}&reduceOnly=false&workingType={workingType}&timestamp={getCurrentTime()}')
def setPositionClosePrice(symbol,side,stopPrice,workingType):
  return requestData(futureURL,'/fapi/v1/algoOrder','post',f'algoType=CONDITIONAL&symbol={symbol}&side={side}&type=STOP_MARKET&triggerPrice={stopPrice}&closePosition=true&workingType={workingType}&timestamp={getCurrentTime()}')
def setStopLimitPrice(symbol,side,stopPrice,quantity,workingType,priceMatch):
  return requestData(futureURL,'/fapi/v1/algoOrder','post',f'algoType=CONDITIONAL&symbol={symbol}&side={side}&type=STOP&triggerPrice={stopPrice}&quantity={quantity}&reduceOnly=true&workingType={workingType}&priceMatch={priceMatch}&timestamp={getCurrentTime()}')
def getCurrentPosition(symbol=None):
  msg=f'symbol={symbol}&timestamp={getCurrentTime()}' if symbol else f'timestamp={getCurrentTime()}'
  return requestData(futureURL,'/fapi/v3/positionRisk','get',msg)
def getFuturePositionMode():
  return requestData(futureURL,'/fapi/v1/positionSide/dual','get',f'timestamp={getCurrentTime()}')
def getAllOpenOrders():
  return requestData(futureURL,'/fapi/v1/openOrders','get',f'timestamp={getCurrentTime()}')
def getAllAlgoOpenOrders():
  return requestData(futureURL,'/fapi/v1/openAlgoOrders','get',f'timestamp={getCurrentTime()}')
def cancelAlgoOrder(symbol,algoId):
  return requestData(futureURL,'/fapi/v1/algoOrder','delete',f'algoId={algoId}&timestamp={getCurrentTime()}')
def closeAllAlgoOpenOrders():
  openOrderSymbolList=set([v['symbol'] for v in getAllAlgoOpenOrders()])
  for symbol in openOrderSymbolList:
    requestData(futureURL,'/fapi/v1/algoOpenOrders','delete',f'symbol={symbol}&timestamp={getCurrentTime()}')
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
def getCoinFutureMarkMovingAvgList(symbol,unit,count,num):
  allHistory=getCoinFutureMarkPriceHistory(symbol,unit,count+num-1)
  historyList=[allHistory[i:i+count] for i in range(len(allHistory)-count+1)]
  return [sum([float(d[4]) for d in history])/len(history) for history in historyList]
def analyzeClosedMarkCandles(history,serverTime,maPeriod):
  closedCandles=[candle for candle in history if int(candle[6])<int(serverTime)]
  requiredCount=maPeriod+4
  if len(closedCandles)<requiredCount:
    raise RuntimeError(f'Need {requiredCount} completed daily mark candles; got {len(closedCandles)}')
  closedCandles=closedCandles[-requiredCount:]
  closePrices=[float(candle[4]) for candle in closedCandles]
  movingAverageList=[
    sum(closePrices[i:i+maPeriod])/maPeriod
    for i in range(len(closePrices)-maPeriod+1)
  ]
  movingAverage=movingAverageList[-1]
  return {
    'averagePrice':movingAverage,
    'averagePriceList':movingAverageList,
    'lastClosedPrice':closePrices[-1],
    'disparity':closePrices[-1]/movingAverage*100,
    'isIncreasing':isMovingAvgIncreasing(movingAverageList)
  }
def getClosedDailyMarkAnalysis(symbol,maPeriod):
  serverTime=getCurrentTime()
  history=getCoinFutureMarkPriceHistory(symbol,'1d',maPeriod+6)
  return analyzeClosedMarkCandles(history,serverTime,maPeriod)
def isMovingAvgIncreasing(averagePriceList):
  x=np.arange(len(averagePriceList))
  y=np.array(averagePriceList)
  slope, _ = np.polyfit(x,y,1)
  return slope>0
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
  ratio=1 if asset=='USDT' else float(getCurrentPrice(f'{asset}USDT')['price'])
  for asset in investInfo: investInfo[asset]*=ratio
  return investInfo

def determineInvestInfo(disparity,currentInvestInfo,isIncreasing,maxLeverage):
  d=disparity-100
  ratio=math.floor(d)/2
  #ratio=math.floor((d+1)/2)/maxLeverage
  newRatio=min(ratio,1) if d>0 and isIncreasing else 0
  ret={}
  ret['investRatio']=newRatio
  ret['total']=currentInvestInfo['total']
  ret['future']=ret['total']*newRatio
  ret['earn']=ret['total']-ret['future']
  ret['spot']=0
  return ret
def getAccountChange(coinsymbols,cashsymbols,isIncreasing,disparity,maxLeverage):
  investInfo=convertAccountUnit(cashsymbols[0],getCurrentInvestInfo(coinsymbols,cashsymbols))
  goalInvestInfo=determineInvestInfo(disparity,investInfo,isIncreasing,maxLeverage)
  accountChangeInfo=goalInvestInfo
  accountChangeInfo['spot']-=investInfo['spot']
  accountChangeInfo['future']-=investInfo['future']
  accountChangeInfo['earn']-=investInfo['earn']
  return accountChangeInfo
def getBuyFundingPlan(changeInfo,spotAvailable,minOrderLimit):
  desiredFunding=max(0.0,float(changeInfo['future']))
  spotAvailable=max(0.0,float(spotAvailable))
  if desiredFunding<=minOrderLimit:
    return {'buyBudget':0.0,'remainingSpot':spotAvailable}
  buyBudget=min(desiredFunding,spotAvailable)
  if buyBudget<=minOrderLimit:
    buyBudget=0.0
  return {'buyBudget':buyBudget,'remainingSpot':spotAvailable-buyBudget}
def hasOpenFutureBuy(orders,symbol):
  return any(
    order.get('symbol')==symbol and order.get('side')=='BUY'
    and order.get('status') in ('NEW','PARTIALLY_FILLED')
    for order in orders
  )
def getBnbQuoteBudget(order,buyBudget,maxLeverage,futureAvailable,usdtCommission=0):
  if order.get('status') not in ('FILLED','CANCELED','EXPIRED','EXPIRED_IN_MATCH'):
    return 0.0
  originalQuantity=float(order.get('origQty',0) or 0)
  executedQuantity=float(order.get('executedQty',0) or 0)
  if originalQuantity<=0 or executedQuantity<=0:
    return 0.0
  filledRatio=min(1.0,executedQuantity/originalQuantity)
  executedQuote=float(order.get('cumQuote',0) or 0)
  if executedQuote<=0:
    executedQuote=executedQuantity*float(order.get('avgPrice',0) or 0)
  if executedQuote<=0:
    return 0.0
  filledBudget=float(buyBudget)*filledRatio
  usedBudget=executedQuote/float(maxLeverage)+max(0.0,float(usdtCommission))
  return min(max(0.0,filledBudget-usedBudget),max(0.0,float(futureAvailable)))
def getConfirmedFutureUsdtCommission(order,trades):
  expected=float(order.get('executedQty',0) or 0)
  if expected<=0 or not trades:
    return None
  if any('qty' not in trade or 'commission' not in trade or not trade.get('commissionAsset') for trade in trades):
    return None
  traded=sum(float(trade['qty']) for trade in trades)
  if abs(traded-expected)>max(1e-8,expected*1e-8):
    return None
  return sum(float(trade['commission']) for trade in trades if trade['commissionAsset']=='USDT')
def getConfirmedNetBnbPurchase(order,trades):
  expected=float(order.get('executedQty',0) or 0)
  if expected<=0 or not trades:
    return 0.0
  if any('qty' not in trade or 'commission' not in trade or not trade.get('commissionAsset') for trade in trades):
    return 0.0
  purchased=sum(float(trade['qty']) for trade in trades)
  if abs(purchased-expected)>max(1e-8,expected*1e-8):
    return 0.0
  bnbCommission=sum(float(trade['commission']) for trade in trades if trade['commissionAsset']=='BNB')
  return floorToDecimal(max(0.0,purchased-bnbCommission),8)
def getSpotMarketQuoteBudget(exchangeInfo,budget,spotAvailable,price):
  symbolInfo=next((row for row in exchangeInfo.get('symbols',[]) if row.get('symbol')=='BNBUSDT'),None)
  if not symbolInfo:
    return 0.0
  filters={row.get('filterType'):row for row in symbolInfo.get('filters',[])}
  minNotional=0.0
  notionalFilter=filters.get('NOTIONAL') or filters.get('MIN_NOTIONAL')
  if notionalFilter:
    marketField='applyMinToMarket' if notionalFilter.get('filterType')=='NOTIONAL' else 'applyToMarket'
    if notionalFilter.get(marketField,True):
      minNotional=float(notionalFilter.get('minNotional',0) or 0)
  marketLot=filters.get('MARKET_LOT_SIZE') or filters.get('LOT_SIZE')
  if marketLot:
    minNotional=max(minNotional,float(marketLot.get('minQty',0) or 0)*float(price))
  if minNotional<=0:
    return 0.0
  quotePrecision=int(symbolInfo.get('quoteAssetPrecision',8))
  quoteBudget=floorToDecimal(min(float(budget),float(spotAvailable)),quotePrecision)
  return quoteBudget if quoteBudget>=minNotional else 0.0


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

def getSpotFreeBalance(account,asset):
  balance=next((row for row in account.get('balances',[]) if row.get('asset')==asset),None)
  return float(balance.get('free',0)) if balance else 0.0

def isFullCloseStop(order,symbol):
  orderType=order.get('type',order.get('orderType'))
  closePosition=order.get('closePosition') in (True,'true','True')
  return order.get('symbol')==symbol and order.get('side')=='SELL' and orderType=='STOP_MARKET' and closePosition

def getAlgoTriggerPrice(order):
  return float(order.get('triggerPrice',order.get('stopPrice',0)) or 0)

def isConfirmedFullCloseStop(order,symbol,stopPrice):
  return (
    isFullCloseStop(order,symbol)
    and order.get('algoId') is not None
    and order.get('algoStatus',order.get('status'))=='NEW'
    and getAlgoTriggerPrice(order)==float(stopPrice)
  )

def isConfirmedPartialStop(order,symbol,stopPrice):
  orderType=order.get('type',order.get('orderType'))
  reduceOnly=order.get('reduceOnly') in (True,'true','True')
  return (
    order.get('symbol')==symbol and order.get('side')=='SELL' and orderType=='STOP'
    and reduceOnly and order.get('algoId') is not None
    and order.get('algoStatus',order.get('status'))=='NEW'
    and getAlgoTriggerPrice(order)==float(stopPrice)
  )

def ensurePreBuyFullCloseStop(symbol,markPrice,averagePrice):
  stopPrice=math.floor(averagePrice*0.99)
  if markPrice<=stopPrice:
    raise RuntimeError('Current mark price is at or below the BTC stop trigger')
  openOrders=getAllAlgoOpenOrders()
  matching=[order for order in openOrders if isConfirmedFullCloseStop(order,symbol,stopPrice)]
  if matching:
    return matching[0],False
  order=setPositionClosePrice(symbol,'SELL',stopPrice,'MARK_PRICE')
  if not isConfirmedFullCloseStop(order,symbol,stopPrice):
    raise RuntimeError('Could not confirm the BTC full-close stop before the buy')
  return order,True

def refreshPositionStops(symbol,curPrice,averagePrice,positionAmount,preBuyStopId=None):
  if float(positionAmount)<=0:
    return
  closeStopPrice=math.floor(averagePrice*0.99)
  orders=[order for order in getAllAlgoOpenOrders() if order.get('symbol')==symbol and order.get('side')=='SELL']
  fullStops=[order for order in orders if isFullCloseStop(order,symbol)]
  matchingFull=[order for order in fullStops if isConfirmedFullCloseStop(order,symbol,closeStopPrice)]
  if matchingFull:
    keepFull=matchingFull[0]
  else:
    keepFull=setPositionClosePrice(symbol,'SELL',closeStopPrice,'MARK_PRICE')
    if not isConfirmedFullCloseStop(keepFull,symbol,closeStopPrice):
      raise RuntimeError('Could not confirm the BTC full-close stop')
  partialStops=[
    order for order in orders
    if order.get('type',order.get('orderType'))=='STOP' and not isFullCloseStop(order,symbol)
  ]
  for order in partialStops:
    algoId=order.get('algoId')
    if algoId is None:
      raise RuntimeError('Cannot safely replace a BTC partial stop without its algo ID')
    cancelAlgoOrder(symbol,algoId)
  if curPrice>averagePrice:
    quantity=floorToDecimal(float(positionAmount)/2,3)
    if quantity>0:
      partial=setStopLimitPrice(symbol,'SELL',averagePrice,quantity,'MARK_PRICE','OPPONENT')
      if not isConfirmedPartialStop(partial,symbol,averagePrice):
        raise RuntimeError('Could not confirm the BTC reduce-only partial stop')
  keepFullId=keepFull.get('algoId')
  for order in fullStops:
    algoId=order.get('algoId')
    if algoId is not None and algoId!=keepFullId:
      cancelAlgoOrder(symbol,algoId)

def buyFeeBnbFromSpot(quoteBudget):
  if quoteBudget<=0:
    return 0.0
  exchangeInfo=getSpotExchangeInfo('BNBUSDT')
  price=float(getCurrentPrice('BNBUSDT')['price'])
  spotFree=getSpotFreeBalance(getAccount(),'USDT')
  quoteAmount=getSpotMarketQuoteBudget(exchangeInfo,quoteBudget,spotFree,price)
  if quoteAmount<=0:
    return 0.0
  clientOrderId=f'bnb-{getCurrentTime()}'
  try:
    order=orderSpotMarketByQuoteAmount('BNBUSDT',quoteAmount,clientOrderId)
  except Exception:
    order=getSpotOrder('BNBUSDT',clientOrderId)
  if order.get('status')=='PARTIALLY_FILLED':
    cancelSpotOrder('BNBUSDT',orderId=order.get('orderId'),clientOrderId=None if order.get('orderId') is not None else clientOrderId)
    order=getSpotOrder('BNBUSDT',clientOrderId)
  if order.get('status') not in ('FILLED','CANCELED','EXPIRED','EXPIRED_IN_MATCH'):
    return 0.0
  fills=order.get('fills',[])
  if not fills and float(order.get('executedQty',0) or 0)>0 and order.get('orderId') is not None:
    fills=getSpotUserTrades('BNBUSDT',order['orderId'])
  netPurchased=getConfirmedNetBnbPurchase(order,fills)
  if netPurchased>0:
    transfer('main','umfuture','BNB',netPurchased)
  return netPurchased


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


# In[ ]:


coinsymbols=['BTC']
cashsymbols=['USDT']
symbol=coinsymbols[0]+cashsymbols[0]
leverage=3
movingAveragePeriod=60
stopLimitLevelNum=2
avoidInsufficientErrorRatio=0.98
minOrderQuantityLimit=0.005

try:
  #현재 이동평균선 확인 후 투자 비율 계산
  loadConfig()
  print(f'start program: {datetime.now()}')
  analysis=getClosedDailyMarkAnalysis(symbol,movingAveragePeriod)
  disparity=analysis['disparity']
  averagePrice=floorToDecimal(analysis['averagePrice'],1)
  averagePriceList=analysis['averagePriceList']
  print(f'average price: {averagePriceList}')
  isIncreasing=analysis['isIncreasing']
  accountChangeInfo=getAccountChange(coinsymbols,cashsymbols,isIncreasing,disparity,leverage)
  minOrderLimit=float(getCurrentPrice(symbol)['price'])*minOrderQuantityLimit
  minEarnLimit=0.1
  curPrice=floorToDecimal(float(getCurrentPrice(symbol)['price']),1)
  markPrice=float(getCurrentFutureMarkPrice(symbol)['markPrice'])

  transferrableList=[v for v in getFutureAccount()['assets'] if float(v.get('maxWithdrawAmount',0))>0 and v['asset']!='BNB']
  for asset in transferrableList: transfer('umfuture','main',asset['asset'],float(asset['maxWithdrawAmount']))

  if accountChangeInfo['earn']<0 and abs(accountChangeInfo['earn'])>minOrderLimit:
    print('redeem simple earn assets and transfer it into spot account')
    earnProducts=getFlexibleSimpleEarnList(cashsymbols[0])['rows']
    if not earnProducts: raise RuntimeError(f'No flexible Simple Earn product for {cashsymbols[0]}')
    prodId=earnProducts[0]['productId']
    amount= 0 if accountChangeInfo['investRatio']==1 else -accountChangeInfo['earn']
    sendMessage(redeemFlexibleSimpleEarnProduct(prodId,floorToDecimal(amount,8)))

  spotAccount=getAccount()
  freeBalances=[v for v in spotAccount['balances'] if v['asset'] in cashsymbols and float(v['free'])>0]
  print(f'free balances: {freeBalances}')
  updatedChangeInfo=getAccountChange(coinsymbols,cashsymbols,isIncreasing,disparity,leverage)
  print(f'balance change: {updatedChangeInfo}')
  fundingPlan=getBuyFundingPlan(updatedChangeInfo,getSpotFreeBalance(spotAccount,cashsymbols[0]),minOrderLimit)
  buyBudget=fundingPlan['buyBudget']
  pendingBuy=hasOpenFutureBuy(getAllOpenOrders(),symbol)
  positionData=getCurrentPosition(symbol)
  positionRow=next((v for v in positionData if v.get('symbol')==symbol),None)
  preBuyStop=None
  preBuyStopCreated=False
  settledOrder=None
  buyAttempted=False
  if buyBudget>0 and not pendingBuy:
    if getFuturePositionMode().get('dualSidePosition') is not False:
      raise RuntimeError('The BTC BUY requires confirmed one-way futures position mode')
    existingPosition=float(positionRow.get('positionAmt',0) or 0) if positionRow else 0.0
    if existingPosition>0 and positionRow.get('positionSide')!='BOTH':
      raise RuntimeError('The BTC BUY requires a confirmed one-way futures position')
    if existingPosition<0:
      raise RuntimeError('Refusing a ratio BUY while a BTC short position exists')
    if markPrice<=math.floor(averagePrice*0.99):
      raise RuntimeError('Current mark price is at or below the BTC stop trigger')
    newPositionAmount=floorToDecimal(buyBudget*leverage/curPrice*avoidInsufficientErrorRatio,3)
    if newPositionAmount<=0:
      raise RuntimeError('The desired BTC buy budget rounds below the exchange quantity precision')
    leverageResponse=changeFutureLeverage(symbol,leverage)
    if int(leverageResponse.get('leverage',0))!=int(leverage):
      raise RuntimeError('Could not confirm the configured futures leverage')
    preBuyStop,preBuyStopCreated=ensurePreBuyFullCloseStop(symbol,markPrice,averagePrice)
    sendMessage("binance future BUY")
    sendMessage(f'disparity: {disparity}')
    sendMessage(updatedChangeInfo)
    transfer('main','umfuture',cashsymbols[0],buyBudget)
    clientOrderId=f'btc-budget-{getCurrentTime()}'
    buyAttempted=True
    try:
      orderResponse=orderFutureWithTimeLimit(symbol,'BUY',newPositionAmount,curPrice,1000,clientOrderId)
    except Exception:
      orderResponse=getFutureOrder(symbol,clientOrderId=clientOrderId)
    sendMessage(orderResponse)
    orderId=orderResponse.get('orderId')
    time.sleep(100)
    settledOrder=getFutureOrder(symbol,orderId=orderId) if orderId is not None else getFutureOrder(symbol,clientOrderId=clientOrderId)
    if settledOrder.get('status') in ('NEW','PARTIALLY_FILLED'):
      orderId=settledOrder.get('orderId',orderId)
      cancelFutureOrder(symbol,orderId=orderId,clientOrderId=None if orderId is not None else clientOrderId)
      settledOrder=getFutureOrder(symbol,orderId=orderId) if orderId is not None else getFutureOrder(symbol,clientOrderId=clientOrderId)
  elif buyBudget>0 and pendingBuy:
    sendMessage('Existing BTC BUY order is still open; no duplicate budget was transferred')

  positionData=getCurrentPosition(symbol)
  positionRow=next((v for v in positionData if v.get('symbol')==symbol),None)
  positionAmount=float(positionRow.get('positionAmt',0) or 0) if positionRow else 0.0
  if positionAmount>0:
    if positionRow.get('positionSide')!='BOTH':
      raise RuntimeError('Cannot safely update BTC reduce-only stops outside one-way mode')
    refreshPositionStops(symbol,curPrice,averagePrice,positionAmount)
  elif buyAttempted and settledOrder and settledOrder.get('status') not in ('NEW','PARTIALLY_FILLED') and preBuyStopCreated:
    algoId=preBuyStop.get('algoId')
    if algoId is not None:
      cancelAlgoOrder(symbol,algoId)

  if buyAttempted and settledOrder and settledOrder.get('status') in ('FILLED','CANCELED','EXPIRED','EXPIRED_IN_MATCH'):
    executedQuantity=float(settledOrder.get('executedQty',0) or 0)
    if executedQuantity>0 and settledOrder.get('orderId') is not None:
      try:
        trades=getFutureUserTrades(symbol,settledOrder['orderId'])
        usdtCommission=getConfirmedFutureUsdtCommission(settledOrder,trades)
      except Exception:
        usdtCommission=None
      if usdtCommission is None:
        sendMessage('BNB purchase skipped because futures fills or fees could not be confirmed')
      else:
        futureAccount=getFutureAccount()
        futureUsdt=next((asset for asset in futureAccount['assets'] if asset['asset']=='USDT'),{})
        bnbQuoteBudget=floorToDecimal(getBnbQuoteBudget(settledOrder,buyBudget,leverage,float(futureUsdt.get('maxWithdrawAmount',0)),usdtCommission),8)
        if bnbQuoteBudget>0:
          try:
            transfer('umfuture','main','USDT',bnbQuoteBudget)
            purchasedBnb=buyFeeBnbFromSpot(bnbQuoteBudget)
            if purchasedBnb<=0:
              sendMessage('BNB purchase was below the current spot minimum; the USDT remains available for Simple Earn')
          except Exception:
            sendMessage('BNB purchase could not be confirmed; remaining USDT stays eligible for Simple Earn')

  earnList=dict([(v['asset'],v['productId']) for v in getFlexibleSimpleEarnList(cashsymbols[0])['rows']])
  futureBalances=dict([(v['asset'],float(v['maxWithdrawAmount'])) for v in getFutureAccount()['assets'] if float(v.get('maxWithdrawAmount',0))>0 and v['asset'] in cashsymbols])
  for asset,amt in futureBalances.items():
    if asset in earnList:
      sendMessage(transfer('umfuture','main',asset,amt))

  spotBalances=dict([(v['asset'],float(v['free'])) for v in getAccount()['balances'] if float(v['free'])>0])
  for asset,amt in spotBalances.items():
    if asset not in earnList or amt<0.1: continue
    sendMessage(f"Subscribe simple earn: {asset}, amount: {amt}")
    sendMessage(subscribeFlexibleSimpleEarnProduct(earnList[asset],amt))
  print('Finish the program')
except Exception as e:
  msg=f'Failed to finish the program: {traceback.format_exc()}'
  sendMessage(msg)
  print(msg)
