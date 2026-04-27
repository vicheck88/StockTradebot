#Sys.setlocale('LC_ALL','en_US.UTF-8')
source("~/StockTradebot/script/RQuantFunctionList.R") #라즈베리에서 읽는 경우
source("~/StockTradebot/script/Han2FunctionList.R") #라즈베리에서 읽는 경우
source("~/StockTradebot/script/telegramAPI.R") #라즈베리에서 읽는 경우

#source("~/stockInfoCrawler/StockTradebot/script/RQuantFunctionList.R") #macOS에서 읽는 경우
#source("~/stockInfoCrawler/StockTradebot/script/Han2FunctionList.R") #macOS에서 읽는 경우
#source("~/stockInfoCrawler/StockTradebot/script/telegramAPI.R") #macOS에서 읽는 경우


pkg = c('data.table','xts','quantmod','stringr','timeDate','lubridate','jsonlite')
new.pkg = pkg[!(pkg %in% installed.packages()[, "Package"])]
if (length(new.pkg)) {
  install.packages(new.pkg, dependencies = TRUE)}
sapply(pkg,library,character.only=T)

# DRY_RUN 환경변수 — 실주문 발송 없이 sheet만 출력
DRY_RUN <- !is.null(Sys.getenv("DRY_RUN", unset=NA)) && tolower(Sys.getenv("DRY_RUN")) %in% c("1","true","y","yes")

today<-str_replace_all(Sys.Date(),"-","")

if(!DRY_RUN){
  if(wday(Sys.Date()) %in% c(1,7)) stop("Weekend")
  if(isHoliday(today)) stop("Holiday")
}

# ====== 분할 일정 (5/5 어린이날 회피) ======
SCHEDULE_DATES <- c("20260428","20260504","20260512","20260519")
if(!(today %in% SCHEDULE_DATES)){
  cat("[",today,"] Not a scheduled split-buy date. Skip (no token issued).\n", sep="")
  quit()
}
ROUND_NO <- which(SCHEDULE_DATES == today)
ROUND_LIMIT <- 25000000   # 차수당 한도
TOTAL_CAP   <- 100000000  # 총 목표

# ====== 잠금 8종목 (코어 4 + 위성 4) ======
LOCKED <- data.table(
  code   = c("000660","005930","071050","000270","267260","278470","095610","064350"),
  name   = c("SK하이닉스","삼성전자","한국금융지주","기아","HD현대일렉트릭","에이피알","테스","현대로템"),
  weight = c(25,15,15,11,10,8,8,8),
  tier   = c("core","core","core","core","sat","sat","sat","sat"),
  held   = c(TRUE,FALSE,FALSE,TRUE,FALSE,FALSE,FALSE,FALSE)
)
LOCKED[, target_amt := TOTAL_CAP * weight / 100]

# ====== 1차 한정 잠금 외 매도 ======
NON_LOCKED_SELL <- c("017670","055550","005830")  # SKT/신한지주/DB손보

# ====== SOFR ETF ======
SOFR_CODE <- "456610"
SOFR_NAME <- "TIGER 미국달러SOFR금리액티브(합성)"

# ====== KIS 토큰 캐시 (24h) ======
TOKEN_CACHE_PATH <- "~/.kis_token_main.json"
get_cached_token <- function(apiConfig, account){
  ## ISSUE-3 FIX: 계정/환경별 토큰 캐시 일치 여부 확인
  cache_file <- path.expand(TOKEN_CACHE_PATH)
  current_api_url <- as.character(apiConfig$url)
  current_app_key <- as.character(account$appkey)
  current_acc_no <- as.character(account$accNo)
  if(file.exists(cache_file)){
    cached <- tryCatch(fromJSON(cache_file), error=function(e) NULL)
    cache_matches <- !is.null(cached) &&
      identical(as.character(cached$api_url), current_api_url) &&
      identical(as.character(cached$app_key), current_app_key) &&
      identical(as.character(cached$acc_no), current_acc_no)
    cache_valid <- cache_matches &&
      !is.null(cached$expires_at) &&
      cached$expires_at > as.numeric(Sys.time()) + 60
    if(cache_valid){
      Sys.chmod(cache_file, mode="0600")
      return(cached$access_token)
    }
  }
  tk <- getToken(apiConfig, account)
  write(toJSON(list(
    access_token=tk,
    expires_at=as.numeric(Sys.time()) + 23*3600,
    api_url=current_api_url,
    app_key=current_app_key,
    acc_no=current_acc_no
  ), auto_unbox=T), cache_file)
  Sys.chmod(cache_file, mode="0600")
  return(tk)
}

