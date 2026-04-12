#!/usr/bin/env Rscript
# screening_pipeline.R
# 종목 스크리닝 파이프라인 (정량)
# - 대형(상위300): 전부 포함 + 스코어 참고용
# - 중소형(301+): 하드필터 + 스코어 경쟁 → 상위 30
# Usage: Rscript screening_pipeline.R [output_path]

library(RPostgres)
library(DBI)
library(jsonlite)
library(data.table)

# ============================================================
# 설정
# ============================================================
AUTO_INCLUDE_CUTOFF <- 300    # 시총 상위 N위까지 자동 포함
SMALL_SLOTS <- 30             # 중소형 스코어 경쟁 슬롯

# 소형주 하드필터 버퍼
KOSDAQ_REV_BUFFER <- 6e9      # KOSDAQ 매출 60억
KOSPI_REV_BUFFER  <- 1e10     # KOSPI 매출 100억
LOSS_YEAR_THRESHOLD <- 2      # 3년 중 2년 영업적자 → 제외
MARGINAL_OPM <- 0.02          # 의심 흑자전환 OPM 2%

CAGR_YEARS <- 3               # 성장률 계산 기간
ONETIME_RATIO <- 2.0           # 일회성 이익 의심 기준 (당기순이익/영업이익)

# 금융지주 코드 (기타금융 중 실제 금융지주만)
FINANCIAL_HOLDING_CODES <- c(
  "055550","086790","138040","071050","175330",
  "138930","139130","402340"
)

args <- commandArgs(trailingOnly = TRUE)
output_path <- if (length(args) > 0) args[1] else "screening_result.json"

log_step <- function(step, msg, ...) {
  cat(sprintf("[%s] %s\n", step, sprintf(msg, ...)))
}

to_sql_in <- function(codes) {
  paste(sprintf("'%s'", codes), collapse = ",")
}

