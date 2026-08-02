#!/usr/bin/env Rscript

# Rebuild one monthly snapshot from existing FnGuide financial-statement data.
# Usage: Rscript RebuildMonthlyCorpInfo.R --date=YYYY-MM-DD [--missing-only] [--dry-run]

suppressPackageStartupMessages({
  library(RPostgres)
  library(DBI)
  library(jsonlite)
  library(data.table)
})

args <- commandArgs(trailingOnly=TRUE)
date_args <- args[grepl('^--date=',args)]
if(length(date_args)!=1) stop('Usage: --date=YYYY-MM-DD [--dry-run]',call.=FALSE)

target_date <- as.Date(sub('^--date=','',date_args))
if(is.na(target_date)) stop('--date must use YYYY-MM-DD',call.=FALSE)
target_date_sql <- format(target_date,'%Y-%m-%d')
dry_run <- '--dry-run' %in% args
missing_only <- '--missing-only' %in% args

script_arg <- commandArgs()[grepl('^--file=',commandArgs())][1]
script_dir <- dirname(normalizePath(sub('^--file=','',script_arg)))
source(file.path(script_dir,'RQuantFunctionList.R'),encoding='utf-8')

config <- read_json('~/config.json')
db_config <- config$database
conn <- dbConnect(
  RPostgres::Postgres(),
  dbname=db_config$database,
  host=db_config$host,
  port=db_config$port,
  user=db_config$user,
  password=db_config$passwd
)
on.exit(dbDisconnect(conn),add=TRUE)

existing_tickers <- data.table(dbGetQuery(
  conn,
  SQL(sprintf("SELECT 종목코드 FROM metainfo.월별기업정보 WHERE 일자='%s'",target_date_sql))
))
old_count <- nrow(existing_tickers)

day <- format(target_date,'%Y%m%d')
corp_table <- as.data.table(KRXDataMerge(day,config$krx))
if(nrow(corp_table)==0) stop('KRXDataMerge returned no ticker rows',call.=FALSE)
if(anyDuplicated(corp_table$종목코드)) stop('KRXDataMerge returned duplicate ticker codes',call.=FALSE)
if(missing_only) {
  corp_table <- corp_table[!종목코드 %in% existing_tickers$종목코드]
  if(nrow(corp_table)==0) stop('No missing tickers to backfill',call.=FALSE)
}
cat(sprintf('Rebuilding %s: KRX tickers=%d, existing rows=%.0f\n',target_date_sql,nrow(corp_table),old_count))

code_sql <- paste(as.character(dbQuoteString(conn,corp_table$종목코드)),collapse=',')
annual_all <- data.table(dbGetQuery(conn,SQL(sprintf(
  'SELECT * FROM metainfo.연간재무제표 WHERE 종목코드 IN (%s)',code_sql
))))
quarter_all <- data.table(dbGetQuery(conn,SQL(sprintf(
  'SELECT * FROM metainfo.분기재무제표 WHERE 종목코드 IN (%s)',code_sql
))))
cat(sprintf('Loaded financial statements: annual=%d, quarterly=%d\n',nrow(annual_all),nrow(quarter_all)))

monthly_rows <- NULL
for(i in seq_len(nrow(corp_table))) {
  code <- corp_table[i,종목코드]
  fs_y <- annual_all[종목코드==code & 연결구분=='연결']
  fs_q <- quarter_all[종목코드==code & 연결구분=='연결']
  fs_y_sep <- annual_all[종목코드==code & 연결구분=='별도']
  fs_q_sep <- quarter_all[종목코드==code & 연결구분=='별도']

  fs_y <- unique(fs_y,by=names(fs_y)[1:4])
  fs_q <- unique(fs_q,by=names(fs_q)[1:4])
  fs_y_sep <- unique(fs_y_sep,by=names(fs_y_sep)[1:4])
  fs_q_sep <- unique(fs_q_sep,by=names(fs_q_sep)[1:4])
  row <- cleanDataAndExtractEntitiesFromFS(corp_table[i,],fs_y,fs_q,TRUE,fs_y_sep,fs_q_sep)

  if(!is.null(row)) {
    if(!is.null(monthly_rows)) names(row) <- names(monthly_rows)
    monthly_rows <- rbind(monthly_rows,row)
  }
  if(i %% 100 == 0 || i == nrow(corp_table)) {
    cat(sprintf('Summarized %d/%d tickers\n',i,nrow(corp_table)))
  }
}

if(is.null(monthly_rows) || nrow(monthly_rows)==0) {
  stop('Monthly summary returned no rows',call.=FALSE)
}
if(any(monthly_rows$일자!=target_date)) stop('Monthly summary date validation failed',call.=FALSE)
if(anyDuplicated(monthly_rows$종목코드)) stop('Monthly summary contains duplicate ticker codes',call.=FALSE)
if(!missing_only && nrow(monthly_rows)<old_count) {
  stop(sprintf('Refusing to replace %d rows with only %d rows',old_count,nrow(monthly_rows)),call.=FALSE)
}

missing_codes <- setdiff(corp_table$종목코드,monthly_rows$종목코드)
cat(sprintf(
  'Validation passed: rebuilt rows=%d, missing financial summaries=%d, TES included=%s',
  nrow(monthly_rows),length(missing_codes),'095610' %in% monthly_rows$종목코드
),"\n")

if(dry_run) {
  cat('Dry run complete; database unchanged\n')
} else {
  dbWithTransaction(conn,{
    if(!missing_only) {
      dbExecute(conn,SQL(sprintf("DELETE FROM metainfo.월별기업정보 WHERE 일자='%s'",target_date_sql)))
    } else {
      duplicate_count <- dbGetQuery(
        conn,
        SQL(sprintf(
          "SELECT COUNT(*) AS n FROM metainfo.월별기업정보 WHERE 일자='%s' AND 종목코드 IN (%s)",
          target_date_sql,code_sql
        ))
      )$n
      if(duplicate_count>0) stop('Backfill contains ticker codes already in the snapshot',call.=FALSE)
    }
    dbWriteTable(conn,SQL('metainfo.월별기업정보'),monthly_rows,append=TRUE,row.names=FALSE)
    new_count <- dbGetQuery(
      conn,
      SQL(sprintf("SELECT COUNT(*) AS n FROM metainfo.월별기업정보 WHERE 일자='%s'",target_date_sql))
    )$n
    expected_count <- if(missing_only) old_count+nrow(monthly_rows) else nrow(monthly_rows)
    if(new_count!=expected_count) stop('Monthly rebuild row-count validation failed',call.=FALSE)
  })
  cat(sprintf(
    'Rebuild complete: %s added %d rows; snapshot now has %d rows\n',
    target_date_sql,nrow(monthly_rows),new_count
  ))
}