# ====== KIS 토큰/시장 체크 ======
config<-fromJSON("~/config.json")
apiConfig<-config$api$config$prod
account<-config$api$account$prod$main

token<-get_cached_token(apiConfig,account)
if(!DRY_RUN){
  if(isKoreanTradeOpen(token,apiConfig,account,today)=="N") stop("Market closed")
  cancelResult<-cancelAllOrders(apiConfig,account,token)
  for(res in cancelResult) sendMessage(res)
}

# ====== 잔고 조회 ======
currentBalance<-getBalancesheet(token,apiConfig,account)
if(currentBalance$status_code!='200'){
  stop("Fail to get current balance. Stop script")
}

if(nrow(currentBalance$sheet)>0){
  cur <- currentBalance$sheet[, .(
    code=pdno, name=prdt_name,
    qty=as.numeric(hldg_qty),
    eval_amt=as.numeric(evlu_amt),
    cur_price=as.numeric(prpr)
  )]
} else {
  cur <- data.table(code=character(), name=character(), qty=numeric(), eval_amt=numeric(), cur_price=numeric())
}

## DRY RUN 시 가상 SOFR 보유 + cash 부족 시나리오 주입 (2~4차 매도 sim 발동용)
if(DRY_RUN && ROUND_NO %in% c(2,3,4) && nrow(cur[code==SOFR_CODE])==0){
  sim_sofr_qty <- 5000
  sim_sofr_price <- 11500
  cur <- rbind(cur, data.table(
    code=SOFR_CODE, name=SOFR_NAME,
    qty=sim_sofr_qty,
    eval_amt=sim_sofr_qty*sim_sofr_price,
    cur_price=sim_sofr_price
  ))
  cat("[DRY RUN sim] 가상 SOFR ", sim_sofr_qty, "주 (", format(sim_sofr_qty*sim_sofr_price, big.mark=","), "원) 잔고 주입\n", sep="")
}

# ====== RSI 14일 계산 (네이버 200일 종가) ======
calc_rsi <- function(closes, n=14){
  if(length(closes) < n+1) return(NA_real_)
  diffs <- diff(closes)
  gains <- pmax(diffs, 0)
  losses <- pmax(-diffs, 0)
  ag <- mean(tail(gains, n))
  al <- mean(tail(losses, n))
  if(al == 0) return(100)
  rs <- ag / al
  return(round(100 - 100/(1+rs), 1))
}

LOCKED[, rsi := NA_real_]
LOCKED[, cur_price := NA_real_]
for(i in 1:nrow(LOCKED)){
  c <- LOCKED[i, code]
  prices <- tryCatch(adjustedPriceFromNaver('day', 200, c), error=function(e) NULL)
  if(is.null(prices) || nrow(prices)==0){
    LOCKED[i, cur_price := getCurrentPrice(apiConfig,account,token,c)]
    next
  }
  closes <- as.numeric(prices[,1])
  LOCKED[i, cur_price := tail(closes, 1)]
  LOCKED[i, rsi := calc_rsi(closes, 14)]
}

# ====== RSI 룰3 (보유 보너스/벌점 + 위성 가드) ======
rsi_ratio <- function(rsi, tier, held){
  if(is.na(rsi)) return(0.5)
  # 위성: RSI 70 이상 진입 금지
  if(tier == "sat"){
    if(rsi >= 70) return(0)
    if(rsi >= 65) return(0.75)
    return(1.0)
  }
  # 코어 + 보유: RSI 75 이상 진입 금지 (평단 끌어올림 방지)
  if(held && rsi >= 75) return(0)
  # 코어 신규 / 보유 RSI<75: 일반 룰
  if(rsi < 65) return(1.0)
  if(rsi < 75) return(0.75)
  if(rsi < 85) return(0.5)
  if(rsi < 90) return(0.25)
  return(0)
}
LOCKED[, ratio := mapply(rsi_ratio, rsi, tier, held)]

