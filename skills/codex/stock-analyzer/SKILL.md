---
name: "stock-analyzer"
description: "Korean stock (KRX) analysis combining PostgreSQL financial statement database with web news sentiment. Use when analyzing Korean stocks, screening KRX listed companies, evaluating 종목, finding undervalued stocks, or performing fundamental + sentiment analysis on Korean equities. Triggers on: 종목 분석, 주식 분석, 종목 추천, 저평가 종목, 재무제표 분석, 뉴스 감성 분석, KRX screening."
---

# Korean Stock Analyzer

## Mission & Done Criteria

**Mission** (1문장): 개인 PostgreSQL DB + 리포트 팩트 + 웹 검색 기반 KRX 종목 스크리닝·분석 자동화로, 사용자에게 투자 판단용 메인/와일드카드 리스트와 Risk Flag 기반 Signal을 제공한다.

**Done 등급** (스킬 1회 실행의 결과 판정, 상위부터 적용):
1. **완전 성공**: 아래 조건 모두 충족
   - [ ] `screening_result.json` 생성 (종목 수 ≥ 1)
   - [ ] 메인 3개 리스트(가치/성장/혼합 TOP 10) 모두 10행 출력
   - [ ] 와일드카드 3개 리스트(가치/성장/혼합 TOP 5) 모두 5행 출력 (3개 섹션 전부 5행 충족)
   - [ ] 메인 리스트 종목 각각에 `risk_flag` ∈ {Red, None, Unknown} 부착
   - [ ] Obsidian vault `{YYYY-MM-DD}_스크리닝_리포트.md` 저장
   - [ ] 포트폴리오/리밸런싱 요청이면 `{YYYY-MM-DD}_포트폴리오_리밸런싱_리포트.md` 저장 및 최종 응답에 저장 경로 명시
2. **부분 성공** (Confidence 자동 1단계 하향): 아래 중 어느 하나라도 해당
   - 메인 TOP 10 중 1개 이상이 10행 미만 (후보 부족 — "후보 부족 ({N}개)" 명시 후 가능한 개수 출력)
   - 와일드카드 1~2개 섹션이 후보 0건 또는 5행 미만
   - 메인 종목의 Risk Flag가 전체 Unknown
3. **N/A** (분석 불가로 종료): DB 데이터 전무 (월별기업정보·재무제표 동시 부실) **또는** 재무 최소 요건(매출·영업이익·자본 중 2개 이상) 미충족 + 리포트/공시 0건

## Output Persistence Contract (필수)

- `stock-analyzer`가 스크리닝, 종목 추천, 포트폴리오 비교, 리밸런싱, KIS 잔고 분석 중 하나라도 수행하면 최종 결과를 반드시 Obsidian vault에 저장한다.
- 사용자가 명시적으로 "저장하지 마", "파일 만들지 마", "Obsidian 저장 생략"이라고 요청한 경우에만 Obsidian 저장을 생략한다.
- repo 내부에는 중간 산출물을 남기지 않는다. 스크리닝 JSON, KIS 잔고 JSON, 기술지표 JSON, 임시 리포트 조각은 `/tmp`에 생성한다.
- `/tmp` 중간 파일과 토큰 캐시는 최종 Obsidian 리포트 저장 후 삭제한다.
- `git clean`, untracked 파일 삭제, 임시 파일 삭제 요청은 repo 작업공간 정리를 의미하며, Obsidian 최종 리포트 삭제로 해석하지 않는다.
- 최종 응답에는 저장된 Obsidian 파일의 절대 경로를 반드시 포함한다.

## Why This Skill

개인 PostgreSQL DB(metainfo)를 AI agent가 직접 쿼리하고, 웹 뉴스와 결합하여 multi-factor 종목 분석을 자동화. 기존 도구(네이버 금융, 증권사 HTS, FnGuide, 퀀트킹)는 각각 재무 데이터 또는 뉴스만 커버하며, 개인 DB 커스텀 쿼리 + LLM 뉴스 감성 자동 결합은 제공하지 않음.

**차별점** (기존 도구 대비):
| 기능 | 네이버 금융 | FnGuide | 퀀트킹 | 이 스킬 |
|------|-----------|---------|--------|--------|
| 개인 DB 커스텀 SQL 쿼리 | ✗ | ✗ | ✗ | ✅ stocks-db MCP |
| 재무+뉴스 감성 자동 결합 리포트 | ✗ (수동 탭 전환) | ✗ (재무만) | ✗ (정량만) | ✅ Step 1→2 자동화 |
| R 스크립트 자동 스크리닝 | ✗ | ✗ | 일부 | ✅ screening_pipeline.R |
| 가치+성장 이중 스코어링 | ✗ | ✗ | ✗ | ✅ score_value + score_growth |
| 연결/별도 재무제표 구분 FCF | ✗ | ✅ (유료) | ✗ | 🔜 DB 구축 완료, 스킬 반영 예정 |

**한계**: DB는 실시간 데이터 없음(월별기업정보 매월 말 갱신, 재무제표 수시). 일별 가격 시계열·기술적 지표는 **한국투자증권 Open API**(`script/kis_price.py`)로 조회 (KIS 계정 필요, 스크리닝 단계엔 미사용). 주문 실행 불가, DB 규모 상용 대비 제한적.

**왜 지금**: 2026년 별도재무 DB 구축 완료(연결구분 컬럼)로 연결/별도 FCF 구분이 가능해짐. 상법개정(자사주 소각 의무화)으로 저PBR/주주환원 분석 수요 증가. stocks-db MCP 연동으로 Codex에서 DB 직접 쿼리 가능.

**타겟 사용자**: PostgreSQL DB(metainfo)를 직접 운영하는 한국 개인투자자. R 스크립트(InsertCorpData.R)로 재무 데이터를 수집하고, Codex에서 종목 분석/스크리닝을 수행. 투자 스타일: 중장기 펀더멘탈 + 배당/주주환원.

**사용자 행동 모델:**
- **분석 빈도**: 월 1~2회 정기 스크리닝 + 실적 발표/이벤트 시 수시 개별 종목 분석
- **워크플로우**: R 스크립트로 DB 갱신 → Codex에서 stock-analyzer skill 호출 → 리포트 검토 → 매수/보유/매도 판단
- **기술 수준**: SQL 직접 작성 가능, R 숙련, Python 기초. Codex 프롬프트로 분석 지시.
- **핵심 제약**: (1) 실시간 시세 없음 — 월별/분기별 DB 기준 판단 (2) 1인 운영 — DB 갱신을 잊으면 stale 데이터로 분석 (3) 투자 시간 지평 6개월~3년 — 단기 트레이딩 아님

## Data Sources

### 1. PostgreSQL Database (stocks-db MCP)
User's personal DB with KRX financial statements. `InsertCorpData.R` 스크립트로 매일 업데이트.

**전제 조건:**
- `stocks-db` MCP 서버가 user scope로 설치되어 있어야 함 (`codex mcp list`로 확인)
- 서버 패키지: `@modelcontextprotocol/server-postgres` (Node.js 필요, MCP 패키지 요건에 따름)
- DB 접속: PostgreSQL `stocks` database, `metainfo` schema
- API 키 불필요 (DB 인증 정보는 MCP 서버 설정에 포함됨)

**Available Tables:**
| 테이블 | 설명 | 업데이트 주기 | 주요 컬럼 |
|--------|------|-------------|----------|
| `metainfo.월별기업정보` | 월별 기업 요약 | 매월 말 | 종목코드, 종목명, 시장구분, 산업분류, 현재가(종가), 시가총액, 배당수익률, 관리여부, 자산~잉여현금흐름 (26개 컬럼) |
| `metainfo.연간재무제표` | 연간 재무제표 (FnGuide) | 수시 (실적 발표 시) | 종목코드, 종류, 계정, 일자, 값 (EAV 구조) |
| `metainfo.분기재무제표` | 분기 재무제표 (FnGuide) | 수시 (실적 발표 시) | 종목코드, 종류, 계정, 일자, 값 (EAV 구조) |

**스키마 확인 (첫 실행 시 필수):**
```sql
SELECT column_name, data_type FROM information_schema.columns WHERE table_schema = 'metainfo' AND table_name = '월별기업정보' ORDER BY ordinal_position;
```

### 2. Web Search (Codex 웹 검색)
API 키 불필요. Codex의 웹 검색 기능을 사용하여 실시간 뉴스 수집.

**전제 조건:**
- 웹 검색이 활성화되어 있어야 함
- 인터넷 연결 필요

**검색 대상:**
- 네이버 금융, 한국경제, 매일경제, 조선비즈 등 한국어 뉴스
- 애널리스트 리포트 및 컨센서스
- 산업 동향 및 매크로 데이터
- 경쟁사 및 섹터 정보

### 3. R 스크립트 (`script/screening_pipeline.R`)
Step 1(정량 스크리닝)을 자동화하는 R 스크립트. DB에 직접 접속하여 하드필터 + 스코어링을 수행.

**전제 조건:**
- R ≥ 4.1
- R 패키지:
  - `screening_pipeline.R` 코어: `RPostgres`, `DBI`, `jsonlite`, `data.table`
  - `fnguide_consensus.R` (컨센서스 필드 산출용, `screening_pipeline.R`이 source): `httr`, `jsonlite`, `stringr`
  - **설치**: `install.packages(c("RPostgres","DBI","jsonlite","data.table","httr","stringr"))`
- Python (정성 데이터 수집 시 필요): Python ≥ 3.10 (type hints `list[X]`, `dict[X,Y]`, `Path | None` 사용), `requests`, `beautifulsoup4`
  - **설치**: `pip install requests beautifulsoup4`
- `~/config.json` 필수 키 (컴포넌트별):
  - **screening_pipeline.R** (스킬 직접 실행):
    ```json
    { "database": { "host": "", "port": 5432, "user": "", "passwd": "", "database": "stocks" } }
    ```
  - **dart_disclosures.py** (정성 데이터 수집 시 Red Flag 출처 URL용):
    ```json
    { "dart": { "api_key": "{OpenDART API 키}" } }
    ```
    `opendart.fss.or.kr`에서 API 키 발급 필요. 환경변수 `DART_API_KEY`로도 대체 가능.
  - **InsertCorpData.R** (DB 갱신, 업스트림):
    ```json
    { "database": { "host": "", "port": 5432, "user": "", "passwd": "", "database": "stocks" }, "krx": { "id": "", "password": "" }, "telegram": { "token": "", "chatId": "" } }
    ```
    `krx`: KRX 데이터 포탈 로그인용. `telegram`: 실행 완료 알림용.
- 실행: `Rscript script/screening_pipeline.R [output_path]`

**출력**: JSON 파일 — ~330개 종목 + score_value, score_growth, 주요 재무 지표


### 4. KIS Open API (한국투자증권) — 실시간 시세 및 기술적 지표

실시간 현재가·일봉 시계열·OHLCV를 제공하는 한국투자증권 Open API. **스크리닝 단계(Step 1·2)에는 사용하지 않고, 최종 포트폴리오 확정 후 진입 타이밍·기술적 분석 단계에서만 호출**. 참조 구현: `script/Han2FunctionList.R` 및 `script/kis_price.py`.

**전제 조건:**
- `~/config.json`의 `api.account.prod.main.appkey` / `appsecret` / `accNo` 필수 (한국투자증권 Open API 신청 필요)
- `config.url = https://openapi.koreainvestment.com:9443`
- Python: `requests` (pip 표준)
- 토큰 유효기간 24시간 — 캐시 권장

**사용 함수 (script/kis_price.py):**

| 함수 | TR_ID | 용도 | 반환 |
|------|-------|------|------|
| `get_token()` | `/oauth2/tokenP` | OAuth 토큰 발급 (24시간 캐시) | access_token |
| `get_current_price(code)` | `FHKST01010100` | **실시간 현재가** | 현재가·거래량·전일대비 |
| `get_daily_chart(code, days)` | `FHKST03010100` | **일봉 OHLCV** (최대 100일) | date, open, high, low, close, volume |
| `calculate_indicators(ohlcv)` | (자체 계산) | **기술적 지표** | ma5/20/60/120, rsi14, 52주 고/저, 구간별 수익률 |

