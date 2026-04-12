#!/usr/bin/env Rscript
# fnguide_consensus.R
# FnGuide 컨센서스 데이터 크롤링 (목표가, EPS, 투자의견)
# JSON endpoint 기반 (SVD_Consensus.asp의 동적 데이터)
#
# Usage:
#   source("fnguide_consensus.R")
#   result <- getConsensusFromFnGuide("005930")
#   # result$opinion, result$target_price, result$eps, result$revenue, result$op_income

library(httr)
library(jsonlite)
library(stringr)

getConsensusFromFnGuide <- function(code, reportGB = "D") {
  # FnGuide 컨센서스 JSON 엔드포인트에서 데이터를 추출한다.
  #
  # Args:
  #   code: 6자리 종목코드 (예: "005930")
  #   reportGB: "D"=연결, "B"=별도
  #
  # Returns:
  #   list(opinion, target_price, eps, revenue, op_income) or NULL
  #
  # JSON endpoints:
  #   Grid1: /SVO2/json/data/01_06/01_A{code}_A_{D|B}.json  (실적+컨센서스 추이)
  #   Grid3: /SVO2/json/data/01_06/03_A{code}.json           (증권사별 목표가)

  ua <- "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
  referer <- "https://comp.fnguide.com/SVO2/ASP/SVD_Consensus.asp"
  base_url <- "https://comp.fnguide.com/SVO2/json/data/01_06"

  # Helper: strip UTF-8 BOM and parse JSON
  parseFnJson <- function(resp) {
    if (status_code(resp) != 200) return(NULL)
    raw <- content(resp, as = "raw")
    if (length(raw) < 4) return(NULL)
    if (as.integer(raw[1]) == 239 && as.integer(raw[2]) == 187 && as.integer(raw[3]) == 191) {
      raw <- raw[4:length(raw)]
    }
    txt <- rawToChar(raw)
    if (is.na(txt) || nchar(txt) < 10) return(NULL)
    tryCatch(fromJSON(txt), error = function(e) NULL)
  }

  parseNum <- function(x) {
    x <- str_replace_all(x, ",", "")
    suppressWarnings(as.numeric(x))
  }

  gicode <- paste0("A", code)

  # =========================================================
  # 1. Grid3: 증권사별 적정주가 & 투자의견
  # =========================================================
  resp3 <- GET(paste0(base_url, "/03_", gicode, ".json"),
               user_agent(ua), add_headers(Referer = referer))
  data3 <- parseFnJson(resp3)
  if (is.null(data3) || is.null(data3$comp) || nrow(data3$comp) == 0) {
    return(NULL)
  }

  brokers <- data3$comp
  target_prices <- parseNum(brokers$TARGET_PRC)
  recom_scores  <- parseNum(brokers$RECOM_CD)

  valid_tp <- !is.na(target_prices) & target_prices > 0
  valid_rc <- !is.na(recom_scores)

  if (sum(valid_tp) == 0 && sum(valid_rc) == 0) return(NULL)

  # RECOM_CD: 5=적극매수, 4=매수, 3=중립, 2=비중축소, 1=매도
  rc_valid <- recom_scores[valid_rc]
  opinion <- list(
    avg_score = parseNum(brokers$AVG_RECOM_CD[1]),
    buy  = sum(rc_valid >= 4),
    hold = sum(rc_valid == 3),
    sell = sum(rc_valid <= 2),
    total = length(rc_valid)
  )

  tp_valid <- target_prices[valid_tp]
  target_price <- list(
    avg          = parseNum(brokers$AVG_PRC[1]),
    max          = if (length(tp_valid) > 0) max(tp_valid) else NA_real_,
    min          = if (length(tp_valid) > 0) min(tp_valid) else NA_real_,
    broker_count = length(tp_valid)
  )

  # =========================================================
  # 2. Grid1: 실적 & 컨센서스 추이 (연간)
  # =========================================================
  resp1 <- GET(paste0(base_url, "/01_", gicode, "_A_", reportGB, ".json"),
               user_agent(ua), add_headers(Referer = referer))
  data1 <- parseFnJson(resp1)

  eps       <- data.frame(period = character(), value = numeric(), stringsAsFactors = FALSE)
  revenue   <- data.frame(period = character(), value = numeric(), stringsAsFactors = FALSE)
  op_income <- data.frame(period = character(), value = numeric(), stringsAsFactors = FALSE)

  if (!is.null(data1) && !is.null(data1$comp) && nrow(data1$comp) > 1) {
    rows   <- data1$comp
    header <- rows[1, ]

    # Find estimate columns: those containing "(E)"
    d_cols      <- names(header)[grepl("^D_", names(header))]
    est_cols    <- c()
    est_periods <- c()
    for (dc in d_cols) {
      val <- header[[dc]]
      if (grepl("[(]E[)]", val)) {
        est_cols    <- c(est_cols, dc)
        est_periods <- c(est_periods, gsub("[(]E[)]", "", val))
      }
    }

    n_periods <- min(2, length(est_cols))
    if (n_periods > 0) {
      eps_row <- rows[grepl("^EPS", rows$ACCOUNT_NM), ]
      rev_row <- rows[grepl("^매출액", rows$ACCOUNT_NM) & rows$GB == "0", ]
      op_row  <- rows[grepl("^영업이익", rows$ACCOUNT_NM) & rows$GB == "0", ]

      for (i in seq_len(n_periods)) {
        col    <- est_cols[i]
        period <- est_periods[i]

        if (nrow(eps_row) > 0)
          eps <- rbind(eps, data.frame(period = period, value = parseNum(eps_row[[col]][1]),
                                       stringsAsFactors = FALSE))
        if (nrow(rev_row) > 0)
          revenue <- rbind(revenue, data.frame(period = period, value = parseNum(rev_row[[col]][1]),
                                               stringsAsFactors = FALSE))
        if (nrow(op_row) > 0)
          op_income <- rbind(op_income, data.frame(period = period, value = parseNum(op_row[[col]][1]),
                                                    stringsAsFactors = FALSE))
      }
    }
  }

  return(list(
    opinion      = opinion,
    target_price = target_price,
    eps          = eps,
    revenue      = revenue,
    op_income    = op_income
  ))
}