# ====== 종목별 갭 (목표 - 현재 평가) ======
LOCKED[, held_qty := sapply(code, function(c){ p<-cur[code==c]; if(nrow(p)>0) p$qty else 0 })]
LOCKED[, held_amt := sapply(code, function(c){ p<-cur[code==c]; if(nrow(p)>0) p$eval_amt else 0 })]
LOCKED[, gap := pmax(0, target_amt - held_amt)]

# ====== 차수별 매수액 산출 ======
if(ROUND_NO == 4){
  ## ISSUE-1 FIX: 4차 강제집행도 ROUND_LIMIT 한도는 유지
  LOCKED[, raw_buy := gap]  # RSI 룰은 무시하되 한도 스케일은 적용
  total_raw <- sum(LOCKED$raw_buy)
  scale <- if(total_raw > ROUND_LIMIT) ROUND_LIMIT / total_raw else 1
  LOCKED[, buy_amt := raw_buy * scale]
  if(total_raw > ROUND_LIMIT && !DRY_RUN){
    sendMessage(paste0(
      "[경고] 4차 잔여 매수액이 차수 한도 초과: ",
      format(total_raw, big.mark=","), "원 > ",
      format(ROUND_LIMIT, big.mark=","), "원\n",
      "ROUND_LIMIT 내 비례 축소 적용. 잔여분은 추가 분할 집행 권고."
    ))
  }
} else {
  LOCKED[, raw_buy := gap * ratio]
  total_raw <- sum(LOCKED$raw_buy)
  scale <- if(total_raw > ROUND_LIMIT) ROUND_LIMIT / total_raw else 1
  LOCKED[, buy_amt := raw_buy * scale]
}

LOCKED[, qty_to_buy := floor(buy_amt / cur_price)]
LOCKED[, final_amt := qty_to_buy * cur_price]

# ====== 매수 시트 (orderStocks 호환: 보유수량 + 평가금액 + 목표금액) ======
buySheet <- LOCKED[qty_to_buy > 0, .(
  종목코드=code, 종목명=name,
  보유수량=held_qty,
  현재가=cur_price,
  평가금액=held_amt,
  목표금액=held_amt + final_amt,    # 매수 후 평가액
  주문구분="00"  # orderStock 내부에서 ORD_DVSN='00' 고정
)]

## ISSUE-2 FIX: 매도 체결 후 실제 주문가능현금 기준으로 매수 시트 비례 축소
get_buy_needed <- function(sheet){
  if(nrow(sheet)==0) return(0)
  return(sum(pmax(0, sheet$목표금액 - sheet$평가금액)))
}

normalize_cash_amount <- function(cash_avail){
  if(is.null(cash_avail) || length(cash_avail)==0 || is.na(cash_avail)) return(0)
  return(as.numeric(cash_avail))
}

## ISSUE-5 FIX: cash 조회 실패 fail-closed 헬퍼
safe_orderable_amount <- function(apiConfig, account, token, code){
  raw <- tryCatch(getOrderableAmount(apiConfig, account, token, code),
                   error=function(e) NULL)
  if(is.null(raw) || length(raw)==0 || is.na(raw[1])){
    return(list(ok=FALSE, value=NA_real_))
  }
  return(list(ok=TRUE, value=as.numeric(raw[1])))
}