**사용 시나리오 (Step 2d 완료 이후):**

| 시점 | 함수 | 트리거 |
|------|------|--------|
| 최종 포트폴리오 제안 | `get_current_price` + `calculate_indicators` | 메인·와일드 종목 대상 이평선 위치, RSI 과열/과매도 판정 |
| "지금 사도 되나?" 질문 | `get_daily_chart(100)` → 이평선 배열·RSI | 눌림목·추세 판정 |
| 정확한 현재가 필요 시 | `get_current_price` | DB 월말 종가 대신 실시간 시세 |
| 분할 매수 가격 제안 | `get_daily_chart` + 5/20일선 | 지지선·저항선 기반 |

**사용 금지 시점:**
- Step 1(정량 스크리닝) 진행 중 — R 스크립트가 이미 재무 지표 산출
- Step 2a/2b/2d 스코어링 순위 — 정량 스코어링 일관성 유지를 위해 혼용 금지
- **스코어링 로직에는 시세 지표를 반영하지 않는다.** 최종 포트폴리오 제시 단계의 부가 정보로만 활용

**한계 및 Fallback:**
- KIS Open API 계정 미설정 시 → DB 월말 종가 기반 fallback (Confidence 유지)
- API 레이트 리밋: 일반적으로 1초당 20회, 초과 시 재시도 1회
- 토큰 발급 실패 시 `~/config.json` `api.account.prod.main` 인증 확인 안내
- 모의투자 계정(`api.account.dev`)은 `url = https://openapivts.koreainvestment.com:29443`로 별도

**스킬 범위 기술적 지표:**
- 이동평균선 (5/20/60/120일)
- RSI (14)
- 52주 최고/최저
- 구간별 수익률 (5d/20d/60d/120d)
- MACD·볼린저밴드 등 고급 지표는 Python `ta` 또는 `pandas-ta` 라이브러리로 확장 가능 (기본 Python만으로는 이평선·RSI만 계산)

**Confidence 영향:**
- KIS API 사용 가능 시 기술적 지표 교차 검증으로 포트폴리오 제안 정확도 향상
- 실패 시 **Confidence 미영향** (스코어링은 DB·리포트 기반). 사용자에게 "KIS API 인증 또는 장외 시간 — HTS에서 직접 확인 권장" 안내


### Upstream Data Pipeline Dependencies

스킬이 직접 사용하지는 않지만, DB 데이터의 신선도를 유지하기 위해 `InsertCorpData.R`이 의존하는 외부 시스템:

| 의존성 | 용도 | 인증/접근 | 장애 시 영향 |
|--------|------|----------|-------------|
| FnGuide (`comp.fnguide.com`) | 연간/분기 재무제표 크롤링 (`getFSHtmlFromFnGuide()`) | 공개 접근 (로그인 불필요), `Sys.sleep(1)` 레이트 리밋 | 재무제표 테이블 갱신 불가 → 데이터 신선도 경고 |
| KRX 데이터 포탈 (`data.krx.co.kr`) | 월별기업정보 다운로드 (`loginKRX()` + `KRXDataMerge()`) | `config.json` `krx.id`/`krx.password` 필요 | 월별기업정보 갱신 불가 → 스크리닝 기반 데이터 경과 |
| 네이버 금융 (`fchart.stock.naver.com`) | 전월 말 영업일 조회 (`getLastBizdayofMonth()` → `adjustedPriceFromNaver()`) | 공개 접근 | InsertCorpData.R 실행 초반 실패 (line 20에서 중단) |
| WISE Index (`www.wiseindex.com`) | WICS 산업 섹터 분류 (`WICSSectorInfo()`) | 공개 접근 | 산업분류 갱신 불가 (기존 DB 데이터로 스크리닝은 가능) |
| `RQuantFunctionList.R` | InsertCorpData.R의 핵심 함수 라이브러리 (25+ R 패키지 자동 로드) | 로컬 파일 | InsertCorpData.R 실행 불가 |
| `telegramAPI.R` | 실행 완료 알림 (Telegram 봇) | `config.json` `telegram.token`/`telegram.chatId` | 소싱 실패 시 InsertCorpData.R 중단 / Telegram API 장애 시 알림 실패만 (DB 갱신 계속) |

이 시스템들은 웹 크롤링 기반이므로 HTML 구조 변경 시 스크립트 수정이 필요할 수 있다. 스킬 실행 시점에서는 DB에 데이터가 존재하면 정상 동작하며, 데이터 경과일 체크(분석 완성도 기준)로 stale 상태를 감지한다.

**가용성 확인**: `InsertCorpData.R` 실행 전 KRX 로그인, FnGuide 접근, 네이버 응답을 순차 확인. 실패 시 해당 데이터 소스를 건너뛰고 나머지만 갱신.


## 2-Step Analysis Workflow

분석은 **정량(R 스크립트) → 정성(스킬)** 2단계로 구성된다.

### Step 번호 범례 (전 문서 공통)

문서 내 Step 번호는 아래 고정 의미로만 사용된다. 섹션마다 재사용되어도 아래 역할과 동일하다. 과거 일부 섹션의 혼용은 이 범례를 우선 적용하여 해석한다.

| Step | 역할 | 주요 산출물 |
|------|------|-------------|
| Step 1 | R 스크립트 정량 스크리닝 | `screening_result.json` (330개 후보 + score_value/score_growth/broker_count/holding_distortion 등) |
| Step 2a | 테마 발견 + 330개 종목 태깅 | 종목별 `themes[]` 라벨 |
| Step 2a' | 커버리지 분리 (Covered/Uncovered, 지주왜곡 제외) | 두 풀 목록 |
| Step 2b | 리포트 팩트 추출 (리포트 PDF/컨센서스/웹 검색) + Risk Flag 산출 | 종목별 `{valuation_basis, investment_thesis, risks, moat, risk_flag, risk_flag_reasons[], risk_flag_sources[]}` |
| Step 2c | 별도재무 확인 (연결 부채비율 > 150% 종목 대상) | 해당 종목 `sep_DEBT` override |
| Step 2d | 종합 판정 + 6개 리스트 산출 + Signal/Confidence | 최종 Markdown 리포트 내용 |
| Step 2e | Obsidian vault 필수 저장 | `{YYYY-MM-DD}_스크리닝_리포트.md` 또는 `{YYYY-MM-DD}_포트폴리오_리밸런싱_리포트.md` 파일 |

이 범례에 따라 하위 섹션의 "2b 뉴스/감성" 같은 표현은 "2b 리포트 팩트 추출(Risk Flag 포함)"으로 읽는다.

```
Source (데이터 소스)                    Step (처리)                생산물
──────────────────────────────────────────────────────────────────────────
PostgreSQL.월별기업정보  ─┐
PostgreSQL.연간재무제표  ─┤→ Step 1: R 스크립트     → ~330개 후보
PostgreSQL.분기재무제표  ─┘  (하드필터 + 스코어링)    + score_value, score_growth
                                                      
웹 검색 (뉴스/감성)    ─┐
ETF/테마 데이터          ─┤→ Step 2: 스킬           → 메인: 가치/성장/혼합
애널리스트 컨센서스      ─┤  (테마 태깅 + 커버리지         TOP 10 × 3 (Covered)
Obsidian 리포트 PDF      ─┘   분리 + 리포트 팩트)    → 와일드카드: 가치/성장/혼합
                                                       TOP 5 × 3 (Uncovered)
```

### Step 1: R 스크립트 (정량 — 자동)

**실행**: `Rscript script/screening_pipeline.R screening_result.json`

| 단계 | 내용 | 결과 |
|------|------|------|
| 하드필터 | 관리종목·자본잠식 제거 | ~2,350개 |
| 시총 분리 | 상위 300위(대형) 전부 포함 | 300개 자동 |
| 소형 필터 | 매출 버퍼·영업적자·편법 탐지 | ~1,050개 통과 |
| 스코어링 | 가치(score_value) + 성장(score_growth) | 전 종목 점수 |
| 추출 | 대형 300 + 중소형 상위 30 | **~330개** |

**출력**: `screening_result.json` — 330개 종목 + 가치/성장 점수

### Step 2: 스킬 (정성 — Codex 수행)

| 단계 | 내용 | 대상 |
|------|------|------|
| 테마 태깅 | 밸류업(고정) + 동적 테마(직전 3개월 기반) 해당 여부 | 330개 전체 |
| 커버리지 분리 | broker_count 기준 Covered/Uncovered pool 분리 | 330개 → Covered + Uncovered |
| 리포트 팩트 | Covered 메인 3개 TOP 10 합집합(~25개): Obsidian PDF / Uncovered 3개 TOP 5 합집합(~10개): 웹 검색 | 상위 ~35개 |
| 종합 판정 | 정량 순위(sv/sg/avg)로 6개 리스트 산출 (메인 3 × 와일드카드 3) | → 최종 ~40개 |

### 진입 분기

| 사용자 요청 | 시작 지점 |
|------------|-----------|
| 종목코드/종목명 지정 (예: "삼성전자 분석해줘") | **Step 2** (스크리닝 스킵, 해당 종목만 분석) |
| 조건 기반 스크리닝 (예: "저PER 고ROE 종목 찾아줘") | **Step 1** → Step 2 |
| 추천 요청 (예: "유망한 종목 추천해줘") | **Step 1** → Step 2 |

### 단계별 사용자 I/O

스킬은 사용자의 최초 프롬프트를 받아 자동으로 전 단계를 실행한다. 각 단계 완료 시 진행 상황을 사용자에게 표시한다. **예외적 사용자 입력**: 종목 조회 시 부분 매칭 결과가 복수이면 후보 목록을 제시하고 사용자 선택을 요청한다 (유일 매칭이면 자동 진행).

**사용자 입력 (최초 프롬프트):**
- 필수: 분석 요청 (종목명/종목코드, 스크리닝 조건, 또는 추천 요청)
- 선택: 커버리지 필터 조정 — 기본은 TOP 10을 Covered pool(`broker_count >= 1`)로 한정하고 Uncovered는 와일드카드로 분리. `"커버리지 무시"` 옵션 지정 시 모든 종목을 단일 풀로 통합하여 **와일드카드 섹션 없이 메인 3개 TOP 10만** 출력 (Uncovered 종목도 broker_count 무관하게 메인 풀에 포함, Confidence 1단계 하향)
- 선택: 와일드카드 최소 기준 임계값 (기본 **sv/sg/avg 각 6.5**). 예: `"와일드카드 임계 7.0"` 지정 시 세 기준 모두 7.0으로 상향
- 선택: 개별 종목 분석 시 확인용 가중치는 사용하지 않음(A차원만 스코어링). 스크리닝 경로는 **메인 3개 TOP 10 + 와일드카드 3개 TOP 5** 대칭 구조로 고정

**스크리닝 경로 (Step 1 → Step 2):**