query_loss_years <- function(conn, codes, since_year) {
  tryCatch(
    as.data.table(dbGetQuery(conn, sprintf("
      SELECT 종목코드,
        SUM(CASE WHEN 값 < 0 THEN 1 ELSE 0 END) as loss_years
      FROM metainfo.연간재무제표
      WHERE 종목코드 IN (%s)
        AND 연결구분 = '연결' AND 계정 = '영업이익'
        AND 일자 >= '%d.12'
      GROUP BY 종목코드
    ", to_sql_in(codes), since_year))),
    error = function(e) {
      log_step("경고", "영업적자 이력 조회 실패: %s (종목수: %d, 기준연도: %d)",
               conditionMessage(e), length(codes), since_year)
      data.table(종목코드 = character(), loss_years = integer())
    })
}

# ============================================================
# DB 접속
# ============================================================
config <- tryCatch(
  read_json("~/config.json"),
  error = function(e) {
    log_step("에러", "config.json 로드 실패: %s (경로: %s)", conditionMessage(e), path.expand("~/config.json"))
    stop("config.json을 읽을 수 없습니다. ~/config.json 파일을 확인하세요.")
  })
dbConfig <- config$database

conn <- tryCatch(
  dbConnect(RPostgres::Postgres(),
            dbname = dbConfig$database,
            host   = dbConfig$host,
            port   = dbConfig$port,
            user   = dbConfig$user,
            password = dbConfig$passwd),
  error = function(e) {
    log_step("에러", "DB 접속 실패: %s (host=%s, port=%s)",
             conditionMessage(e), dbConfig$host, dbConfig$port)
    stop(sprintf("DB 접속 실패. host=%s port=%s를 확인하세요.",
                 dbConfig$host, dbConfig$port))
  })
on.exit(dbDisconnect(conn), add = TRUE)

latest_date <- tryCatch(
  dbGetQuery(conn, "SELECT MAX(일자) FROM metainfo.월별기업정보")[[1]],
  error = function(e) {
    log_step("에러", "최신일자 조회 실패: %s (테이블: metainfo.월별기업정보)", conditionMessage(e))
    stop("월별기업정보 테이블 조회 실패. DB 상태를 확인하세요.")
  })
if (is.na(latest_date) || is.null(latest_date)) {
  stop("월별기업정보 테이블이 비어있습니다. InsertCorpData.R 실행이 필요합니다.")
}
log_step("DB", "접속 완료. 최신일자: %s", latest_date)

# ============================================================
# 1. 데이터 로드
# ============================================================
raw <- tryCatch(
  as.data.table(dbGetQuery(conn, sprintf("
    SELECT 종목코드, 종목명, 시장구분, 산업분류, 시가총액,
      관리여부, 자본, 부채, 매출액, 영업이익,
      지배주주순이익, 당기순이익, 배당수익률,
      영업활동으로인한현금흐름, 잉여현금흐름, 유상증자,
      자산, 유동자산, 유동부채, 매출총이익
    FROM metainfo.월별기업정보
    WHERE 일자 = '%s'
  ", latest_date))),
  error = function(e) {
    log_step("에러", "월별기업정보 로드 실패: %s (일자: %s)", conditionMessage(e), latest_date)
    stop("월별기업정보 데이터 로드에 실패했습니다.")
  })
log_step("로드", "전체 종목: %d개", nrow(raw))

# ============================================================
# 2. 공통 하드필터 (이상한 기업만 제거)
# ============================================================
n_before_admin <- nrow(raw)
dt <- raw[is.na(관리여부) | 관리여부 != "관리종목"]
log_step("필터", "관리종목 제외: %d → %d (-%d)", n_before_admin, nrow(dt), n_before_admin - nrow(dt))

n_before_capital <- nrow(dt)
dt <- dt[!is.na(자본) & 자본 > 0]
log_step("필터", "자본잠식 제외: %d → %d (-%d)", n_before_capital, nrow(dt), n_before_capital - nrow(dt))

# ============================================================
# 3. 시총 순위 → 대형/중소형 분리
# ============================================================
dt[, mkt_rank := frankv(시가총액, order = -1L, ties.method = "min")]
large <- dt[mkt_rank <= AUTO_INCLUDE_CUTOFF]
small <- dt[mkt_rank > AUTO_INCLUDE_CUTOFF]
log_step("분리", "대형(상위 %d위): %d개 | 중소형: %d개",
         AUTO_INCLUDE_CUTOFF, nrow(large), nrow(small))

# ============================================================
# 4. 중소형 하드필터 (보수적, 버퍼 적용)
# ============================================================
current_year <- as.integer(format(Sys.Date(), "%Y"))
n_start <- nrow(small)

# 4a. 매출 버퍼
small <- small[
  (시장구분 == "KOSDAQ" & !is.na(매출액) & 매출액 >= KOSDAQ_REV_BUFFER) |
  (시장구분 != "KOSDAQ" & !is.na(매출액) & 매출액 >= KOSPI_REV_BUFFER)
]
log_step("소형", "매출 버퍼: %d → %d", n_start, nrow(small))

# 4b. 영업적자 이력
if (nrow(small) > 0) {
  n_before_loss <- nrow(small)
  loss_check <- query_loss_years(conn, small$종목코드, current_year - CAGR_YEARS)

  exclude <- loss_check[loss_years >= LOSS_YEAR_THRESHOLD]$종목코드
  small <- small[!종목코드 %in% exclude]
  log_step("소형", "영업적자 이력: %d → %d", n_before_loss, nrow(small))
}

# 4c. 의심 흑자전환
if (nrow(small) > 0) {
  n_before_marginal <- nrow(small)
  marginal <- small[!is.na(영업이익) & !is.na(매출액) & 매출액 > 0 &
                    영업이익 > 0 & (영업이익 / 매출액) < MARGINAL_OPM]
  if (nrow(marginal) > 0) {
    m_loss <- query_loss_years(conn, marginal$종목코드, current_year - CAGR_YEARS)
    small <- small[!종목코드 %in% m_loss[loss_years >= CAGR_YEARS]$종목코드]
  }
  log_step("소형", "의심 흑자전환: %d → %d", n_before_marginal, nrow(small))
}

# 4d. 적자 + 유상증자
if (nrow(small) > 0) {
  n_before_dilution <- nrow(small)
  cur_dilution <- small[!is.na(유상증자) & 유상증자 > 0 &
                        !is.na(당기순이익) & 당기순이익 < 0]$종목코드
  codes_sql <- to_sql_in(small$종목코드)
  prev_dilution <- tryCatch({
    as.data.table(dbGetQuery(conn, sprintf("
      SELECT DISTINCT 종목코드 FROM metainfo.월별기업정보
      WHERE 종목코드 IN (%s)
        AND 일자 >= '%s'::date - INTERVAL '2 years' AND 일자 < '%s'
        AND 유상증자 > 0 AND 당기순이익 < 0
    ", codes_sql, latest_date, latest_date)))$종목코드
  }, error = function(e) {
    log_step("경고", "적자+유상증자 이력 조회 실패: %s (종목수: %d, 기준일: %s)", conditionMessage(e), nrow(small), latest_date)
    character(0)
  })
  small <- small[!종목코드 %in% unique(c(cur_dilution, prev_dilution))]
  log_step("소형", "적자+유상증자: %d → %d", n_before_dilution, nrow(small))
}

log_step("소형", "최종: %d / %d 통과 (탈락률 %.0f%%)",
         nrow(small), n_start, (1 - nrow(small) / max(n_start, 1)) * 100)

# ============================================================
# 5. 전체 합치기 + 금융 구분
# ============================================================
filtered <- rbind(large, small)
filtered[, is_large := mkt_rank <= AUTO_INCLUDE_CUTOFF]
filtered[, is_financial :=
  grepl("보험|증권|은행", 산업분류) |
  (산업분류 == "기타금융" & 종목코드 %in% FINANCIAL_HOLDING_CODES)]

log_step("합산", "필터 통과: %d개 (대형 %d + 중소형 %d, 금융 %d개)",
         nrow(filtered), sum(filtered$is_large), sum(!filtered$is_large),
         sum(filtered$is_financial))

# ============================================================
# 6. 성장 데이터 로드 (매출 CAGR + ROE/OPM delta)
# ============================================================
all_codes_sql <- to_sql_in(filtered$종목코드)
start_year <- current_year - CAGR_YEARS

growth_raw <- tryCatch(
  as.data.table(dbGetQuery(conn, sprintf("
    SELECT 종목코드, 종류, 계정, 일자, 값
    FROM metainfo.연간재무제표
    WHERE 종목코드 IN (%s)
      AND 연결구분 = '연결'
      AND ((종류 = '포괄손익계산서' AND 계정 IN ('매출액', '영업이익', '지배주주순이익'))
        OR (종류 = '재무상태표' AND 계정 = '자본'))
      AND 일자 >= '%d.12'
    ORDER BY 종목코드, 계정, 일자
  ", all_codes_sql, start_year))),
  error = function(e) {
    log_step("경고", "성장 데이터 로드 실패: %s (종목수: %d, 기간: %d~%d)", conditionMessage(e), nrow(filtered), start_year, current_year)
    data.table(종목코드 = character(), 종류 = character(),
               계정 = character(), 일자 = character(), 값 = numeric())
  })

calc_cagr <- function(values, years) {
  if (length(values) < 2 || any(is.na(values))) return(NA_real_)
  v_start <- values[1]; v_end <- values[length(values)]
  if (v_start <= 0 || v_end <= 0) return(NA_real_)
  return((v_end / v_start)^(1 / years) - 1)
}

growth_metrics <- growth_raw[, {
  rev <- .SD[계정 == "매출액"][order(일자)]$값
  oi  <- .SD[계정 == "영업이익"][order(일자)]$값
  ni  <- .SD[계정 == "지배주주순이익"][order(일자)]$값
  eq  <- .SD[계정 == "자본"][order(일자)]$값
  n_years <- max(length(rev) - 1, 1)

  rev_cagr_val <- calc_cagr(rev, n_years)

  roe_delta_val <- NA_real_
  if (length(ni) >= 2 && length(eq) >= 2 &&
      !is.na(eq[1]) && eq[1] > 0 && !is.na(eq[length(eq)]) && eq[length(eq)] > 0) {
    roe_delta_val <- (ni[length(ni)] / eq[length(eq)] - ni[1] / eq[1]) * 100
  }

  opm_delta_val <- NA_real_
  if (length(oi) >= 2 && length(rev) >= 2 &&
      !is.na(rev[1]) && rev[1] > 0 && !is.na(rev[length(rev)]) && rev[length(rev)] > 0) {
    opm_delta_val <- (oi[length(oi)] / rev[length(rev)] - oi[1] / rev[1]) * 100
  }

  list(rev_cagr = rev_cagr_val, roe_delta = roe_delta_val, opm_delta = opm_delta_val)
}, by = 종목코드]

filtered <- merge(filtered, growth_metrics, by = "종목코드", all.x = TRUE)
log_step("성장", "매출CAGR + ROE/OPM delta 계산: %d종목", nrow(growth_metrics))

# ============================================================
# 7. 기본 지표 계산
# ============================================================
# 7a. 일회성 이익 플래그 — 지배주주순이익이 영업이익의 ONETIME_RATIO배 초과 시 의심

filtered[, onetime_flag := {
  has_oi <- !is.na(영업이익)
  has_ni <- !is.na(지배주주순이익)
  fifelse(
    has_oi & has_ni & 영업이익 <= 0 & 지배주주순이익 > 0, TRUE,
    fifelse(
      has_oi & has_ni & 영업이익 > 0 & 지배주주순이익 > 영업이익 * ONETIME_RATIO, TRUE,
      FALSE))
}]

n_flagged <- sum(filtered$onetime_flag, na.rm = TRUE)
log_step("지표", "일회성 이익 의심 플래그: %d개", n_flagged)

# 7b. 지표 산출
filtered[, `:=`(
  ROE  = fifelse(자본 > 0, 지배주주순이익 / 자본 * 100, NA_real_),
  PER  = fifelse(!is.na(지배주주순이익) & 지배주주순이익 > 0,
                 시가총액 / 지배주주순이익, NA_real_),
  PBR  = fifelse(자본 > 0, 시가총액 / 자본, NA_real_),
  PCR  = fifelse(!is.na(잉여현금흐름) & 잉여현금흐름 > 0,
                 시가총액 / 잉여현금흐름, NA_real_),
  OPM  = fifelse(!is.na(매출액) & 매출액 > 0, 영업이익 / 매출액 * 100, NA_real_),
  DEBT = fifelse(자본 > 0, 부채 / 자본 * 100, NA_real_),
  DIV  = 배당수익률,
  PEG  = fifelse(
    !is.na(지배주주순이익) & 지배주주순이익 > 0 & !is.na(rev_cagr) & rev_cagr > 0,
    (시가총액 / 지배주주순이익) / (rev_cagr * 100), NA_real_)
)]

# ============================================================
# 7c. 저PBR 보조지표 (value_gap + Piotroski F-Score)
# PBR < 1 종목에만 적용. score_value에 반영하지 않는 별도 플래그.
# ============================================================
low_pbr_codes <- filtered[!is.na(PBR) & PBR < 1.0]$종목코드

if (length(low_pbr_codes) > 0) {
  # value_gap = 이론PBR(ROE/10) - 실제PBR. 양수 = 저평가
  filtered[, value_gap := fifelse(!is.na(PBR) & PBR < 1.0 & !is.na(ROE),
                                  round(ROE / 10 - PBR, 2), NA_real_)]

  # Piotroski F-Score: 전년 데이터 조회
  prev_date <- tryCatch(
    dbGetQuery(conn, sprintf("
      SELECT MAX(일자) FROM metainfo.월별기업정보
      WHERE 일자 < '%s'::date - INTERVAL '10 months'
    ", latest_date))[[1]],
    error = function(e) { log_step("경고", "전년 데이터 조회 실패"); NA })

  if (!is.na(prev_date)) {
    prev_data <- tryCatch(
      as.data.table(dbGetQuery(conn, sprintf("
        SELECT 종목코드, 당기순이익, 영업활동으로인한현금흐름,
               자산, 부채, 자본, 유동자산, 유동부채,
               매출액, 매출총이익, 유상증자
        FROM metainfo.월별기업정보
        WHERE 일자 = '%s' AND 종목코드 IN (%s)
      ", prev_date, to_sql_in(low_pbr_codes)))),
      error = function(e) {
        log_step("경고", "F-Score 전년 데이터 로드 실패: %s", conditionMessage(e))
        data.table()
      })

    if (nrow(prev_data) > 0) {
      setnames(prev_data, setdiff(names(prev_data), "종목코드"),
               paste0(setdiff(names(prev_data), "종목코드"), "_prev"))
      filtered <- merge(filtered, prev_data, by = "종목코드", all.x = TRUE)

      filtered[종목코드 %in% low_pbr_codes, fscore := {
        # F1: 당기순이익 > 0
        f1 <- fifelse(!is.na(당기순이익) & 당기순이익 > 0, 1L, 0L)
        # F2: 영업CF > 0
        f2 <- fifelse(!is.na(영업활동으로인한현금흐름) & 영업활동으로인한현금흐름 > 0, 1L, 0L)
        # F3: ROA 개선 (YoY)
        roa_cur  <- fifelse(!is.na(자산) & 자산 > 0, 당기순이익 / 자산, NA_real_)
        roa_prev <- fifelse(!is.na(자산_prev) & 자산_prev > 0, 당기순이익_prev / 자산_prev, NA_real_)
        f3 <- fifelse(!is.na(roa_cur) & !is.na(roa_prev) & roa_cur > roa_prev, 1L, 0L)
        # F4: 영업CF > 당기순이익 (accrual quality)
        f4 <- fifelse(!is.na(영업활동으로인한현금흐름) & !is.na(당기순이익) &
                      영업활동으로인한현금흐름 > 당기순이익, 1L, 0L)
        # F5: 부채비율 감소 (YoY)
        dr_cur  <- fifelse(자본 > 0, 부채 / 자본, NA_real_)
        dr_prev <- fifelse(!is.na(자본_prev) & 자본_prev > 0, 부채_prev / 자본_prev, NA_real_)
        f5 <- fifelse(!is.na(dr_cur) & !is.na(dr_prev) & dr_cur < dr_prev, 1L, 0L)
        # F6: 유동비율 증가 (YoY)
        cr_cur  <- fifelse(!is.na(유동부채) & 유동부채 > 0, 유동자산 / 유동부채, NA_real_)
        cr_prev <- fifelse(!is.na(유동부채_prev) & 유동부채_prev > 0, 유동자산_prev / 유동부채_prev, NA_real_)
        f6 <- fifelse(!is.na(cr_cur) & !is.na(cr_prev) & cr_cur > cr_prev, 1L, 0L)
        # F7: 유상증자 없음
        f7 <- fifelse(is.na(유상증자) | 유상증자 == 0, 1L, 0L)
        # F8: 매출총이익률 개선 (YoY)
        gpm_cur  <- fifelse(!is.na(매출총이익) & !is.na(매출액) & 매출액 > 0, 매출총이익 / 매출액, NA_real_)
        gpm_prev <- fifelse(!is.na(매출총이익_prev) & !is.na(매출액_prev) & 매출액_prev > 0, 매출총이익_prev / 매출액_prev, NA_real_)
        f8 <- fifelse(!is.na(gpm_cur) & !is.na(gpm_prev) & gpm_cur > gpm_prev, 1L, 0L)
        # F9: 자산회전율 개선 (YoY)
        at_cur  <- fifelse(!is.na(매출액) & !is.na(자산) & 자산 > 0, 매출액 / 자산, NA_real_)
        at_prev <- fifelse(!is.na(매출액_prev) & !is.na(자산_prev) & 자산_prev > 0, 매출액_prev / 자산_prev, NA_real_)
        f9 <- fifelse(!is.na(at_cur) & !is.na(at_prev) & at_cur > at_prev, 1L, 0L)
        f1 + f2 + f3 + f4 + f5 + f6 + f7 + f8 + f9
      }]

      # cleanup prev columns
      prev_cols <- grep("_prev$", names(filtered), value = TRUE)
      filtered[, (prev_cols) := NULL]
    }
  }

  # value_label 판정
  filtered[, value_label := fifelse(
    is.na(value_gap), NA_character_,
    fifelse(value_gap > 0.5 & !is.na(fscore) & fscore >= 7, "TRUE_VALUE",
    fifelse(value_gap > 0.5 & !is.na(fscore) & fscore <= 3, "TRAP_RISK",
    fifelse(value_gap <= 0.5 & !is.na(fscore) & fscore >= 7, "MODERATE",
    fifelse(value_gap <= 0.5 & !is.na(fscore) & fscore <= 6, "TRAP_RISK",
    "MODERATE")))))]

  n_true <- sum(filtered$value_label == "TRUE_VALUE", na.rm = TRUE)
  n_mod  <- sum(filtered$value_label == "MODERATE", na.rm = TRUE)
  n_trap <- sum(filtered$value_label == "TRAP_RISK", na.rm = TRUE)
  log_step("저PBR", "value_gap + F-Score 계산: TRUE_VALUE %d, MODERATE %d, TRAP_RISK %d",
           n_true, n_mod, n_trap)
} else {
  filtered[, `:=`(value_gap = NA_real_, fscore = NA_integer_, value_label = NA_character_)]
  log_step("저PBR", "PBR < 1 종목 없음, 보조지표 스킵")
}

# ============================================================
# 헬퍼: z-score 기반 스코어 (0-10)
# - 업종 내 z-score 계산 후 pnorm()으로 0~10 변환
# - 소규모 업종(n < min_group_size)은 전체 시장 z-score로 fallback
# - 극단값은 1st/99th 백분위로 winsorize
# ============================================================
MIN_GROUP_SIZE <- 10

add_zscore <- function(dt, col, score_col, group_col = "산업분류",
                       higher_is_better = TRUE) {
  all_vals <- dt[[col]]
  n_total <- sum(!is.na(all_vals))
  if (n_total <= 2) {
    dt[, (score_col) := 5]
    return(invisible(dt))
  }

  q01 <- quantile(all_vals, 0.01, na.rm = TRUE)
  q99 <- quantile(all_vals, 0.99, na.rm = TRUE)
  w_all <- pmin(pmax(all_vals, q01), q99)
  global_mean <- mean(w_all, na.rm = TRUE)
  global_sd   <- sd(w_all, na.rm = TRUE)
  if (is.na(global_sd) || global_sd == 0) global_sd <- 1

  if (is.null(group_col)) {
    dt[, (score_col) := {
      vals <- get(col)
      w <- pmin(pmax(vals, q01), q99)
      z <- (w - global_mean) / global_sd
      if (!higher_is_better) z <- -z
      round(pnorm(z) * 10, 1)
    }]
  } else {
    dt[, (score_col) := {
      vals <- get(col)
      w <- pmin(pmax(vals, q01), q99)
      n_valid <- sum(!is.na(w))
      if (n_valid < MIN_GROUP_SIZE) {
        z <- (w - global_mean) / global_sd
      } else {
        m <- mean(w, na.rm = TRUE)
        s <- sd(w, na.rm = TRUE)
        if (is.na(s) || s == 0) {
          z <- (w - global_mean) / global_sd
        } else {
          z <- (w - m) / s
        }
      }
      if (!higher_is_better) z <- -z
      round(pnorm(z) * 10, 1)
    }, by = group_col]
  }

  invisible(dt)
}

# ============================================================
# 8. 가치 스코어 (score_value)
# ============================================================
# 금융은 별도 그룹핑 (PCR/OPM/DEBT 무의미)
non_fin <- filtered[is_financial == FALSE]
fin     <- filtered[is_financial == TRUE]

# 일반 기업: 업종 내 백분위
# 접미사: _vs = value score (가치 백분위), _gs = growth score (성장 백분위)
add_zscore(non_fin, "ROE",  "ROE_vs",  higher_is_better = TRUE)
add_zscore(non_fin, "PER",  "PER_vs",  higher_is_better = FALSE)
add_zscore(non_fin, "PBR",  "PBR_vs",  higher_is_better = FALSE)
add_zscore(non_fin, "PCR",  "PCR_vs",  higher_is_better = FALSE)
add_zscore(non_fin, "OPM",  "OPM_vs",  higher_is_better = TRUE)
add_zscore(non_fin, "DEBT", "DEBT_vs", higher_is_better = FALSE)
add_zscore(non_fin, "DIV",  "DIV_vs",  higher_is_better = TRUE)

non_fin[, score_value := {
  roe_wt  <- fifelse(is.na(ROE_vs),  0, 0.15)
  per_wt  <- fifelse(is.na(PER_vs),  0, 0.20)
  pbr_wt  <- fifelse(is.na(PBR_vs),  0, 0.15)
  pcr_wt  <- fifelse(is.na(PCR_vs),  0, 0.10)
  opm_wt  <- fifelse(is.na(OPM_vs),  0, 0.10)
  debt_wt <- fifelse(is.na(DEBT_vs), 0, 0.10)
  div_wt  <- fifelse(is.na(DIV_vs),  0, 0.20)
  base_wt <- roe_wt + per_wt + pbr_wt + pcr_wt + opm_wt + debt_wt + div_wt
  raw <- fifelse(is.na(ROE_vs),  0, ROE_vs*0.15) +
    fifelse(is.na(PER_vs),  0, PER_vs*0.20) +
    fifelse(is.na(PBR_vs),  0, PBR_vs*0.15) +
    fifelse(is.na(PCR_vs),  0, PCR_vs*0.10) +
    fifelse(is.na(OPM_vs),  0, OPM_vs*0.10) +
    fifelse(is.na(DEBT_vs), 0, DEBT_vs*0.10) +
    fifelse(is.na(DIV_vs),  0, DIV_vs*0.20)
  fifelse(base_wt > 0, round(raw / base_wt, 2), NA_real_)
}]

# 금융: 금융 전체에서 백분위 (PCR/OPM/DEBT 제외)
add_zscore(fin, "ROE", "ROE_vs", group_col = NULL, higher_is_better = TRUE)
add_zscore(fin, "PER", "PER_vs", group_col = NULL, higher_is_better = FALSE)
add_zscore(fin, "PBR", "PBR_vs", group_col = NULL, higher_is_better = FALSE)
add_zscore(fin, "DIV", "DIV_vs", group_col = NULL, higher_is_better = TRUE)
fin[, `:=`(PCR_vs = NA_real_, OPM_vs = NA_real_, DEBT_vs = NA_real_)]
fin[, score_value := {
  roe_wt <- fifelse(is.na(ROE_vs), 0, 0.30)
  per_wt <- fifelse(is.na(PER_vs), 0, 0.25)
  pbr_wt <- fifelse(is.na(PBR_vs), 0, 0.20)
  div_wt <- fifelse(is.na(DIV_vs), 0, 0.25)
  base_wt <- roe_wt + per_wt + pbr_wt + div_wt
  raw <- fifelse(is.na(ROE_vs), 0, ROE_vs*0.30) +
    fifelse(is.na(PER_vs), 0, PER_vs*0.25) +
    fifelse(is.na(PBR_vs), 0, PBR_vs*0.20) +
    fifelse(is.na(DIV_vs), 0, DIV_vs*0.25)
  fifelse(base_wt > 0, round(raw / base_wt, 2), NA_real_)
}]

filtered <- rbind(non_fin, fin, fill = TRUE)
log_step("가치", "score_value 계산 완료")

# ============================================================
# 9. 성장 스코어 (score_growth)
# ============================================================
# 시총 구간별 delta 백분위 (대형 vs 중소형)
filtered[, mkt_tier := fifelse(mkt_rank <= AUTO_INCLUDE_CUTOFF, "대형", "중소형")]

add_zscore(filtered, "ROE",       "ROE_gs",       higher_is_better = TRUE)
add_zscore(filtered, "OPM",       "OPM_gs",       higher_is_better = TRUE)
add_zscore(filtered, "rev_cagr",  "REVCAGR_gs",   group_col = "mkt_tier", higher_is_better = TRUE)
add_zscore(filtered, "roe_delta", "ROEDELTA_gs",  group_col = "mkt_tier", higher_is_better = TRUE)
add_zscore(filtered, "opm_delta", "OPMDELTA_gs",  group_col = "mkt_tier", higher_is_better = TRUE)
add_zscore(filtered, "PEG",       "PEG_gs",       higher_is_better = FALSE)

filtered[, score_growth := {
  roe_wt   <- fifelse(is.na(ROE_gs),       0, 0.15)
  opm_wt   <- fifelse(is.na(OPM_gs),       0, 0.15)
  cagr_wt  <- fifelse(is.na(REVCAGR_gs),   0, 0.20)
  roed_wt  <- fifelse(is.na(ROEDELTA_gs),  0, 0.20)
  opmd_wt  <- fifelse(is.na(OPMDELTA_gs),  0, 0.20)
  peg_wt   <- fifelse(is.na(PEG_gs),       0, 0.10)
  base_wt  <- roe_wt + opm_wt + cagr_wt + roed_wt + opmd_wt + peg_wt
  raw <- fifelse(is.na(ROE_gs),       0, ROE_gs*0.15) +
    fifelse(is.na(OPM_gs),       0, OPM_gs*0.15) +
    fifelse(is.na(REVCAGR_gs),   0, REVCAGR_gs*0.20) +
    fifelse(is.na(ROEDELTA_gs),  0, ROEDELTA_gs*0.20) +
    fifelse(is.na(OPMDELTA_gs),  0, OPMDELTA_gs*0.20) +
    fifelse(is.na(PEG_gs),       0, PEG_gs*0.10)
  fifelse(base_wt > 0, round(raw / base_wt, 2), NA_real_)
}]

log_step("성장", "score_growth 계산 완료")

# ============================================================
# 10. 최종 스코어 + 추출
# ============================================================
filtered[, `:=`(
  score_best = {
    sb <- pmax(score_value, score_growth, na.rm = TRUE)
    fifelse(is.finite(sb), sb, NA_real_)
  },
  best_track = fifelse(
    is.na(score_growth) | (!is.na(score_value) & score_value >= score_growth), "V", "G")
)]

# 대형: 전부 포함
result_large <- filtered[is_large == TRUE]

# 중소형: score_best 상위 N개
result_small <- filtered[is_large == FALSE][order(-score_best)][1:min(SMALL_SLOTS, sum(!filtered$is_large))]

result <- rbind(result_large, result_small)
result <- result[order(-score_best)]

log_step("추출", "대형 %d + 중소형 %d = 총 %d",
         nrow(result_large), nrow(result_small), nrow(result))

# ============================================================
# 11. 출력
# ============================================================
out_cols <- c("종목코드", "종목명", "시장구분", "산업분류", "시가총액",
              "mkt_rank", "is_large", "is_financial", "best_track",
              "score_value", "score_growth", "score_best",
              "ROE", "PER", "PBR", "PCR", "OPM", "DEBT", "DIV",
              "rev_cagr", "roe_delta", "opm_delta", "PEG",
              "onetime_flag", "value_gap", "fscore", "value_label")

result_out <- result[, .SD, .SDcols = intersect(out_cols, names(result))]

result_list <- list(
  meta = list(
    generated_at = as.character(Sys.time()),
    db_date = latest_date,
    auto_include_cutoff = AUTO_INCLUDE_CUTOFF,
    small_slots = SMALL_SLOTS,
    total_large = nrow(result_large),
    total_small = nrow(result_small)
  ),
  candidates = result_out
)

tryCatch(
  write_json(result_list, output_path, pretty = TRUE, auto_unbox = TRUE),
  error = function(e) {
    log_step("에러", "결과 저장 실패: %s (경로: %s)", conditionMessage(e), output_path)
    stop(sprintf("결과 파일 저장 실패: %s", output_path))
  })
log_step("저장", "%s (%d종목)", output_path, nrow(result))

# 요약 출력
cat("\n===== 대형 TOP 10 (가치) =====\n")
print(result[is_large==TRUE][order(-score_value)][1:10,
  .(종목명, score_value=round(score_value,1), ROE=round(ROE,1),
    PER=round(PER,1), PBR=round(PBR,2), DIV=round(DIV,2))])

cat("\n===== 대형 TOP 10 (성장) =====\n")
print(result[is_large==TRUE][order(-score_growth)][1:10,
  .(종목명, score_growth=round(score_growth,1), ROE=round(ROE,1),
    rev_cagr=round(rev_cagr*100,1), roe_delta=round(roe_delta,1))])

cat("\n===== 중소형 TOP 10 =====\n")
print(result[is_large==FALSE][order(-score_best)][1:10,
  .(종목명, best_track, score_best=round(score_best,1),
    ROE=round(ROE,1), PER=round(PER,1))])

cat(sprintf("\n완료. %d → 하드필터 %d → 최종 %d (대형 %d + 중소형 %d)\n",
            nrow(raw), nrow(filtered), nrow(result),
            nrow(result_large), nrow(result_small)))