## ISSUE-6 FIX: orderStocks 내부 cash 재조회 우회 — 사전 검증된 cash budget으로 매수 dispatch
## (orderStocks는 매도용 유지, 인프라 미수정 — ISA 호환성)
## ISSUE-7 FIX: delta 계산을 평가금액 기준으로 변경 (price*cur_qty와 평가금액 괴리 방지)
##              remaining 초기화 = min(validated_cash, get_buy_needed) — 계획 budget 초과 금지
safe_buy_dispatch <- function(token, apiConfig, account, sheet, validated_cash){
  if(is.null(sheet) || nrow(sheet)==0) return(NULL)
  if(is.null(validated_cash) || length(validated_cash)==0 ||
     !is.finite(validated_cash) || validated_cash <= 0){
    sendMessage("⚠️ safe_buy_dispatch: validated_cash 미확인 — 매수 발송 abort")
    return(NULL)
  }
  planned_total <- get_buy_needed(sheet)
  res <- NULL
  remaining <- min(as.numeric(validated_cash), planned_total)  # 계획 초과 매수 금지
  total_submitted <- 0
  for(i in 1:nrow(sheet)){
    code <- sheet[i,]$종목코드
    price <- as.numeric(sheet[i,]$현재가)
    eval_amt <- as.numeric(sheet[i,]$평가금액)
    target_amt <- as.numeric(sheet[i,]$목표금액)
    if(!is.finite(price) || price <= 0){
      sendMessage(paste0("⚠️ safe_buy_dispatch ", code, ": 가격 비정상, skip")); next
    }
    # delta = 평가금액 기준 (planning과 동일 산식)
    delta <- target_amt - eval_amt
    if(delta <= 0){ next }
    avail <- min(remaining, delta)
    qty <- floor(avail / price)
    if(qty <= 0){
      print(paste0(code,": qty 0 (cash 또는 계획 budget 소진")); next
    }
    submitted <- qty * price
    if(total_submitted + submitted > planned_total){
      sendMessage(paste0("⚠️ safe_buy_dispatch ", code, ": 계획 budget 초과, skip"))
      next
    }
    print(paste("[safe_buy] code:",code," qty:",qty," price:",price," ordersum:",submitted))
    r <- orderStock(apiConfig, account, token, code, qty, price)
    r$idx <- i
    res <- rbind(res, as.data.table(r))
    remaining <- remaining - submitted
    total_submitted <- total_submitted + submitted
    Sys.sleep(0.1)
  }
  return(res)
}

scale_buy_sheet_to_cash <- function(sheet, cash_avail){
  buy_needed <- get_buy_needed(sheet)
  if(nrow(sheet)==0 || buy_needed <= 0) return(sheet)
  cash_avail <- normalize_cash_amount(cash_avail)
  if(cash_avail >= buy_needed) return(sheet)

  scale <- max(0, cash_avail / buy_needed)
  if(!DRY_RUN){
    sendMessage(paste0(
      "[경고] 매수 가능 현금 부족: 필요 ",
      format(round(buy_needed), big.mark=","), "원 / 가능 ",
      format(round(cash_avail), big.mark=","), "원\n",
      "buySheet를 가용 현금 내로 비례 축소합니다."
    ))
  }
  sheet[, 목표금액 := 평가금액 + (목표금액 - 평가금액) * scale]
  sheet <- sheet[목표금액 > 평가금액]
  return(sheet)
}

# ====== 매도 시트 ======
sellSheet <- data.table(종목코드=character(), 종목명=character(), 보유수량=numeric(),
                        현재가=numeric(), 평가금액=numeric(), 목표금액=numeric(), 주문구분=character())

# 1차 한정: 잠금 외 전량 매도
if(ROUND_NO == 1){
  for(c in NON_LOCKED_SELL){
    p <- cur[code==c]
    if(nrow(p)>0 && p$qty>0){
      cp <- if(!is.na(p$cur_price) && p$cur_price>0) p$cur_price else getCurrentPrice(apiConfig,account,token,c)
      sellSheet <- rbind(sellSheet, data.table(
        종목코드=c, 종목명=p$name,
        보유수량=p$qty,
        현재가=cp,
        평가금액=p$eval_amt,
        목표금액=0,         # 전량 매도
        주문구분="00"
      ))
    }
  }
}