| 단계 | 시스템 출력 (사용자에게 표시) |
|------|---------------------------|
| Pre-check | DB freshness 확인 → 경과일 초과 시 `⚠️ {테이블} 기준일: {일자} ({N}일 경과)` 경고 표시 후 계속 진행 |
| Step 1 실행 | `스크리닝 실행 중...` → 완료 시 `{N}개 후보 추출 (대형 {n1}개 + 중소형 {n2}개)` |
| Step 2a 테마 태깅 | `테마 발견: 밸류업(고정) + {동적테마1}, {동적테마2}, ... ({N}개). 태깅: 밸류업 {N}개, {테마1} {N}개, ... → 330개 종목 전체에 테마 라벨 부착` |
| Step 2a' 커버리지 분리 | `Covered pool: {n1}개 (broker_count>=1) / Uncovered pool: {n2}개 (커버 없음) / 지주왜곡 {h}개 제외` |
| Step 2b 리포트 팩트 추출 | `리포트·공시·뉴스 확인 중 ({current}/{total})...` → 완료 시 `Risk Flag Red {R}건 / None {N}건 / Unknown {U}건` |
| Step 2c 별도재무 | (해당 종목만) `별도재무 확인: {종목명} 연결 부채비율 {X}% → 별도 {Y}%` |
| Step 2d 종합 판정 | Report Structure 8개 섹션 출력 (메인 가치/성장/혼합 TOP 10 + 와일드카드 가치/성장/혼합 TOP 5 + Signal + Risk) |
| Step 2e Obsidian 저장 | `리포트 저장 완료 → ~/Documents/Obsidian Vault/StockAnalysis/screening/{YYYY-MM-DD}_스크리닝_리포트.md` 또는 포트폴리오 요청 시 `{YYYY-MM-DD}_포트폴리오_리밸런싱_리포트.md` (동일 경로 존재 시 `_v2`, `_v3` 접미사 부여) |

**개별 종목 경로 (Step 2 직행):**

| 단계 | 시스템 출력 |
|------|-----------|
| Pre-check | DB freshness 확인 (동일) |
| 종목 조회 | 유일 매칭: `{종목명} ({종목코드}) 조회 완료`. 복수 매칭: `"{검색어}" 검색 결과 {N}건: 1. {종목명A} ({코드A}) 2. {종목명B} ({코드B}) ... 번호를 선택해주세요.` |
| 재무 분석 | `{종목명} 재무 분석 중...` → `A 차원: {score}/10 (업종: {산업분류}, 백분위 상위 {p}%)` |
| 리포트 팩트 | `{종목명} 리포트·공시·뉴스 수집 중...` → `Risk Flag: {Red/None/Unknown}, 핵심 리스크 {N}건` |
| 별도재무 | (연결 부채비율 >150% 시) `별도재무 확인: 연결 {X}% → 별도 {Y}%` |
| 종합 판정 | 단일 종목 스코어카드 (A 정량 + B 테마 라벨 + 리포트 팩트 Risk Flag + Signal + Confidence, 비중 배분 없음) |

### Step 1 상세: R 스크립트 (`script/screening_pipeline.R`)

**실행**: `Rscript script/screening_pipeline.R [output_path]`
**기본 output_path**: repo 내부가 아니라 `/tmp/stock_analyzer_screening_{YYYYMMDD}.json`을 사용한다. 사용자가 명시한 경우에만 다른 경로를 사용한다.
**출력**: JSON 파일 — ~330개 종목 + score_value, score_growth, 주요 지표

#### 하드필터 (이상한 기업만 제거)

| 필터 | 대상 | 기준 |
|------|------|------|
| 관리종목 | 전체 | `관리여부 != '관리종목'` |
| 자본잠식 | 전체 | `자본 > 0` |
| 매출 버퍼 | 중소형(301위+)만 | KOSDAQ ≥ 60억, KOSPI ≥ 100억 |
| 영업적자 이력 | 중소형만 | 최근 3년 중 2년 이상 적자 → 제외 |
| 의심 흑자전환 | 중소형만 | 3년 적자 후 OPM < 2% → 제외 |
| 적자+유상증자 | 중소형만 | 직전 2년 중 1회라도 → 제외 |

#### 가치 스코어 (score_value)

**일반 기업**: 업종 내 백분위 (0-10)
| 항목 | 비중 | 방향 |
|------|:---:|:---:|
| PER | 20% | 낮을수록 |
| 배당수익률 | 20% | 높을수록 |
| ROE | 15% | 높을수록 |
| PBR | 15% | 낮을수록 |
| PCR(FCF) | 10% | 낮을수록 (NA면 재배분) |
| OPM | 10% | 높을수록 |
| 부채비율 | 10% | 낮을수록 |

**금융 기업**: 금융 전체 백분위 (PCR/OPM/부채 제외)
| 항목 | 비중 |
|------|:---:|
| ROE | 30% |
| PER | 25% |
| PBR | 20% |
| 배당수익률 | 25% |

#### 성장 스코어 (score_growth)

업종 내 백분위(Level) + 시총 구간별 백분위(Delta)
| 항목 | 비중 | 유형 |
|------|:---:|:---:|
| 매출 CAGR (3Y) | 20% | Delta (시총구간별) |
| ROE 개선폭 (최근 ROE − 3년전 ROE) | 20% | Delta (시총구간별) |
| OPM 개선폭 | 20% | Delta (시총구간별) |
| ROE 수준 | 15% | Level (업종 내) |
| OPM 수준 | 15% | Level (업종 내) |
| PEG (매출CAGR 기반) | 10% | 낮을수록 (NA면 재배분) |

#### 추출 규칙
- **대형 (시총 상위 300위)**: 전부 자동 포함 (스코어는 참고용)
- **중소형 (301위+)**: score_best (= max(score_value, score_growth)) 상위 30개

### Step 2 상세: 스킬 (정성 분석 — Codex 수행)

Step 2는 R 스크립트 결과(~330개)를 받아 정성 분석 후 6개 리스트(메인 가치/성장/혼합 TOP 10 + 와일드카드 가치/성장/혼합 TOP 5)를 산출한다.

#### 실행 패턴 (순차/병렬)

**스크리닝 경로의 Step 2 내부 반복 실행 지점은 순차가 기본**. 병렬 허용 범위는 아래 표의 "병렬 허용" 행에 한정 (2a 독립 웹 검색 3쿼리 + 개별 종목 비교 요청의 종목별 MCP 재무 쿼리).

| 지점 | 방식 | 근거 |
|------|------|------|
| 2a 동적 테마 웹 검색 3쿼리 (시장/ETF/정책) | 병렬 허용 | 3개 쿼리는 독립 탐색이며, 결과 통합 후 "3건 이상 독립 소스" 기준으로 채택 |
| 2a Phase 2 테마별 ETF·산업분류 매핑 | 순차 | 선정 테마별 매핑 결과를 DB 산업분류·매출 비중 확인에 누적 적용 |
| 2b Covered PDF 읽기 (~25건) | 순차 | 읽기 실패 시 즉시 `risk_flag=Unknown`+"리포트 없음" 처리 후 다음 종목 진행 |
| 2b Uncovered 웹 검색 (~10건) | 순차 | rate limit 방지 + 검색 품질 보장 |
| 2b Red Flag 검색 (종목당 최대 7쿼리) | 순차 | 동일 종목 7개 타깃을 출처 URL과 함께 검증 (병렬 필요 시 종목 간만 허용) |
| stocks-db MCP 쿼리 | 순차 | R 산출물 우선 사용, MCP fallback/구조 재확인 쿼리는 재시도 흐름과 연동 |
| 2d 6개 리스트 / Signal / Confidence 산출 | 순차 | 2b Risk Flag와 커버리지 분리 결과가 입력, 도구 병렬 대상 아님 |
| 개별 종목 비교 요청 (예: "A vs B") MCP 재무 쿼리 | **병렬 허용** | 종목 간 데이터 독립 (Scope 원칙 1의 "병렬 실행" 대응) |

**연속 실패 중단 조건:**
- 2b PDF 읽기 **5종목 연속 실패** → 남은 Covered 종목 `risk_flag=Unknown` 일괄 처리. Done 판정 "부분 성공"으로 하향. Confidence 하향 요인 "PDF 읽기 대량 실패(-1)" 적용.
- 2b PDF **전체 실패율 50% 이상** → Obsidian vault 접근 불가 경고 표시. PDF 읽기에 실패한 Covered 종목에 한해 웹 검색 fallback(Uncovered 경로)으로 전환하여 사업 모델·최근 실적·리스크만 수집 (성공한 PDF의 추출 결과는 유지).
- 2a Phase 2 ETF/산업분류 매핑에서 **테마별 종목 0건이 3개 테마 연속** → 해당 테마 라벨 부착 생략 (남은 테마만 진행, 경고 메시지).

**Agent 사용 여부**: 이 스킬은 sub-agent를 스폰하지 않는다 (Codex가 MCP, 파일 읽기, 웹 검색, 셸을 사용해 선형 수행). Agent 스폰이 필요한 확장 시나리오가 생기면 이 섹션 하단에 스폰 패턴을 추가한다.

#### 2a. 테마 태깅 (동적 테마 발견 → 종목 매핑)

테마는 **고정 목록이 아니라 실행 시점 기준 직전 3개월의 시장 정보로 동적 결정**한다.

**고정 테마 (상시):**
- **밸류업/주주환원**: 밸류업 지수 편입 여부, 자사주 소각/분기배당 공시, PBR < 1.0 대형주. 항상 포함.

**동적 테마 발견 (웹 검색):**
실행일 기준 직전 3개월간의 시장 테마를 웹 검색으로 탐색:
1. `"한국 주식시장 테마 {YYYY}년 {M-2}~{M}월"` — 시장 전체 테마 트렌드
2. `"ETF 수익률 상위 테마 {YYYY}년"` — 자금 유입이 검증된 테마
3. `"한국 산업 정책 {YYYY}년"` — 정부 정책/법제 변화

검색 결과에서 **3건 이상의 독립 소스에서 언급된 테마**만 채택. 동적 테마는 최소 2개, 최대 7개 선정 (밸류업 포함 총 3~8개).

**Phase 2: 테마별 ETF/종목 매핑 (웹 검색)**
선정된 각 테마에 대해:
1. `"{테마명} ETF 구성종목 {YYYY}"` 검색 → 해당 테마 ETF가 있으면 편입 종목 파악
2. DB `산업분류` 매칭 — 테마와 관련된 산업분류 식별
3. 산업분류 미매칭 종목은 웹 검색으로 매출 비중 확인하여 50% 이상이면 해당으로 판정

**Phase 3: 종목 태깅**
- 330개 후보에 대해 Phase 2 결과를 매핑하여 각 종목에 테마 라벨 부착
- 추가로 `PBR < 1.0` 대형주는 밸류업/주주환원 후보로 별도 태깅 (상시)
- 테마는 스코어링에 포함하지 않고 **리스트에 병기되는 메타데이터**로만 사용

**출력**: 테마 목록 + 종목별 테마 라벨 (와일드카드 선정은 별도 섹션 "Report Structure"의 커버리지 기준 적용)

#### 2b. 리포트 팩트 추출 (상위 종목 대상)

Covered pool의 가치/성장/혼합 각 TOP 10 합집합(약 20~25개)에 대해 애널리스트 리포트 PDF에서 구조화된 팩트를 추출한다. 와일드카드(Uncovered)는 PDF가 없으므로 웹 검색으로 사업 모델·최근 실적·리스크를 별도로 확인하여 1~2줄 요약을 병기한다.

**리포트 PDF는 `qualitative_pipeline.py`로 Obsidian vault에 사전 수집한다.** 스크리닝 실행 시 Codex가 상위 종목의 최신 리포트 PDF를 파일/PDF 읽기 기능으로 직접 읽고 아래 스키마로 구조화하여 리스트에 병기한다. **정규식 기반 자동 추출은 사용하지 않는다** (이전 `report_extractor.py` 참조는 제거됨).

**Step 2b 산출물 스키마 (Step 번호 범례의 Step 2b 행과 일치):**

| 필드 (canonical) | 한국어 명칭 | 타입 | 내용 |
|---|---|:---:|---|
| `valuation_basis` | 밸류에이션 근거 | string | 방법론(PER/PBR/DCF/SOTP) + 적용 배수 + 핵심 가정(점유율·ASP·성장률·환율 등 애널리스트가 사용한 수치 포함), 1~2줄 |
| `investment_thesis` | 투자논리 | string list | 핵심 카탈리스트 1~3개, 구체적 수치 포함 (예: "HBM4 점유율 55%") |
| `risks` | 리스크 요인 | string list | 구체적 리스크 목록 1~3개 |
| `moat` | 경쟁우위/해자 | string | 진입장벽, 점유율, 기술력 등 근거 (1~2줄) |
| `risk_flag` | Risk Flag 판정값 | enum | `Red` \| `None` \| `Unknown` (산출 규칙: 아래 "Risk Flag 산출" 참조) |
| `risk_flag_reasons[]` | Red 판정 사유 | string list | `risk_flag = Red` 시 충족된 Red 조건 목록, 그 외 빈 배열 |
| `risk_flag_sources[]` | 출처 URL | string list | `risk_flag = Red` 시 필수, 리포트/DART/웹 검색 URL |

