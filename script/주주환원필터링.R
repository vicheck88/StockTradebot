setwd("/Users/chyouk.han/Documents/personal_project/StockTradebot/script")
source("./Han2FunctionList.R")
pkg = c('RPostgres', 'DBI','stringr')
new.pkg = pkg[!(pkg %in% installed.packages()[, "Package"])]
if (length(new.pkg)) {
  install.packages(new.pkg, dependencies = TRUE)}
sapply(pkg,library,character.only=T)

config<-fromJSON("~/config.json")
dbconfig<-config$database
conn<-dbConnect(RPostgres::Postgres(),dbname=dbconfig$database,host=dbconfig$host,port=dbconfig$port,user=dbconfig$user,password=dbconfig$passwd)
apiConfig<-config$api$config$prod
account<-config$api$account$prod$main
token<-getToken(apiConfig,account)

# PLUS 자사주매입고배당주
etfCode <- "0098N0"
etfStockTable <- getETFComponentStocks(apiConfig, account, token, etfCode)
etfStockCodeList<- etfStockTable$stck_shrn_iscd

sql<-"SELECT * FROM metainfo.월별기업정보 WHERE 일자=(SELECT max(일자) FROM metainfo.월별기업정보)"
corpTable<-as.data.table(dbGetQuery(conn,SQL(sql)))
corpTable[,pcr:=시가총액/잉여현금흐름]
corpTable[,pbr:=시가총액/자본]
corpTable[,per:=시가총액/지배주주순이익]
corpTable[,roe:=지배주주순이익/자본]
corpTable[,roa:=지배주주순이익/자산]
corpTable[,부채비율:=부채/자본]

cols<-c('pcr','pbr','per','roe')
corpTable[, paste0(cols, "_z") := lapply(.SD, function(v) {
  m <- mean(v, na.rm = TRUE)
  s <- sd(v, na.rm = TRUE)
  if (is.na(s) || s == 0) rep(NA_real_, .N) else (v - m) / s
}), by = '산업분류', .SDcols = cols]

filteredCorpTable<-corpTable[잉여현금흐름 > 0][지배주주순이익 >0][종목코드 %in% etfStockCodeList]
#filteredCorpTable<-corpTable[잉여현금흐름 > 0][지배주주순이익 >0][order(-시가총액)][1:200,]
filteredCorpTable[,pcr_z_rank:=rank(pcr_z)]
filteredCorpTable[,pbr_z_rank:=rank(pbr_z)]
filteredCorpTable[,per_z_rank:=rank(per_z)]
filteredCorpTable[,roe_z_rank:=rank(-roe_z)]

filteredCorpTable[,pcr_rank:=rank(pcr)]
filteredCorpTable[,pbr_rank:=rank(pbr)]
filteredCorpTable[,per_rank:=rank(per)]
filteredCorpTable[,roe_rank:=rank(-roe)]
filteredCorpTable[,.(종목코드,종목명,산업분류,per,per_z,pbr,pbr_z,pcr,pcr_z,roe,roe_z,per_rank,pbr_rank,pcr_rank,roe_rank,per_z_rank,pbr_z_rank,pcr_z_rank,roe_z_rank)][order(pcr_rank)]