# 2~4차: 매수 자금 부족 시 SOFR 부분 매도
## ISSUE-5 FIX: cash 조회 실패 시 SOFR 매도 결정 보류 (fail-closed)
if(ROUND_NO %in% c(2,3,4)){
  if(DRY_RUN){
    cash_avail <- 0  # SOFR 매도 sim 발동을 위해 cash 0 가정
    cat("[DRY RUN sim] cash_avail = 0 가정 (SOFR 매도 sim 발동용)\n")
    cash_ok <- TRUE
  } else {
    cash_res <- safe_orderable_amount(apiConfig, account, token, LOCKED[1,code])
    if(!cash_res$ok){
      cash_ok <- FALSE
      sendMessage(paste0(
        "⚠️ 차수 ",ROUND_NO," SOFR 매도 결정용 cash 조회 실패 — SOFR 매도 보류, 후처리 단계에서 재시도"
      ))
    } else {
      cash_ok <- TRUE
      cash_avail <- cash_res$value
    }
  }
  if(cash_ok){
    total_buy_needed <- get_buy_needed(buySheet)
    shortfall <- total_buy_needed - cash_avail
    if(shortfall > 0){
      sofr <- cur[code==SOFR_CODE]
      if(nrow(sofr)>0 && sofr$qty>0){
        sofr_price <- if(!is.na(sofr$cur_price) && sofr$cur_price>0) sofr$cur_price else getCurrentPrice(apiConfig,account,token,SOFR_CODE)
        sofr_remaining <- max(0, sofr$eval_amt - shortfall - 100000)
        sellSheet <- rbind(sellSheet, data.table(
          종목코드=SOFR_CODE, 종목명=SOFR_NAME,
          보유수량=sofr$qty,
          현재가=sofr_price,
          평가금액=sofr$eval_amt,
          목표금액=sofr_remaining,
          주문구분="00"
        ))
        if(!DRY_RUN){
          sendMessage(paste0(
            "매수자금 부족으로 SOFR 매도 예정: 부족 ",
            format(round(shortfall), big.mark=","), "원"
          ))
        }
      } else if(!DRY_RUN){
        sendMessage(paste0(
          "[경고] 매수자금 부족이나 SOFR 보유 수량 없음: 부족 ",
          format(round(shortfall), big.mark=","), "원. 매도 후 현금 확인 단계에서 매수 축소 예정."
        ))
      }
    }
  }
}

# ====== 차수 완료 조기 종료 (이전 시간대에 모두 체결된 경우) ======
## ISSUE-4 FIX: 11시 매수 전부 체결되면 13/15시 재실행 시 quit()
## ISSUE-5 FIX: cash 조회 실패 시 fail-closed (quit X, 정상 흐름 진행)
if(!DRY_RUN && nrow(buySheet) == 0 && nrow(sellSheet) == 0){
  cash_lookup_ok <- TRUE
  cash_check <- 0
  if(ROUND_NO == 1){
    cash_res <- safe_orderable_amount(apiConfig, account, token, SOFR_CODE)
    if(!cash_res$ok){
      cash_lookup_ok <- FALSE
      sendMessage(paste0("⚠️ 차수 ",ROUND_NO," 조기종료 판단용 cash 조회 실패 — quit 보류, SOFR 매수 단계 정상 진행"))
    } else {
      cash_check <- cash_res$value
    }
  }
  needs_sofr_buy <- (ROUND_NO == 1) && (!cash_lookup_ok || cash_check > 100000)
  if(cash_lookup_ok && !needs_sofr_buy){
    cat("[",today,"] 차수 ",ROUND_NO," 매수/매도/SOFR 모두 완료. Skip.\n", sep="")
    if(hour(Sys.time())==11){
      sendMessage(paste0("차수 ",ROUND_NO," — 매수/매도 사전 완료, 실행 없음"))
    }
    quit()
  }
}