**스코어링 사용 범위**: `valuation_basis`/`investment_thesis`/`risks`/`moat`는 리스트 병기용 메타데이터로만 사용(스코어링 제외). `risk_flag`만 Signal 판정의 보조 입력으로 사용된다 (상세: "Investment Signal 판정 규칙" 섹션).

**리포트 읽기 절차:**
1. `~/Documents/Obsidian Vault/StockAnalysis/reports/` 에서 해당 종목의 최신 PDF를 찾는다
2. 파일/PDF 읽기 기능으로 PDF를 읽는다
3. 위 7개 필드를 추출하여 리스트 테이블의 비고란에 병기한다
4. 리포트가 없는 종목은 `risk_flag = Unknown` + "리포트 없음"으로 표시한다

#### 2c. 별도재무 확인 결과 검토 (R 스크립트가 이미 계산한 내용)

**실제 처리**: R 스크립트(`screening_pipeline.R:304-346`)가 `연간재무제표` 별도 데이터를 조회하여 모든 종목에 대해 미리 계산 완료됨. 주요 산출 필드:
- `sep_ROE`, `sep_DEBT`: 별도 ROE / 부채비율
- `holding_distortion`: 별도 적자 + 연결 흑자 종목 (지주왜곡 플래그)
- `debt_override`: 연결 부채비율 > 150% AND 별도 부채비율 < 150% (별도 기준 적용 대상)
- `consol_gap`: 연결-별도 순이익 괴리율

**R 내부 보정** (`screening_pipeline.R:562-569`): `holding_distortion=TRUE` → `score_value -= 5`, `debt_override=TRUE` → `score_value += 1`. 이 보정은 Step 1 산출 시점에 이미 반영되어 있다.

**Step 2c에서 스킬의 역할** (Codex 수행): R 산출 결과를 리포트에 병기하기만 한다:
- Covered pool 중 연결 부채비율 > 150% 종목에 대해 별도 기준(`sep_DEBT`) 병기
- 사용자 I/O 표시: `Step 2c 별도재무 확인: {종목명} 연결 {X}% → 별도 {Y}%`

기존 서술 "override + score_value +1 가산"은 **R 내부에서 이미 완료됨을 설명**하는 것이며, 스킬이 별도로 계산/수정하지 않는다.

#### 2d. 종합 판정

**스코어링은 A차원(정량)만 사용한다. B차원도 점수화하지 않으며 테마 라벨만 부착한다. C차원(정성 스코어링)은 없다.**

| 차원 | 역할 | 스코어? |
|------|------|:-------:|
| **A. 정량 재무** | score_value + score_growth → 가치/성장/혼합 리스트 산출 | O |
| **B. 테마/정책** | 밸류업 + 동적 테마 → 종목별 테마 라벨 표시 (참조용 메타데이터) | X |
| **리포트 팩트** | 밸류에이션 근거, 투자논리, 리스크, 해자 → 리스트에 병기 | X |
| **Risk Flag (리포트 팩트에서 도출)** | Red/None/Unknown → Signal 판정 보조 입력 | X (enum) |

→ 가치 TOP 10 + 성장 TOP 10 + 혼합 TOP 10 리스트를 제시 (정렬은 A만).
→ 각 종목에 리포트 팩트(투자논리, 리스크, 해자) + B 테마 라벨을 병기.
→ 사용자가 정량 + 정성을 보고 직접 포트폴리오를 구성한다.

#### Core-Satellite 분류 기준

**영업이익 변동계수(CV)** = 최근 3~4년 영업이익의 표준편차 / |평균| × 100
- **Core (CV ≤ 40%)**: 이익 안정. 가치주가 대부분 해당.
- **Satellite (CV > 40%)**: 이익 변동 큼. 성장주/사이클주가 대부분 해당.
- **Unknown**: 아래 "Unknown 조건" 중 하나라도 해당 시. 라벨 공란 + "CV 데이터 부족" 각주.

**계산 경로**: CV는 **Step 2d 스킬이 `stocks-db` MCP 쿼리로 계산한다**. R 스크립트(`screening_pipeline.R`)는 CV를 산출하지 않으며 `out_cols`에 `cv_opm` 필드 없음. 따라서 혼합 리스트(메인 TOP 10 + 와일드카드 TOP 5) 대상 최대 15개 종목에 대해서만 선별 MCP 쿼리 수행.

SQL 템플릿 (PostgreSQL, `metainfo.연간재무제표` 스키마 확인 후 사용):

```sql
-- Step 2d: 혼합 리스트 대상 종목 cv_opm 계산
-- 주의: 일자 컬럼은 'YYYY.MM' 문자열 형태 (연간은 '.12'). 첫 실행 시 information_schema로 타입 확인 권장.
WITH target_years AS (
  SELECT 종목코드, 값::numeric AS op_income, 일자
  FROM metainfo.연간재무제표
  WHERE 연결구분 = '연결'
    AND 종류 = '포괄손익계산서'
    AND 계정 = '영업이익'
    AND 일자 IN (:year_list)          -- 실행 시 리터럴로 치환: ('2022.12','2023.12','2024.12','2025.12')
    AND 종목코드 IN (:top_codes)      -- 실행 시 리터럴로 치환: ('005930','000660',...) 최대 15개
)
SELECT 종목코드,
       COUNT(*) AS year_count,
       AVG(op_income) AS avg_op,
       CASE
         WHEN COUNT(*) < 3 THEN NULL
         WHEN AVG(op_income) <= 0 THEN NULL          -- 적자/흑자 혼재 → Unknown
         ELSE ROUND(STDDEV_SAMP(op_income) / ABS(AVG(op_income)) * 100, 2)
       END AS cv_opm
FROM target_years
GROUP BY 종목코드;
```

**Unknown 조건** (라벨 = Unknown, 각주 = "CV 데이터 부족"):
- `year_count < 3` (연도 데이터 3년 미만, 신규 상장 정책과 정합)
- `AVG(op_income) <= 0` (평균 영업이익 0 이하 — 적자 기업의 음수 CV 오분류 방지)
- MCP 쿼리 실패·타임아웃 (해당 종목만 Unknown, 나머지 계속)

**플레이스홀더 치환 규칙**: `stocks-db` MCP는 raw SQL을 받으므로 `:year_list`와 `:top_codes`는 **MCP 호출 직전에 Codex가 SQL 문자열에 리터럴로 치환**한다 (바인딩 파라미터 미지원). 양쪽 모두 작은따옴표 포함 CSV 형태 튜플. 치환 실패 시 MCP 호출 보류.

#### 포트폴리오 비중 가이드 (정성적, 슬롯별)

Scope 원칙 4 "슬롯별 비중 가이드 (정성적)"의 canonical 규칙. 스킬은 메인/와일드카드 리스트 산출 시 참고 비중을 병기한다 (강제 아님, 사용자 판단).

- **단일 종목 25% 초과 금지** (집중 리스크)
- **소형주(시총 상위 301위+)**: 포트폴리오 내 최대 1자리 종목 & 합계 15% 이하
- 수학적 포트폴리오 최적화(MVO, risk parity)는 out-of-scope — `financial-analyst` 스킬 영역.

### 리포트 팩트·공시 검색 상세 (Risk Flag 산출 지원)

이 섹션은 **Signal 스코어링 입력이 아니다**. 리포트 팩트의 "투자논리·리스크·해자" 항목과 위 "Risk Flag 산출" 절차의 Red 조건(단일제품 70%, 경영권 분쟁, 배당 제약, 감사의견 한정, 유상증자+적자, 특허소송, 관리종목)을 뒷받침할 근거 URL을 찾는 웹 검색 쿼리 가이드다.

**Search Targets:**
- `"{종목명} 실적"` — 실적 발표·가이던스 (투자논리 근거)
- `"{종목명} 수주"` — 신규 수주·계약 (투자논리 근거)
- `"{종목명} 신사업"` — 신규 사업 진출 (투자논리 근거)
- `"{종목명} 규제"` — 규제 리스크 (Risk Flag: 규제당국 조사 조건 확인용)
- `"{산업분류} 전망"` — 업종 전망 (해자·경쟁우위 근거)
- `"{종목명} 애널리스트"` — 증권사 의견·목표주가 (컨센서스 보조)
- `"{종목명} 유상증자"` / `"{종목명} 감사의견"` / `"{종목명} 경영권"` — Red Flag 조건 직접 검증

**결과 분류 (리포트 팩트로 병기, Signal 입력 아님):**
- **투자논리 근거 (긍정)**: 실적 개선, 수주 증가, 신규 진출, 배당 확대, 자사주 매입
- **리스크 근거 (Risk Flag 입력 후보)**: 실적 부진, 소송, 규제 강화, 대주주 지분 매도, 유상증자, 감사의견 한정, 단일 제품 의존
- **Watch (판단 보류)**: 경영진 교체, M&A 루머, 업종 재편 — Risk Flag는 None/Unknown으로 유지

위 항목 중 Red Flag 조건에 해당하는 근거가 확인되면 "Risk Flag 산출" 절차에 따라 Red로 분류하고 출처 URL을 기록한다. 단순 Watch 항목은 Risk Flag에 영향 없음.

### Report Structure (종목 추천 시)

**최종 결과는 메인 3개 TOP 10 + 와일드카드 3개 TOP 5로 제시한다 (대칭 구조).**

#### 커버리지 필터 (메인/와일드카드 공통)

리스트는 **`broker_count`** 기준으로 두 pool로 분리한 뒤, 각 pool 내에서 가치/성장/혼합 3분할을 동일하게 적용한다. 메인은 증권사 커버가 있어 목표가·괴리율·forward PER 등 제3자 검증이 가능하고, 와일드카드는 커버가 없어 자체 검증이 필요하다.

- **Covered pool**: `broker_count >= 1` — 메인 3개 TOP 10 대상
- **Uncovered pool**: `broker_count IS NULL OR broker_count = 0` — 와일드카드 3개 TOP 5 대상

#### 6개 리스트 정의 (메인 3 × 와일드카드 3, 대칭)

| 구분 | 리스트 | 대상 풀 | 정렬 기준 | 종목 수 | 컬럼 |
|:----:|--------|:-------:|----------|:-------:|------|
| 메인 | **가치 TOP 10** | Covered | `score_value` 내림 | 10 | 산업분류, sv, sg, avg, ROE(연결/별도), fwdROE, PER, fwdPER, PBR, DIV, 부채(연결/별도), 괴리%, 매수, F-Score, label |
| 메인 | **성장 TOP 10** | Covered | `score_growth` 내림 | 10 | 산업분류, sv, sg, avg, ROE(연결/별도), fwdROE, PER, fwdPER, CAGR, ROE변화, OPM변화, 괴리%, 매수 |
| 메인 | **혼합 TOP 10** | Covered | 가치+성장 합집합 중 `avg=(sv+sg)/2` 내림 | 10 | 산업분류, sv, sg, avg, ROE(연결/별도), fwdROE, PER, fwdPER, DIV, 괴리%, 매수, **CV%, Core/Sat**, 출처, 리포트1줄 |
| 와일드 | **와일드카드-가치 TOP 5** | Uncovered | `score_value` 내림 | 5 | 산업분류, sv, sg, ROE(별도), PER, PBR, DIV, 시총, 주요 테마, 웹 검색 1줄 |
| 와일드 | **와일드카드-성장 TOP 5** | Uncovered | `score_growth` 내림 | 5 | 산업분류, sv, sg, ROE(별도), PER, CAGR, OPM변화, 시총, 주요 테마, 웹 검색 1줄 |
| 와일드 | **와일드카드-혼합 TOP 5** | Uncovered | 가치+성장 합집합 중 `avg=(sv+sg)/2` 내림 | 5 | 산업분류, sv, sg, avg, ROE(별도), PER, PBR, **CV%, Core/Sat**, 시총, 주요 테마, 웹 검색 1줄 |

