#!/usr/bin/env python3
"""
KIS (한국투자증권) Open API 기반 실시간 시세 및 기술적 지표 계산.

참조: script/Han2FunctionList.R의 getToken(), getCurrentPrice()
확장: 일봉 시세 조회 (inquire-daily-itemchartprice) + 이평선·RSI 계산

사용:
    python kis_price.py 005930 000660 095610  # 여러 종목 일괄 조회
"""

import json
import os
import sys
import time
import requests
from datetime import datetime, timedelta
from pathlib import Path

CONFIG_PATH = os.path.expanduser("~/config.json")
TOKEN_CACHE = Path("/tmp/kis_token.json")


def load_config():
    with open(CONFIG_PATH) as f:
        return json.load(f)


def get_token(api_url: str, app_key: str, app_secret: str) -> str:
    """OAuth 토큰 발급 (24시간 캐시)."""
    if TOKEN_CACHE.exists():
        cached = json.loads(TOKEN_CACHE.read_text())
        if cached.get("app_key") == app_key and cached.get("expires_at", 0) > time.time() + 60:
            return cached["access_token"]

    resp = requests.post(
        f"{api_url}/oauth2/tokenP",
        json={"grant_type": "client_credentials", "appkey": app_key, "appsecret": app_secret},
        timeout=10,
    )
    data = resp.json()
    if "access_token" not in data:
        raise RuntimeError(f"토큰 발급 실패: {data}")

    TOKEN_CACHE.write_text(json.dumps({
        "app_key": app_key,
        "access_token": data["access_token"],
        "expires_at": time.time() + 23 * 3600,
    }))
    return data["access_token"]


def get_current_price(api_url: str, app_key: str, app_secret: str, token: str, code: str) -> dict:
    """실시간 현재가."""
    resp = requests.get(
        f"{api_url}/uapi/domestic-stock/v1/quotations/inquire-price",
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {token}",
            "appkey": app_key,
            "appsecret": app_secret,
            "tr_id": "FHKST01010100",
        },
        params={"FID_COND_MRKT_DIV_CODE": "J", "FID_INPUT_ISCD": code},
        timeout=10,
    )
    data = resp.json()
    if data.get("rt_cd") != "0":
        return {"error": data.get("msg1", "unknown")}

    o = data["output"]
    return {
        "current": int(o["stck_prpr"]),
        "change": int(o["prdy_vrss"]),
        "change_pct": float(o["prdy_ctrt"]),
        "volume": int(o["acml_vol"]),
        "high_52w": int(o["w52_hgpr"]),
        "low_52w": int(o["w52_lwpr"]),
        "market_cap": int(o.get("hts_avls", 0)) * 100_000_000,  # 억 단위
        "per": float(o.get("per", 0)) if o.get("per") not in (None, "", "0") else None,
        "pbr": float(o.get("pbr", 0)) if o.get("pbr") not in (None, "", "0") else None,
        "eps": float(o.get("eps", 0)) if o.get("eps") else None,
    }


def get_daily_chart(api_url: str, app_key: str, app_secret: str, token: str, code: str, days: int = 150) -> list:
    """일봉 OHLCV 조회 (최대 100일, 그 이상은 여러 번 호출)."""
    end = datetime.now()
    start = end - timedelta(days=int(days * 1.5) + 30)  # 주말/공휴일 고려

    resp = requests.get(
        f"{api_url}/uapi/domestic-stock/v1/quotations/inquire-daily-itemchartprice",
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {token}",
            "appkey": app_key,
            "appsecret": app_secret,
            "tr_id": "FHKST03010100",
        },
        params={
            "FID_COND_MRKT_DIV_CODE": "J",
            "FID_INPUT_ISCD": code,
            "FID_INPUT_DATE_1": start.strftime("%Y%m%d"),
            "FID_INPUT_DATE_2": end.strftime("%Y%m%d"),
            "FID_PERIOD_DIV_CODE": "D",
            "FID_ORG_ADJ_PRC": "0",
        },
        timeout=10,
    )
    data = resp.json()
    if data.get("rt_cd") != "0":
        return []

    rows = data.get("output2", [])
    # KIS는 최신 먼저 반환 → 오래된 순으로 정렬
    ohlcv = []
    for r in reversed(rows):
        if not r.get("stck_bsop_date"):
            continue
        ohlcv.append({
            "date": r["stck_bsop_date"],
            "open": int(r["stck_oprc"]),
            "high": int(r["stck_hgpr"]),
            "low": int(r["stck_lwpr"]),
            "close": int(r["stck_clpr"]),
            "volume": int(r["acml_vol"]),
        })
    return ohlcv


