setwd("/home/pi/stockInfoCrawler/StockTradebot/Rscript")
source("./coinFunctionList.R",encoding="utf-8")
rebalanceWeight(getEqualWeightBalanceDiff(10))