**공통 선정 규칙 (6개 리스트 모두):**
- 지주왜곡 종목(`holding_distortion=TRUE`) 전부 제외
- 메인: 최소 기준 없음 — Covered pool 내 정렬 상위 10개 그대로
- 와일드카드: **`score_value >= 6.5`** (가치) / **`score_growth >= 6.5`** (성장) / **`avg >= 6.5`** (혼합) 중 해당 정렬 기준 점수가 이 이상만 후보. 5개 미만이면 "와일드카드-{구분} 후보 부족 ({N}개)" 명시 후 가능한 개수만 출력
- 와일드카드 정성 정보: 애널 리포트 부재이므로 **웹 검색으로 사업 모델·최근 실적·리스크 1~2줄 확인하여 병기**. Obsidian vault PDF가 있으면 참고 가능
- 와일드카드 공통 유의사항: `⚠️ 커버리지 없음 — 제3자 검증·목표가·괴리율·forward PER 전부 부재, 유동성 제한 가능`

**Core/Satellite 분류**: canonical source는 "Core-Satellite 분류 기준" 섹션 (영업이익 최근 3~4년 CV, Step 2d MCP 쿼리 계산, Unknown 3조건). 혼합 TOP 10(메인) + 혼합 TOP 5(와일드카드) 종목에 `Core`/`Satellite`/`Unknown` 라벨 표시.

**리포트 섹션:**

| # | 섹션 | 포함 내용 |
|---|------|----------|
| 1 | 가치 TOP 10 (메인) | Covered · sv 상위 + 리포트 팩트 |
| 2 | 성장 TOP 10 (메인) | Covered · sg 상위 + 리포트 팩트 |
| 3 | 혼합 TOP 10 (메인) | Covered · avg 상위 + Core/Satellite + 리포트 팩트 |
| 4 | **와일드카드-가치 TOP 5** | Uncovered · sv 상위 + 웹 검색 1줄 + ⚠️ 유의 |
| 5 | **와일드카드-성장 TOP 5** | Uncovered · sg 상위 + 웹 검색 1줄 + ⚠️ 유의 |
| 6 | **와일드카드-혼합 TOP 5** | Uncovered · avg 상위 + 웹 검색 1줄 + ⚠️ 유의 |
| 7 | Investment Signal | 메인 혼합 TOP 10 + 와일드카드 대상 Bullish/Neutral/Bearish + Confidence (와일드카드는 자동 1단계 하향) |
| 8 | Risk Factors | 종목별 + 섹터 집중도 리스크 + 와일드카드 공통 리스크(커버리지 부재) |

## 종합 스코어링 (Step 2d)

### 원칙
1. **Dim A는 R 스크립트가 산출** — `score_value`/`score_growth`는 R 스크립트가 계산한 최종값을 사용하며, 스킬(Codex)은 재계산하지 않는다. R 스크립트 내부에서는 아래 보정이 이미 적용된 값이므로 스킬 단계에서 추가 조정할 필요가 없다.
   **R 내부 보정 로직** (`screening_pipeline.R`):
   - (a) **별도재무 부채 override** (`screening_pipeline.R:567-569`): 연결 부채비율 > 150% AND 별도 부채비율 < 150% 인 종목은 `debt_override = TRUE` 플래그와 함께 `score_value += 1` (상한 10). 부채비율 단일 항목 교체가 아니라 **최종 `score_value` 값에 +1 가산**.
   - (b) **지주왜곡 감점** (`screening_pipeline.R:564-566`): `holding_distortion = TRUE` 인 종목(별도 적자 + 연결 흑자)은 `score_value -= 5` (하한 0).
   - (c) **Forward 지표 보정** (`screening_pipeline.R:756-772`): `broker_count ≥ FWD_MIN_BROKERS(=10)` AND `blended_PER > 0` 인 종목은 `PER := blended_PER`, `ROE := fwd_ROE` 로 교체 후 `score_value` 전체 재계산(대형주 대상).
   **스킬 측 예외** (Codex가 수행하는 유일한 보정):
   - (d) R 스크립트 실행 실패 → MCP fallback: 스킬이 하드필터 + 간이 스코어링 수행 (업종별 백분위 대신 전체 시장 백분위, Confidence 1단계 하향)
2. **모든 점수에 근거 필수** — 각 항목의 점수에 데이터 출처(DB 쿼리 결과, 웹 검색 URL, ETF 편입 사실 등)를 반드시 명시
3. **검증 불가 데이터 = 0점** — 추정/날조 금지. URL 없는 뉴스 인용 = 날조로 간주
4. **스코어링 구조 — A와 B 2차원만 사용** — A(정량, `score_value`/`score_growth`)와 B(테마 라벨)만 사용. 리포트 팩트는 병기 메타데이터(스코어링 아님). 사용자 가중치 조정은 지원하지 않음 — 순위는 `score_value`/`score_growth` 고정, Signal 판정에 Risk Flag만 보조 입력으로 사용

### 스코어링 차원

차원별 역할/스코어 여부는 **"2d. 종합 판정" 섹션의 차원 테이블**에 정의된다. 이 섹션에서는 각 차원의 **산식·데이터 소스** 만 정의한다 (역할·스코어 여부 중복 서술 제거).

**A. 정량 재무 (Quantitative Fundamentals)**
| 항목 | 측정 | 데이터 소스 |
|------|------|-----------|
| ROE | 수익성 | DB: `지배주주순이익 / 자본` |
| PER 적정성 | 밸류에이션 | DB: `시가총액 / 지배주주순이익` vs 동일 산업분류 평균 |
| PBR 적정성 | 자산 대비 가격 | DB: `시가총액 / 자본` vs 동일 산업분류 평균 |
| PCR(FCF) | 현금흐름 대비 가격 | DB: `시가총액 / 잉여현금흐름` (금융 제외) |
| 영업이익률 | 본업 수익성 | DB: `영업이익 / 매출액` |
| 부채비율 | 재무 건전성 | DB: `부채 / 자본` |
| 배당수익률 | 주주환원 | DB: `배당수익률` 컬럼 |
| 매출 성장 | 성장성 | DB: 연간재무제표 YoY 비교 |

점수 산출: 각 항목을 동일 산업분류 내 z-score로 변환 → `pnorm(z) × 10`으로 0~10점 스케일링. 극단값은 1st/99th 백분위로 winsorize. 소규모 업종(n < 10)은 전체 시장 z-score로 fallback. 업종 내 상대 평가이므로 반도체와 은행을 동일 기준으로 비교하는 문제가 해소되며, 백분위 대비 극단값의 차별력이 높음.

#### 컨센서스 필드 정의 (screening_result.json)

애널리스트 컨센서스 필드. R 스크립트가 `fnguide_consensus.R`로 fnguide를 크롤링하여 `screening_pipeline.R`에서 파생 필드를 계산한다. 용도는 (1) **A 스코어 보정** — `broker_count ≥ FWD_MIN_BROKERS(=10)`인 종목은 `blended_PER`/`fwd_ROE`로 `PER`/`ROE`를 교체한 뒤 `score_value`를 재산출 — 과 (2) **Signal 판정 보조 입력**(`broker_count`·`buy_ratio`) 및 (3) **커버리지 분리**(와일드카드/메인) 세 가지로 구분된다.

**컨센서스 원천 필드 (fnguide 크롤링, 기본 메타):**

| 필드 | 정의 | 산식/출처 | 타입 |
|------|------|----------|:----:|
| `broker_count` | 유효 목표주가(target_price > 0)를 제시한 증권사 수 | `fnguide_consensus.R` — `length(tp_valid)` | int |
| `opinion_buy` / `opinion_hold` / `opinion_sell` | 투자의견 Buy(RECOM_CD≥4) / Hold(=3) / Sell(≤2) 건수 | `fnguide_consensus.R` | int |
| `target_avg` / `target_gap` | 목표주가 평균 / 현재가 대비 괴리율(%) | `screening_pipeline.R` | float |
| `eps_fwd1` / `eps_fwd2` / `fwd_eps` | 당해/차기 예상 EPS 및 컨센서스 EPS | `fnguide_consensus.R` | float |

**파생 지표 (`screening_pipeline.R`에서 계산):**

| 필드 | 정의 | 산출 조건 | 용도 |
|------|------|----------|------|
| `buy_ratio` | 매수 의견 비율 (0~10 스케일, 소수 1자리): `round(opinion_buy / pmax(opinion_buy + opinion_hold + opinion_sell, 1) × 10, 1)` | `opinion_buy` NA 아닌 종목 | Signal threshold (`≥ 8` = 80% 이상) |
| `fwd_PER` | `round(현재가 / fwd_eps, 1)` | `fwd_eps > 0` AND 현재가 유효 | 리포트 병기 참조 (컬럼 fwdPER) |
| `fwd_ROE` | `round(fwd_eps × 발행주식수 / 자본 × 100, 1)` | `fwd_eps > 0` AND `자본 > 0` AND 현재가 유효 | 리포트 병기 참조 (컬럼 fwdROE) |
| `blended_eps` | 경과 월수 기반 FY1+FY2 가중평균 | `eps_fwd1` + `eps_fwd2` 모두 존재 | A 스코어 보정 입력 |
| `blended_PER` | `round(현재가 / blended_eps, 1)` | `blended_eps > 0` | **`broker_count ≥ 10`이면 `PER`에 대입 후 `score_value` 재계산** |

**A 스코어 보정 로직** (`screening_pipeline.R:759-772`):
- 적용 조건: `broker_count ≥ FWD_MIN_BROKERS(=10)` AND `blended_PER > 0`
- 교체: `PER := blended_PER`, `ROE := fwd_ROE` (fwd_ROE가 양수인 경우)
- 효과: 위 종목은 A 차원 `score_value`가 컨센서스 forward 지표를 반영한 값으로 재산출됨. 나머지 종목은 원본 DB PER/ROE 기반 스코어 유지.

**Signal 판정 threshold 매핑**: `buy_ratio ≥ 8`은 매수 의견 비율 80% 이상, `broker_count ≥ 5`는 목표주가를 제시한 증권사 5곳 이상, `broker_count ≥ 10`은 **A 스코어 보정 적용** 종목군.

**B. 테마/정책 (Thematic & Policy) — 라벨링만, 점수화 없음**

테마는 **밸류업(고정) + 동적 테마(실행 시점 직전 3개월 기반)**로 구성. Step 2a에서 발견된 테마 목록을 사용. B차원은 **종목별 테마 라벨 부착만 수행하며 순위·Signal 가중치에 포함되지 않는 참조 메타데이터**이다.

| 라벨 | 조건 (해당 시 라벨 부착) | 데이터 소스 |
|------|------------------------|-----------|
| `밸류업` (고정) | 밸류업 지수/ETF 편입 OR PBR < 1.0 대형주 | ETF 구성종목 스캔 (웹 검색) + DB |
| `테마:{테마명}` | Step 2a에서 발견된 동적 테마 ETF에 편입, 혹은 산업분류·매출 비중 50%+ | Step 2a Phase 2 ETF 스캔 |
| `주주환원` | 저PBR + 자사주 보유/소각 공시 | DB PBR + DART 공시 |
| `수급-외인/기관` | 최근 순매수 우세 (참조용, 라벨만) | 웹 검색 |

**B 차원 라벨은 Signal 판정·순위 산출에 수치로 반영되지 않는다.** 독자가 "이 종목이 어떤 테마에 해당하는지"를 한눈에 보고 개인 포트폴리오를 구성할 때 참고하는 메타데이터일 뿐이다. 점수 배점(과거 "10점 만점" 체계)은 제거되었다.