# ====== 텔레그램 요약 (11시에만) ======
if(!DRY_RUN && hour(Sys.time())==11){
  msg <- paste0("[메인 분할매수 ",ROUND_NO,"차 / ",today,"]\n")
  msg <- paste0(msg, "잠금 8종 RSI/매수액\n")
  for(i in 1:nrow(LOCKED)){
    r <- LOCKED[i]
    msg <- paste0(msg,
      sprintf("  %s(%s) RSI %s %.0f%% qty %d (%s)\n",
        r$name, r$tier, ifelse(is.na(r$rsi),"-",as.character(r$rsi)),
        r$ratio*100, r$qty_to_buy, format(r$final_amt, big.mark=","))
    )
  }
  msg <- paste0(msg, "\n매수 합계: ", format(sum(LOCKED$final_amt), big.mark=","), "원")
  if(nrow(sellSheet)>0){
    msg <- paste0(msg, "\n매도: ", paste(sellSheet$종목명, collapse=", "))
  }
  sendMessage(msg)
}

# ====== DRY_RUN 출력 (orderStocks 시뮬 포함) ======
## DRY RUN 시 orderStocks 함수 로직 시뮬:
##   매수: priceSum = 목표금액 - price*curQty; qty = floor(priceSum/price)  → 양수
##   매도: priceSum = 목표금액 - price*curQty; qty = floor(priceSum/price)  → 음수
if(DRY_RUN){
  cat("\n========== DRY RUN ==========\n")
  cat("Round:", ROUND_NO, " Date:", today, "\n\n")
  cat("--- LOCKED ---\n"); print(LOCKED[, .(code,name,tier,held,rsi,ratio,cur_price,held_qty,held_amt,gap,buy_amt,qty_to_buy,final_amt)])

  cat("\n--- buySheet (orderStocks 시뮬) ---\n")
  if(nrow(buySheet)>0){
    bs <- copy(buySheet)
    bs[, sim_qty := floor((목표금액 - 현재가*보유수량)/현재가)]
    bs[, sim_amt := sim_qty * 현재가]
    print(bs[, .(종목코드,종목명,보유수량,현재가,평가금액,목표금액,sim_qty,sim_amt)])
    cat("매수 시뮬 합계:", format(sum(bs$sim_amt), big.mark=","), "원\n")
  } else cat("(empty)\n")

  cat("\n--- sellSheet (orderStocks 시뮬) ---\n")
  if(nrow(sellSheet)>0){
    ss <- copy(sellSheet)
    ss[, sim_qty := floor((목표금액 - 현재가*보유수량)/현재가)]   # 음수 = 매도
    ss[, sim_amt := sim_qty * 현재가]
    print(ss[, .(종목코드,종목명,보유수량,현재가,평가금액,목표금액,sim_qty,sim_amt)])
    cat("매도 시뮬 합계:", format(sum(abs(ss$sim_amt)), big.mark=","), "원 회수\n")
  } else cat("(empty)\n")

  cat("\n--- 자금 흐름 시뮬 ---\n")
  buy_total <- if(exists("bs") && nrow(bs)>0) sum(bs$sim_amt) else 0
  sell_total <- if(exists("ss") && nrow(ss)>0) sum(abs(ss$sim_amt)) else 0
  cat("매수 시뮬 합계 (실제 발송 예정):", format(buy_total, big.mark=","), "원\n")
  cat("매도 시뮬 합계 (실제 회수 예정):", format(sell_total, big.mark=","), "원\n")
  cat("순 자금 필요   :", format(buy_total - sell_total, big.mark=","), "원 (양수=현금/SOFR 차감, 음수=잔여)\n")
  quit()
}

# ====== 매도 → 매수 (ISA 패턴) ======
if(nrow(sellSheet)>0){
  sellRes <- orderStocks(token,apiConfig,account,sellSheet)
  if(length(sellRes)>0){
    sendMessage("Sell orders")
    for(i in 1:nrow(sellRes)){
      row<-sellRes[i,]
      text<-paste0("rt_cd: ",row$rt_cd," msg: ",row$msg1," code: ",row$code," qty: ",row$qty," price: ",row$price)
      sendMessage(text,0)
      Sys.sleep(0.04)
    }
    ## ISSUE-2 FIX: SOFR/잠금 외 매도 발송 후 현금 재조회 전 대기
    sendMessage("매도 주문 후 매수 가능 현금 확인을 위해 30초 대기합니다.")
    Sys.sleep(30)
  }
}