def calculate_indicators(ohlcv: list) -> dict:
    """
    기술적 지표 계산: 이평선(5/20/60/120), RSI(14), 수익률, 52주 고/저.
    """
    if len(ohlcv) < 5:
        return {"error": "데이터 부족"}

    closes = [x["close"] for x in ohlcv]
    current = closes[-1]
    latest_date = ohlcv[-1]["date"]

    def ma(n):
        if len(closes) < n:
            return None
        return sum(closes[-n:]) / n

    def rsi(n=14):
        if len(closes) < n + 1:
            return None
        gains = []
        losses = []
        for i in range(-n, 0):
            diff = closes[i] - closes[i - 1]
            if diff > 0:
                gains.append(diff)
            else:
                losses.append(-diff)
        avg_gain = sum(gains) / n if gains else 0
        avg_loss = sum(losses) / n if losses else 0
        if avg_loss == 0:
            return 100.0
        rs = avg_gain / avg_loss
        return round(100 - 100 / (1 + rs), 1)

    def return_n(n):
        if len(closes) < n + 1:
            return None
        past = closes[-n - 1]
        return round((current - past) / past * 100, 1)

    ma5 = ma(5)
    ma20 = ma(20)
    ma60 = ma(60)
    ma120 = ma(120)

    # 52주 고/저 (최대 252거래일)
    recent = closes[-min(252, len(closes)):]
    high_52w = max(recent)
    low_52w = min(recent)

    return {
        "latest_date": latest_date,
        "current": current,
        "ma5": int(ma5) if ma5 else None,
        "ma20": int(ma20) if ma20 else None,
        "ma60": int(ma60) if ma60 else None,
        "ma120": int(ma120) if ma120 else None,
        "rsi14": rsi(14),
        "high_52w": high_52w,
        "low_52w": low_52w,
        "from_52w_high_pct": round((current - high_52w) / high_52w * 100, 1),
        "from_52w_low_pct": round((current - low_52w) / low_52w * 100, 1),
        "vs_ma5_pct": round((current / ma5 - 1) * 100, 1) if ma5 else None,
        "vs_ma20_pct": round((current / ma20 - 1) * 100, 1) if ma20 else None,
        "vs_ma60_pct": round((current / ma60 - 1) * 100, 1) if ma60 else None,
        "vs_ma120_pct": round((current / ma120 - 1) * 100, 1) if ma120 else None,
        "return_5d": return_n(5),
        "return_20d": return_n(20),
        "return_60d": return_n(60),
        "return_120d": return_n(120),
        "data_days": len(closes),
    }


def analyze_ticker(code: str, api_url: str, app_key: str, app_secret: str, token: str) -> dict:
    """종목 1개 종합 분석."""
    price = get_current_price(api_url, app_key, app_secret, token, code)
    time.sleep(0.1)  # rate limit 여유
    ohlcv = get_daily_chart(api_url, app_key, app_secret, token, code, days=150)
    indicators = calculate_indicators(ohlcv)

    return {
        "code": code,
        "price": price,
        "indicators": indicators,
    }


def technical_signal(ind: dict) -> str:
    """기술적 진입 시그널 판정."""
    if "error" in ind:
        return "데이터 부족"

    current = ind["current"]
    rsi = ind.get("rsi14", 50)
    vs_ma20 = ind.get("vs_ma20_pct") or 0
    vs_ma60 = ind.get("vs_ma60_pct") or 0
    from_high = ind.get("from_52w_high_pct", 0)

    signals = []
    if rsi and rsi < 30:
        signals.append("과매도")
    elif rsi and rsi > 70:
        signals.append("과매수")

    if from_high < -15:
        signals.append("눌림목")
    elif from_high > -3:
        signals.append("52주고점근접")

    if vs_ma20 < -5 and vs_ma60 > 0:
        signals.append("단기조정·중기상승")
    elif vs_ma20 > 0 and vs_ma60 > 0 and vs_ma20 < vs_ma60:
        signals.append("상승추세")
    elif vs_ma20 < 0 and vs_ma60 < 0:
        signals.append("하락추세")

    return " / ".join(signals) if signals else "중립"


def main():
    if len(sys.argv) < 2:
        print("Usage: python kis_price.py <code1> <code2> ...")
        sys.exit(1)

    cfg = load_config()
    prod = cfg["api"]["config"]["prod"]
    main_acc = cfg["api"]["account"]["prod"]["main"]

    api_url = prod["url"]
    app_key = main_acc["appkey"]
    app_secret = main_acc["appsecret"]

    token = get_token(api_url, app_key, app_secret)
    print(f"Token: {token[:20]}...", file=sys.stderr)

    results = {}
    for code in sys.argv[1:]:
        try:
            r = analyze_ticker(code, api_url, app_key, app_secret, token)
            r["signal"] = technical_signal(r["indicators"])
            results[code] = r
            time.sleep(0.15)
        except Exception as e:
            results[code] = {"error": str(e)}

    print(json.dumps(results, ensure_ascii=False, indent=2, default=str))


if __name__ == "__main__":
    main()