**C차원(정성 스코어링)은 사용하지 않는다.** 정성 판단은 사용자가 리포트 팩트를 보고 직접 수행한다. Signal 판정에서는 리포트 팩트를 아래 "Risk Flag 산출" 절차로 Red/None/Unknown 3단계로 이진화한 값만 사용한다.

### Risk Flag 산출 (리포트 팩트 기반)

각 종목의 리포트 팩트(위 "리포트 팩트" 항목)에서 아래 조건 중 하나라도 해당하면 **Red**. 없으면 **None**. 리포트·공시·뉴스 모두 확인 불가하면 **Unknown**.

**Red Flag 조건 (명시적 구조적 리스크 — 출처 URL 필수):**
- 단일 제품/거래처 매출 비중 ≥ 70% (예: SK바이오팜 엑스코프리 95%)
- 경영권 분쟁 / 대주주 지분 소송 (예: 오스코텍 제노스코 합병 불확실성)
- 배당 제약 (보험업 자본비율 규제, 누적 결손금, 배당 0원 예정 공시)
- 최근 2년 내 감사의견 한정 / 부적정 / 의견거절
- 유상증자 + 영업이익 적자 병존 (최근 2년 내)
- 핵심 특허 소송 / 규제당국 조사 (진행 중)
- 관리종목 / 거래정지 이력 (최근 1년 내)
- PBR ≥ 5 + fwd PER ≥ 30 (과열 가능 — 다만 단독으로는 Red 불가, 다른 조건 1개 이상 동반 시만)

**출처 필수**: 각 Red Flag는 리포트 본문 또는 DART 공시·웹 검색 URL을 동반해야 한다. 출처 없는 추정 = Red Flag 인정 안 함(None으로 분류).

**결측 처리**: 리포트·공시·뉴스 모두 확인 불가 시 `Unknown` + Confidence 1단계 하향.

**Signal 효과**: Risk Flag 값(`Red` / `None` / `Unknown`)은 **"Investment Signal 판정 규칙" 섹션**(아래 참조)에서 Signal 등급 강제 하향 및 Confidence 하향의 보조 입력으로 사용된다. Red/None/Unknown → Signal/Confidence 매핑은 해당 섹션의 단일 표에서만 정의하며 여기서는 중복 기술하지 않는다.

### 리포트 팩트 (추가 보조 항목)

→ 리포트 팩트 canonical 스키마는 **"2b. 리포트 팩트 추출" 섹션의 canonical 7필드 테이블**을 참조하라. 이 섹션은 해당 스키마에 포함되지 않은 **추가 보조 항목** 두 가지만 정의한다.

| 항목 | 내용 | 소스 | 비고 |
|------|------|------|------|
| 주주환원 팩트 | 자사주 취득/처분, 배당 증감, 밸류업 공시 | DART 공시 | B 차원 `주주환원` 라벨 부착 근거 |
| 내부자 매매 | 임원 순매수/매도 | DART 지분공시 | 참조용, Signal 가중치 없음 |

**데이터 수집**: `python script/qualitative_pipeline.py --codes-file screening_result.json --top 30 --count 10`
**팩트 추출**: Codex 파일/PDF 읽기 기능으로 Obsidian vault의 PDF 직접 읽기 (정규식 기반 자동 추출 미사용 — "2b. 리포트 팩트 추출" 섹션 참조)

**qualitative_pipeline.py 주요 함수 시그니처** (실제 파일 기준):
```python
# 종목별 fnguide 컨센서스 조회 (HTTP)
def get_fnguide_consensus(code: str) -> dict | None
# DART + 리포트 + 컨센서스를 종목 단위로 수집·저장
def process_stock(code: str, name: str, api_key: str, report_count: int = 5)
# screening_result.json에서 상위 N 종목 로드
def load_codes_from_screening(json_path: str, top_n: int = 30) -> list[tuple[str, str]]
```

**qualitative_pipeline.py CLI 인자 → 내부 함수 매핑**:

| CLI 인자 | 타입 | 기본값 | 내부 매핑 | 설명 |
|----------|------|:------:|-----------|------|
| `--codes` | str | — | `code_list = codes.split(",")` | 쉼표 구분 종목코드 직접 지정 (예: `005930,000660`) |
| `--codes-file` | str | — | `load_codes_from_screening(path, top_n)` | screening_result.json 경로, `--codes`와 상호 배타 |
| `--top` | int | 30 | `top_n` 인자 | JSON에서 상위 N개 추출 |
| `--count` | int | 10 | `process_stock(..., report_count=count)` | 종목당 다운로드할 리포트 수 |

**dart_disclosures.py 주요 함수**:
```python
def load_api_key(config_path: str = "~/config.json") -> str
def stock_code_to_corp_code(stock_code: str, api_key: str) -> str
def get_treasury_stock_status(api_key, corp_code, bsns_year, reprt_codes=None)
def get_executive_shareholder_report(api_key, corp_code)
def get_dart_disclosures(corp_code, api_key, start_date, end_date, bsns_year=None)
# 편의 래퍼 (qualitative_pipeline.py가 직접 호출)
def get_dart_disclosures_by_stock_code(stock_code, api_key, start_date, end_date, bsns_year=None)
```

**get_fnguide_consensus 반환 dict 스키마** (fnguide_consensus.R JSON 출력을 그대로 래핑, nested 구조):
```python
{
  "opinion":      {"avg_score": float, "buy": int, "hold": int, "sell": int, "total": int},
  "target_price": {"avg": float, "max": float, "min": float, "broker_count": int},
  "eps":          [{"period": str, "value": float}, ...],      # 연간 EPS 예상 (FY1, FY2 ...)
  "revenue":      [{"period": str, "value": float}, ...],      # 연간 매출 예상
  "op_income":    [{"period": str, "value": float}, ...],      # 연간 영업이익 예상
  "quarterly":    [{"period": str, "revenue": float, "op_income": float,
                   "net_income": float, "eps": float, "type": str}, ...],  # 분기 컨센서스
}
```
screening_pipeline.R가 이 nested 구조를 flatten하여 screening_result.json에 `broker_count`, `opinion_buy`, `target_avg`, `eps_fwd1/2`, `fwd_eps`, `fwd_oi` 등 최상위 필드로 저장한다 (flat 필드명은 "컨센서스 필드 정의" 섹션 참조).
**저장 위치**: Obsidian vault `StockAnalysis/consensus/`, `StockAnalysis/reports/`

### 스코어링 체계

→ **canonical 정의는 "종합 스코어링 (Step 2d)" 섹션의 "2d. 종합 판정" 테이블을 단일 source of truth로 사용한다.** 차원별 역할/스코어 여부는 그 표만 참조하고 이 섹션에서는 중복 기술하지 않는다. 요약: 순위는 A차원(`score_value`/`score_growth`) 단독 결정, B/리포트 팩트/Risk Flag는 모두 스코어 대상 아님.

### 최종 순위 산출 프로세스

Step 번호는 "Step 번호 범례" 섹션과 일치하는 의미로 사용한다 (아래 숫자는 실행 순서).

```
1. Step 1:  R 스크립트 → ~330개 후보 (score_value, score_growth, forward PER/ROE, F-Score, 별도재무, broker_count)
2. Step 2a: 테마 태깅 → 밸류업(고정) + 동적 테마 라벨 (330개 전체)
3. Step 2a': 커버리지 분리 (지주왜곡=TRUE 양쪽 제외)
   - Covered pool   = broker_count >= 1                        (메인 3개 TOP 10 대상)
   - Uncovered pool = broker_count NULL/0                      (와일드카드 3개 TOP 5 대상)
4. Step 2b: 리포트 팩트 추출 (canonical 7필드 스키마, "2b. 리포트 팩트 추출" 섹션 참조)
   - Covered 메인 3개 합집합(~25개): Obsidian PDF 읽기 (Codex 파일/PDF 읽기 기능)
   - Uncovered 와일드카드 3개 합집합(~10개): 웹 검색 1~2줄
5. Step 2c: 별도재무 확인 (연결 부채비율 > 150%인 종목만) → `sep_DEBT` override
6. Step 2d: 종합 판정 + 6개 리스트 산출 + Signal/Confidence (메인 3 × 와일드카드 3 대칭)
   - 메인 가치 TOP 10       = Covered · score_value 내림
   - 메인 성장 TOP 10       = Covered · score_growth 내림
   - 메인 혼합 TOP 10       = Covered 합집합 · avg=(sv+sg)/2 내림 + Core/Satellite
   - 와일드카드 가치 TOP 5  = Uncovered · score_value 내림 (sv >= 6.5 기준)
   - 와일드카드 성장 TOP 5  = Uncovered · score_growth 내림 (sg >= 6.5 기준)
   - 와일드카드 혼합 TOP 5  = Uncovered 합집합 · avg 내림 (avg >= 6.5 기준) + Core/Satellite
   - 와일드카드 공통: + 웹 검색 1줄 + ⚠️ 커버리지 부재 유의
   - **CV MCP 쿼리 단계** (혼합 TOP 10/5 확정 후): 혼합 리스트 최대 15개 종목코드로 `stocks-db` MCP에 CV 계산 SQL 1회 실행 → `cv_opm` 반환 → `Core` (≤40) / `Satellite` (>40) / `Unknown` (3조건 중 하나) 라벨 부착. canonical source: "Core-Satellite 분류 기준" 섹션.
7. Step 2e: Obsidian vault 필수 저장 → 일반 스크리닝은 `~/Documents/Obsidian Vault/StockAnalysis/screening/{YYYY-MM-DD}_스크리닝_리포트.md`, 포트폴리오/리밸런싱 요청은 `~/Documents/Obsidian Vault/StockAnalysis/screening/{YYYY-MM-DD}_포트폴리오_리밸런싱_리포트.md`
8. 사용자가 메인 + 와일드카드를 함께 보고 직접 포트폴리오 구성
```

### 출력 형식

→ 리스트 컬럼 및 구조는 **"#### 6개 리스트 정의" 섹션을 canonical source**로 참조한다. 이 섹션은 **각 리스트에 공통으로 병기되는 리포트 팩트** 포맷만 정의한다.

**각 리스트의 종목에 병기되는 리포트 팩트** (메인 3개 섹션=가치/성장/혼합 TOP 10은 Obsidian PDF 읽기, 와일드카드 3개 섹션=가치/성장/혼합 TOP 5는 웹 검색 1~2줄):
- 밸류에이션 근거 (방법론 + 목표가)
- 투자논리 (핵심 카탈리스트 1~3개, 구체적 수치)
- 리스크 (구체적 목록)
- 해자/경쟁우위

**최종 출력물은 Obsidian vault에 마크다운 파일로 저장한다. 사용자가 명시적으로 저장 생략을 요청하지 않은 한 이 단계는 필수다.**
- 일반 스크리닝: `~/Documents/Obsidian Vault/StockAnalysis/screening/{YYYY-MM-DD}_스크리닝_리포트.md`
- 포트폴리오/리밸런싱: `~/Documents/Obsidian Vault/StockAnalysis/screening/{YYYY-MM-DD}_포트폴리오_리밸런싱_리포트.md`
- 동일 경로가 있으면 `_v2`, `_v3` 접미사를 붙여 기존 리포트를 덮어쓰지 않는다.

포트폴리오/리밸런싱 리포트에는 반드시 다음 항목을 포함한다:
- 분석 기준일과 DB/KIS 데이터 기준
- 현재 보유 종목, 수량, 평가금액, 현재 비중
- 현재 보유 종목과 스크리닝 상위 후보의 `score_value`, `score_growth`, `avg`
- 유지/축소/제거/신규편입 판단과 이유
- 종목 수 제한, 목표 비중, 리밸런싱 수량
- 분할매수 계획, RSI/기술적 기준, 사용한 웹 출처 URL
- Confidence와 제한사항

