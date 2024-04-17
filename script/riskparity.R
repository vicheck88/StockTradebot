library(quantmod)
library(PerformanceAnalytics)
library(magrittr)
library(tidyr)
library(dplyr)
library(corrplot)
library(nloptr)

symbols = c('XLP',
            'XLY',
            'JETS',
            'PAVE',
            'PBW',
            'ARKK',
            'NRGU',
            'FNGU'
)
getSymbols(symbols, src = 'yahoo')
prices = do.call(cbind,
                 lapply(symbols, function(x) Ad(get(x)))) %>%
  setNames(symbols)

rets = Return.calculate(prices) %>% na.omit()


cor(rets) %>%
  corrplot(method = 'color', type = 'upper',
           addCoef.col = 'black', number.cex = 0.7,
           tl.cex = 0.6, tl.srt=45, tl.col = 'black',
           col =
             colorRampPalette(c('blue', 'white', 'red'))(200),
           mar = c(0,0,0.5,0))
covmat = cov(rets)
library(cccp)

opt = rp(x0 = rep(1/length(symbols),length(symbols)),
         P = covmat,
         mrc = rep(1/length(symbols),length(symbols)))


w = getx(opt) %>% drop()
w = (w / sum(w)) %>%
  round(., 4) %>%
  setNames(colnames(rets))

print(w)