## ISSUE-2 FIX: 매도 실패/부분체결/SOFR 부족 가능성을 반영해 buySheet 최종 조정
## ISSUE-5 FIX: 매도 후 cash 조회 실패 시 buySheet 발송 abort (fail-closed)
if(nrow(buySheet)>0){
  cash_res <- safe_orderable_amount(apiConfig, account, token, buySheet[1,종목코드])
  if(!cash_res$ok){
    sendMessage("⚠️ [중대] 매도 후 cash 재조회 실패 — buySheet 발송 abort. 수동 재조정 필요.")
    buySheet <- buySheet[0]  # buy 단계 스킵
  } else {
    cash_avail_after_sell <- cash_res$value
    if(!DRY_RUN){
      sendMessage(paste0(
        "매수 전 주문가능현금 확인: ",
        format(round(cash_avail_after_sell), big.mark=","),
        "원"
      ))
    }
    buySheet <- scale_buy_sheet_to_cash(buySheet, cash_avail_after_sell)
  }
}

## ISSUE-6 FIX: orderStocks 대신 safe_buy_dispatch 사용 — cash NULL 시 발송 막음
if(nrow(buySheet)>0){
  buyRes <- safe_buy_dispatch(token, apiConfig, account, buySheet, cash_avail_after_sell)
  if(!is.null(buyRes) && nrow(buyRes)>0){
    sendMessage("Buy orders")
    for(i in 1:nrow(buyRes)){
      row<-buyRes[i,]
      text<-paste0("rt_cd: ",row$rt_cd," msg: ",row$msg1," code: ",row$code," qty: ",row$qty," price: ",row$price)
      sendMessage(text,0)
      Sys.sleep(0.04)
    }
  }
}

# ====== 1차 마무리: 잔여 자금 SOFR 매수 ======
## ISSUE-5 FIX: cash 조회 실패 시 SOFR 매수 스킵 + 텔레그램 경고 (fail-closed)
if(ROUND_NO == 1){
  Sys.sleep(60)
  cash_res <- safe_orderable_amount(apiConfig, account, token, SOFR_CODE)
  if(!cash_res$ok){
    sendMessage("⚠️ 1차 SOFR 매수 단계 cash 조회 실패 — SOFR 매수 스킵 (수동 확인 필요)")
  } else if(cash_res$value > 100000){
    cash_after <- cash_res$value
    sofr_price <- getCurrentPrice(apiConfig,account,token,SOFR_CODE)
    if(is.null(sofr_price) || length(sofr_price)==0 || is.na(sofr_price[1]) || sofr_price[1]<=0){
      sendMessage("⚠️ 1차 SOFR 매수 단계 시세 조회 실패 — SOFR 매수 스킵")
    } else {
      sofr_price <- as.numeric(sofr_price[1])
      sofr_buy_qty <- floor(cash_after / sofr_price)
      if(sofr_buy_qty > 0){
        sofr_pos <- cur[code==SOFR_CODE]
        sofr_held_qty <- if(nrow(sofr_pos)>0) sofr_pos$qty else 0
        sofr_held_amt <- if(nrow(sofr_pos)>0) sofr_pos$eval_amt else 0
        sofrSheet <- data.table(
          종목코드=SOFR_CODE, 종목명=SOFR_NAME,
          보유수량=sofr_held_qty,
          현재가=sofr_price,
          평가금액=sofr_held_amt,
          목표금액=sofr_held_amt + sofr_buy_qty * sofr_price,
          주문구분="00"
        )
        ## ISSUE-6 FIX: safe_buy_dispatch로 cash 검증 강제
        sofrRes <- safe_buy_dispatch(token, apiConfig, account, sofrSheet, cash_after)
        if(!is.null(sofrRes) && nrow(sofrRes)>0){
          sendMessage(paste0("SOFR 매수 ",sofr_buy_qty,"주 (",format(sofr_buy_qty*sofr_price, big.mark=","),"원)"))
        }
      }
    }
  }
}

# 토큰은 캐시 활용을 위해 폐기하지 않음