```
# 스크리닝 리포트 ({날짜})

## 가치주 TOP 10 (커버 종목)
| # | 종목 | sv | sg | avg | PER | fwdPER | DIV | ROE | 별도ROE | 괴리% | 매수 | F | label |
(정량 테이블, broker_count >= 1 필터)

### 가치주 리포트 팩트
**{종목명}** ({증권사} {날짜})
- 밸류에이션: ...
- 투자논리: ...
- 리스크: ...
- 해자: ...

## 성장주 TOP 10 (커버 종목)
(동일 구조)

## 혼합 TOP 10 (커버 종목)
(동일 구조 + Core/Satellite/Unknown 라벨 + 출처 컬럼 + 1줄 요약)
(Unknown 라벨은 공란 표시 + 각주 "CV 데이터 부족")

## 와일드카드-가치 TOP 5 (Uncovered)
| # | 종목 | 산업 | sv | sg | ROE(별도) | PER | PBR | DIV | 시총 | 테마 |
(broker NULL/0 · sv >= 6.5 · 내림 Top 5)

## 와일드카드-성장 TOP 5 (Uncovered)
| # | 종목 | 산업 | sv | sg | ROE(별도) | PER | CAGR | OPM변화 | 시총 | 테마 |
(broker NULL/0 · sg >= 6.5 · 내림 Top 5)

## 와일드카드-혼합 TOP 5 (Uncovered)
| # | 종목 | 산업 | sv | sg | avg | ROE(별도) | PER | PBR | CV% | Core/Sat | 시총 | 테마 |
(broker NULL/0 · avg >= 6.5 · 내림 Top 5. CV%/Core/Sat 모두 Unknown 시 두 컬럼 모두 공란 + 각주 "CV 데이터 부족")

### 와일드카드 종목 분석 (웹 검색 기반)
**{종목명}** [구분: V/G/M, {해당 리스트}]
- 사업: {웹 검색 사업 모델}
- 최근 실적: {YoY/QoQ 핵심 수치}
- 해당 테마: {AI반도체, 원전, 방산 등}
- 리스크: ⚠️ **커버리지 없음 — 목표가·괴리율·forward 전부 부재**, 소형주 유동성 제한 가능
```

## Investment Signal 판정 규칙

### Signal 결정 (Bullish / Neutral / Bearish)
A 정량 스코어(`score_value`/`score_growth`) 중심으로 판정. 매수 컨센서스(`broker_count`·`buy_ratio`)와 리포트 팩트의 Risk Flag(위 "Risk Flag 산출" 참조)를 보조 입력으로 사용. 정성(C) 스코어링은 사용하지 않는다.

**모집단 정의:**
- **스크리닝 경로** (Step 1→2): 모집단 = Step 2b 리포트 팩트 추출 대상 ~35개 (Covered TOP 10 합집합 ~25개 + Uncovered TOP 5 합집합 ~10개). "상위 20%"는 이 후보 풀 내 복합 스코어 백분위 기준이다.
- **소규모 모집단 (후보 ≤10건)**: 상대 순위만으로는 1~2종목에 과도한 의미 부여. 아래 **절대 기준을 병행** 적용하여 상대·절대 중 보수적 판정(둘 중 낮은 Signal)을 채택.
- **개별 종목 분석 (Step 2 직행)**: 비교 모집단 없음. 절대 기준만 적용.

#### 스크리닝 경로 Signal (상대 기준, 후보 >10건)

**우선순위 규칙**: 아래 표는 위에서 아래로 **첫 매칭** 사용. Risk Flag = Red는 A 상위 20%여도 Bullish 불가 — 반드시 Neutral 이하로 강등된다.

| 순번 | 조건 | Signal |
|:---:|------|--------|
| 1 | Risk Flag = Red **AND** A ≥ 4 (하위 40% 초과) | **Neutral** (Red Flag 강제 하향, 어떤 A여도 Bullish 불가) |
| 2 | Risk Flag = Red **AND** A < 4 (하위 40%) | **Bearish** |
| 3 | A 복합 스코어(`avg=(sv+sg)/2`) 상위 20% **AND** `broker_count` ≥ 5 **AND** `buy_ratio` ≥ 8 **AND** Risk Flag = None | **Bullish** |
| 4 | A 복합 스코어 상위 20% **AND** (`broker_count` < 5 **OR** `buy_ratio` < 8 **OR** Risk Flag = Unknown) | **Bullish** (Confidence 1단계 하향) |
| 5 | A 복합 스코어 중위 40~80% **OR** 차원 간 점수/리스크 상충 | **Neutral** |
| 6 | A 복합 스코어 하위 40% | **Bearish** |

#### 개별 종목 절대 기준 (Step 2 직행 또는 소규모 모집단 병행)

| 차원 | Bullish | Neutral | Bearish |
|------|---------|---------|---------|
| A 정량 재무 | ≥ 7/10 | 4~6/10 | < 4/10 |
| B 테마/정책 (참조용) | — (Signal 가중치 없음, 라벨만 병기) | — | — |
| 리포트 팩트 Risk Flag | None | Unknown | Red |
| **종합 판정** | A ≥ 7 **AND** Risk Flag = None | 위 외 전부 | A < 4 **OR** Risk Flag = Red |

- B 차원은 Signal 가중치가 없으므로 태깅 실패 자체는 Signal 판정에 영향이 없으나, 태마 라벨 병기가 완전히 누락된 경우(전 종목 B 누락) Confidence 1단계 하향(참조 정보 부족).
- `broker_count` = 0/NULL (와일드카드 Uncovered) 종목은 컨센서스 threshold를 적용할 수 없으므로, 절대 기준 표에 따라 판정하고 Confidence를 자동 1단계 하향한다.
- 소규모 모집단(≤10건)에서 상대 기준과 절대 기준이 상충 시 **보수적 판정** (둘 중 낮은 Signal) 적용.
- Red Flag + A ≥ 7 조합은 Bullish 불가 (Neutral로 강제 하향). 이 규칙이 "4/21 자동 threshold만으로 현대해상·SK바이오팜이 Bullish로 잘못 분류" 문제를 해소한다.

### 재무 점수
복합 스코어링 체계의 차원 A(정량 재무)를 사용한다. 별도의 고정 threshold 점수표를 사용하지 않는다.

## 데이터 무결성 규칙

**이 규칙은 스킬 전체에 적용되며, 모든 Phase에서 준수해야 한다.**

1. **DB 데이터만 재무 수치의 유일한 진실** — 재무 지표는 반드시 `stocks-db` 쿼리 결과를 사용. "대략", "약", "추정" 등으로 수치를 만들어내지 않는다
2. **웹 검색 결과는 출처 URL 필수** — 뉴스/전망/컨센서스 데이터는 반드시 웹 검색 또는 웹 fetch로 확인하고, 결과에 출처 URL을 포함. URL 없는 뉴스 인용 = 날조로 간주
3. **검증 불가 항목 = 0점** — DB에 데이터가 없거나, 웹 검색으로 확인할 수 없는 항목은 0점 처리하고 `⚠️ 데이터 없음`으로 표시. 절대 추정값을 채워넣지 않는다
4. **0점 항목 과다 시 재분석** — 한 종목에서 A 차원 항목 3개 이상이 0점이면 해당 종목을 순위에서 제외. 재분석 사유를 명시
5. **교차 검증** — DB 수치와 웹 뉴스의 수치가 크게 다르면(예: DB ROE 10% vs 뉴스 "ROE 30%"), 불일치를 명시하고 DB를 우선. 뉴스 수치가 더 최신이면 그 사실을 표기

### 분석 완성도 기준
| 지표 | 목표 | 측정 방법 | 판단 시점 | 미달 시 대응 |
|------|------|----------|----------|-------------|
| Step 완료율 | 2/2 Step 실행 | Step 1 JSON 생성 (종목 수 ≥ 1) + Step 2 리포트 작성 | Step 2 완료 직후 | Step 1 실패 → Error Handling R 스크립트 시나리오. Step 2 미완 → 가용 데이터로 부분 리포트 생성, Confidence 하향 |
| 데이터 커버리지 | 재무 점수 7항목 중 5개 이상 산출 | 종목별로 NULL이 아닌 A 차원 항목 수 카운트 | Step 2d 종합 판정 직전 | 5개 미만 종목은 순위에서 제외, 리포트에 "데이터 부재: {누락 항목}" 명시 |
| 리포트 섹션 완성 | Report Structure 8개 섹션 모두 작성 (메인 가치/성장/혼합 TOP 10 + 와일드카드 가치/성장/혼합 TOP 5 + Signal + Risk) | 각 섹션에 1개 이상의 데이터 행 또는 판정 결과 포함 | 리포트 출력 직전 | 빈 섹션 발생 시 "⚠️ 데이터 부족"으로 표시, Confidence 하향. 와일드카드 특정 구분(V/G/M)이 5개 미만이면 "와일드카드-{구분} 후보 부족 ({N}개)" 명시 후 가능한 개수만 출력 |
| 데이터 신선도 | 월별기업정보 35일, 분기재무제표 100일, 연간재무제표 380일 이내 | 테이블별 `MAX(일자)` SQL 쿼리 | Pre-check 단계 (Step 1 실행 전) | 초과 시 리포트 상단에 경고 표시 후 계속 진행. 전 테이블 초과 시 Confidence: N/A |

## Error Handling & Edge Cases

### DB 관련
| 시나리오 | 대응 |
|----------|------|
| stocks-db MCP 서버 미연결 | 사용자에게 `codex mcp list`로 확인 안내. 사용자가 종목을 직접 지정한 경우 웹 검색만으로 제한적 분석 가능 (Confidence 최대 Low, 재무 데이터 없음 명시). 스크리닝 요청이면 MCP 필수 안내 후 중단 |
| 종목코드 조회 결과 0건 | `WHERE 종목명 LIKE '%검색어%'`로 부분 매칭 시도. 0건이면 정확한 종목코드/종목명 재입력 요청 |
| 재무제표 데이터 누락 | 최소 요건: 매출액 + 영업이익 + 자본총계 중 2개 이상 존재해야 시그널 판정. 미충족 시 "Confidence: N/A". 충족 시 가용 데이터만 분석하되 리포트에 "데이터 부재: {누락 항목}" 명시 |
| DB 최신 데이터 경과 | 테이블별 경고 threshold — `월별기업정보`: 35일, `분기재무제표`: 100일, `연간재무제표`: 380일 초과 시 리포트 상단에 "⚠️ {테이블} 기준일: {일자} ({N}일 경과)" 경고 |
| SQL 쿼리 에러 | `information_schema.columns` 조회로 테이블 구조 재확인 후 쿼리 수정하여 1회 재시도. 재실패 시 `"⚠️ DB 쿼리 실패: {에러 메시지}. 해당 항목을 건너뜁니다."` 표시 후 가용 데이터만으로 진행 |

### 웹 검색 관련
| 시나리오 | 대응 |
|----------|------|
| 뉴스 검색 결과 0건 | Step 2b를 "뉴스 데이터 없음"으로 표시. Confidence 최대 Medium. 재무 데이터도 제한적이면 최대 Low |
| 최신 뉴스가 90일 이상 전 | "최근 뉴스 부재" 경고 + Confidence 1단계 하향 (High→Medium, Medium→Low). 단, Step 1 재무 점수에서 명확한 시그널이 있으면 하향 유지 가능 — 판단 근거를 리포트에 명시 |
| 리포트·공시·뉴스 내 긍정/부정 정보 병존 | Red Flag 조건 미충족 시 Risk Flag=Unknown, Signal은 A 기반 기본 판정에 Confidence 1단계 하향. 양측 근거를 리포트에 병기하고 사용자 판단에 위임 |

### Python 스크립트 관련

| 시나리오 | 대응 |
|----------|------|
| `ModuleNotFoundError: requests/bs4` | 사용자에게 `pip install requests beautifulsoup4` 안내 + 정성 데이터 수집 스킵 → 웹 검색 fallback (Confidence 1단계 하향) |
| Python < 3.10 | type hints 문법 오류 → Python 버전 업그레이드 안내, 임시로 정성 수집 스킵 |

### KIS Open API 관련
| 시나리오 | 대응 |
|----------|------|
| 토큰 발급 실패 (`access_token` 미반환) | `~/config.json`의 `api.account.prod.main.appkey`/`appsecret` 확인 안내. Confidence 미영향 — 기술적 분석은 부가 정보. 대신 "HTS/네이버 금융에서 직접 확인" 안내 |
| 레이트 리밋 (`EGW00201` 등) | 1회 재시도. 재실패 시 해당 종목만 기술적 지표 제외하고 나머지 계속 진행 |
| 일봉 데이터 결측 | 신규 상장·거래정지 가능성. 리포트에 "⚠️ 기술적 지표 조회 불가" 표시 |
| 장외 시간 현재가 요청 | 전일 종가 반환 (정상). 사용자에게 "장외 시간, 전일 종가 기준" 고지 |
| `kis_price.py` 미존재 | `script/Han2FunctionList.R`의 `getToken`·`getCurrentPrice` 함수 참조하여 생성 가능. 없으면 DB 월말 종가 fallback |

### R 스크립트 관련
| 시나리오 | 대응 |
|----------|------|
| 스크립트 실행 실패 | 1회 자동 재실행. 재실패 시 사용자에게 `"⚠️ R 스크립트 실행 실패: {에러 메시지 첫 줄}. DB 접속 → R 패키지 → config.json 순으로 확인해주세요."` 표시 후 MCP 직접 쿼리로 fallback (Confidence 1단계 하향) |
| screening_result.json 미생성 | 스크립트를 1회 재실행. 재실패 시 `"⚠️ 스크리닝 JSON 생성 실패. MCP 직접 쿼리로 전환합니다."` 표시 후 MCP fallback (하드필터만 적용, 스코어링은 스킬에서 수행, Confidence 1단계 하향) |
| 결과 종목 수 < 300 | DB 최신 일자 확인. 데이터 미갱신 가능성 → 사용자에게 InsertCorpData.R 실행 안내 |

### 입력 관련
| 시나리오 | 대응 |
|----------|------|
| 종목 미지정 + 조건 미지정 | "분석할 종목코드/종목명 또는 스크리닝 조건을 알려주세요." 안내 |
| 해외 종목 요청 | "이 skill은 KRX(KOSPI/KOSDAQ) 상장 종목만 지원합니다. KONEX는 유동성·재무 데이터 제한으로 미지원." 안내 |
| ETF/ETN 종목 요청 | 재무제표 기반 분석 불가 명시. 시가총액/가격 정보만 제공 가능 안내 |
| 우선주 (예: 삼성전자우) | 가격/시총/배당 데이터는 우선주 종목코드 기준, 재무제표는 보통주 기준으로 분석. 리포트에 "우선주 — 재무 데이터는 보통주({보통주코드}) 기준, 가격/배당은 우선주 기준" 명시 |

### 분석 로직 관련
| 시나리오 | 대응 |
|----------|------|
| 스크리닝 결과 50건 초과 | 사용자 스크리닝 조건의 주요 정렬 기준으로 상위 20개 제한 (정렬 기준 불명확 시 사용자에게 선택 요청). 결과 테이블 제공 후 추가 필터 또는 상세 분석 대상 선택 요청 |
| 신규 상장 (연간재무제표 2기 미만) | 가용 기간만 분석. 리포트에 "데이터 기간: {시작}~{끝} ({N}기)" 명시. Confidence 1단계 하향. Piotroski F-Score 산출 불가 시 해당 항목 제외하고 나머지로 재무 점수 산출 |
| 관리종목/거래정지 | DB `관리여부` 컬럼 확인 (값: `"관리종목"` / `"-"`). 관리종목이면 리포트에 "⚠️ 관리종목" 경고 부기. 투자 시그널 대신 현황 분석만 제공. 스크리닝 시 기본 제외 (`WHERE 관리여부 = '-'`) |
| Peer group 1-2개 이하 | "동일 산업분류 비교 대상 부족" 명시. 상위 산업분류로 확대하거나 시총 유사 종목으로 대체 |

### Confidence 결정 규칙
1. N/A 조건(재무 최소 요건 미충족, DB+뉴스 모두 부실)이 하나라도 해당 → **Confidence: N/A**
2. 그 외: 기본 High에서 하향 요인당 1단계 하향 (High→Medium→Low)
3. 하향 요인: 뉴스 0건(-1), 뉴스 90일+ 경과(-1), 신규 상장 3년 미만(-1), DB 불가 웹전용(-2), 테마 태깅 미실행(-1), PDF 읽기 대량 실패(-1) — "실행 패턴" 섹션의 연속 실패 중단 조건 참조
4. 최저 floor = Low (N/A 제외)

### 복합 시나리오
| 시나리오 | 대응 |
|----------|------|
| DB 경과 + 뉴스 0건 | 양쪽 데이터 모두 부실 — "현재 가용한 데이터가 충분하지 않습니다. DB 업데이트 후 재분석을 권장합니다." 안내. Confidence: N/A |
| 스크리닝 과다 + 재무제표 부분 누락 | 재무 데이터 최소 요건 미충족 종목을 우선 제외한 뒤 나머지로 순위 산출 |
| ETF 포함 스크리닝 | 스크리닝 결과에서 ETF/ETN 자동 제외. 사용자가 명시적으로 ETF를 요청한 경우만 시가총액/가격 정보 제공 |
| DB 경과 + 테마 태깅 불가 + 뉴스 0건 | 3중 데이터 소스 부실. Step 1 DB 데이터만으로 제한적 스크리닝 가능하나 Confidence: N/A. "DB 업데이트 후 재분석" 권장 |

## Scope

### 포함/제외 판단 원칙

1. **데이터 원칙**: stocks-db(재무제표) + 웹 검색(뉴스)로 분석 가능한 항목만 포함. 실시간 시세, 가격 시계열, 주문 실행이 필요한 분석은 제외.
2. **시장 원칙**: KRX(KOSPI/KOSDAQ) 상장 보통주/우선주만 대상. KONEX, 해외, 파생은 제외.
3. **분석 유형 원칙**: 펀더멘탈(재무제표 기반) + 뉴스 감성 분석만 수행. 기술적 분석(차트)과 정교한 수리 모델(DCF, 최적화)은 financial-analyst skill 영역.
4. **배분 vs 최적화 경계**: 스크리닝 결과의 슬롯별 비중 가이드(정성적 배분)는 포함. 수학적 포트폴리오 최적화(MVO, risk parity, 리밸런싱 시뮬레이션)는 제외.

### 포함 (In Scope)
- **시장**: KRX (KOSPI, KOSDAQ) 상장 보통주/우선주
- **분석 유형**: 펀더멘탈 분석 (재무제표 기반) + 뉴스 감성 분석 + **기술적 지표 (MCP 가용 시, 포트폴리오 확정 후 단계)**
- **데이터 소스**: stocks-db PostgreSQL (재무제표) + R 스크립트 (정량 스크리닝) + 웹 검색 (뉴스/감성) + **korea-stock-analyzer MCP (기술적 지표·수급·DCF, 선택적)**
- **출력**: 종목 스크리닝 테이블, 개별 종목 분석 리포트 (Investment Signal 포함), **최종 포트폴리오 제안 시 기술적 진입 포지션 참고 (이평선·RSI·MACD·수급)**
- **기술적 분석 범위**: MCP `get_technical_indicators` (이평선 5/20/60/120, RSI 14, MACD, 볼린저밴드) + `get_supply_demand` (외국인·기관·개인 수급). **스코어링·순위 산출에는 반영하지 않고 진입 타이밍 참고용으로만 사용**

### 인접 영역 판단

| 요청 유형 | 판정 | 근거 (원칙) |
|----------|------|------------|
| "삼성전자 vs SK하이닉스 비교" | **포함** | 개별 종목 분석의 병렬 실행 (원칙 1) |
| "반도체 산업 전망 분석" | **포함** (종목 없이도) | 웹 검색 기반 정성 분석 (원칙 1) |
| "삼성전자 ESG 분석" | **제외** | ESG 데이터가 DB에 없고 별도 프레임워크 필요 (원칙 1) |
| "이 스크리닝을 2023년에 적용하면?" | **제외** | 과거 시점 DB 스냅샷 불가, 백테스팅 인프라 필요 (원칙 1) |
| "삼성전자 DCF 해줘" | **제외** → financial-analyst | 수리 모델(DCF)은 원칙 3 해당 |
| "10종목 리밸런싱해줘" | **제외** → financial-analyst | 수학적 최적화는 원칙 4 해당 |

### 제외 (Out of Scope)
| 제외 항목 | 이유 | 원칙 |
|----------|------|------|
| 해외 주식 (미국, 중국 등) | DB에 KRX 데이터만 존재 | 2 |
| KONEX 종목 | 유동성·재무 데이터 부족 | 2 |
| ETF/ETN/ELW | 재무제표 기반 분석 불가 (발행사 구조 상이) | 1 |
| 기술적 분석 (캔들 패턴·엘리엇 파동·일봉 차트 이미지 판독) | KIS API 제공 범위 초과 (이평선·RSI·수익률만 계산) | 3 |
| MACD·볼린저밴드·스토캐스틱 | 기본 Python만으로 미지원 (pandas-ta 설치 시 확장 가능) | 3 |
| 수급 분석 (외국인·기관·개인 순매수) | KIS API 제공되나 `kis_price.py`에 미구현 (확장 필요) | - |
| 매매 주문 실행 | 분석/추천만 제공, 실제 거래 수행 안 함 | 1 |
| 실시간 호가창·틱 데이터 | KIS API는 일봉 종가 기준, 장중 실시간 호가 미제공 | 1 |
| 암호화폐/선물/옵션 | DB 범위 외 | 2 |
| 포트폴리오 최적화 (MVO, 리밸런싱) | 수학적 최적화는 financial-analyst 영역 | 4 |
| 세금/수수료 계산 | 개인별 조건 상이, 범위 외 | — |

### financial-analyst skill과의 경계
| stock-analyzer | financial-analyst |
|---------------|-------------------|
| 한국 주식 종목 발굴/분석 | 범용 재무 모델링 (DCF, 예측) |
| DB + 뉴스 결합 | JSON 입력 기반 계산 |
| Investment Signal 판정 | 밸류에이션 레인지 산출 |
| 한국어 뉴스 감성 분석 | 예산 편차 분석, 롤링 예측 |
| 슬롯별 비중 가이드 (정성적) | 포트폴리오 최적화 (수학적) |

## 확장 가이드

스킬 수정 시 변경해야 할 위치 체크리스트:

**새 데이터 소스 추가 시:**
1. Data Sources 섹션에 전제조건/방법/fallback 기술
2. Error Handling에 해당 소스 실패 시나리오 추가
3. Scope 포함(In Scope) 데이터 소스 목록 업데이트
4. 해당 소스를 사용하는 Phase에 입력/처리/출력 반영

**R 스크립트 스코어링 변경 시:**
1. `script/screening_pipeline.R`의 해당 스코어 섹션 수정
2. 이 문서의 "가치 스코어" 또는 "성장 스코어" 테이블 업데이트
3. 테스트 실행하여 주요 종목 포함 여부 확인

**새 스코어링 차원 추가 시:**
1. 종합 스코어링 체계에 차원 테이블 추가 (항목/측정/데이터소스)
2. 순위 산식 영향 평가: 새 차원이 (a) `score_value`/`score_growth`에 포함되는지, (b) Risk Flag 산출 조건에 포함되는지, (c) 병기 메타데이터인지 결정 후 해당 섹션에 반영
3. Step 2의 어느 단계에서 산출되는지 명시
4. 스코어카드 출력 형식에 차원 행 추가
5. Signal 판정 규칙(스크리닝 경로 표 + 개별 종목 절대 기준 표)에 신규 차원 반영 여부 결정
