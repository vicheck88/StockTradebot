#!/usr/bin/env python
"""29개 선정 종목 기술 지표 일괄 산출 (pykrx 직접 호출)."""
from __future__ import annotations

import json
import os
from datetime import datetime, timedelta
from pathlib import Path

# KRX 환경변수 설정 (pykrx 1.2.7 로그인 경고 회피)
config = json.loads(Path.home().joinpath("config.json").read_text())
os.environ.setdefault("KRX_ID", config["krx"]["id"])
os.environ.setdefault("KRX_PW", config["krx"]["password"])

import numpy as np
import pandas as pd
from pykrx import stock

CODES = [
    ("000240", "한국앤컴퍼니"), ("000270", "기아"), ("000660", "SK하이닉스"),
    ("000990", "DB하이텍"), ("001450", "현대해상"), ("003230", "삼양식품"),
    ("005690", "파미셀"), ("005830", "DB손해보험"), ("005930", "삼성전자"),
    ("006910", "보성파워텍"), ("017510", "세명전기"), ("017670", "SK텔레콤"),
    ("017800", "현대엘리베이터"), ("021240", "코웨이"), ("023590", "다우기술"),
    ("030000", "제일기획"), ("039200", "오스코텍"), ("055550", "신한지주"),
    ("064350", "현대로템"), ("065710", "서호전기"), ("071050", "한국금융지주"),
    ("082920", "비츠로셀"), ("088130", "동아엘텍"), ("089970", "브이엠"),
    ("095610", "테스"), ("096530", "씨젠"), ("161390", "한국타이어앤테크놀로지"),
    ("171090", "선익시스템"), ("192400", "쿠쿠홀딩스"), ("206650", "유바이오로직스"),
    ("267260", "HD현대일렉트릭"), ("278470", "에이피알"), ("326030", "SK바이오팜"),
    ("417790", "트루엔"),
]


def rsi(series: pd.Series, period: int = 14) -> float:
    delta = series.diff()
    gain = delta.clip(lower=0)
    loss = -delta.clip(upper=0)
    avg_gain = gain.ewm(alpha=1 / period, adjust=False, min_periods=period).mean()
    avg_loss = loss.ewm(alpha=1 / period, adjust=False, min_periods=period).mean()
    rs = avg_gain / avg_loss.replace(0, np.nan)
    return float((100 - 100 / (1 + rs)).iloc[-1])


def macd(series: pd.Series):
    ema12 = series.ewm(span=12, adjust=False).mean()
    ema26 = series.ewm(span=26, adjust=False).mean()
    macd_line = ema12 - ema26
    signal = macd_line.ewm(span=9, adjust=False).mean()
    return float(macd_line.iloc[-1]), float(signal.iloc[-1]), float((macd_line - signal).iloc[-1])


def analyze(ticker: str, name: str, end: str, start: str) -> dict:
    df = stock.get_market_ohlcv(start, end, ticker, adjusted=True)
    if df.empty or len(df) < 60:
        return {"종목코드": ticker, "종목명": name, "error": "데이터 부족"}
    close = df["종가"].astype(float)
    vol = df["거래량"].astype(float)
    cur = float(close.iloc[-1])
    ma20 = float(close.rolling(20).mean().iloc[-1])
    ma60 = float(close.rolling(60).mean().iloc[-1])
    ma120 = float(close.rolling(120).mean().iloc[-1]) if len(close) >= 120 else None
    std20 = float(close.rolling(20).std().iloc[-1])
    bb_pos = (cur - ma20) / std20 if std20 else None
    macd_line, signal, hist = macd(close)
    rsi14 = rsi(close, 14)
    high_52w = float(close.tail(250).max()) if len(close) >= 250 else float(close.max())
    low_52w = float(close.tail(250).min()) if len(close) >= 250 else float(close.min())
    pos_52w = (cur - low_52w) / (high_52w - low_52w) * 100 if high_52w > low_52w else None
    vol_ratio = float(vol.tail(5).mean()) / float(vol.tail(60).mean()) if vol.tail(60).mean() else None
    return {
        "종목코드": ticker,
        "종목명": name,
        "현재가": cur,
        "MA20": ma20,
        "MA60": ma60,
        "MA120": ma120,
        "vs_MA20_%": (cur / ma20 - 1) * 100,
        "vs_MA60_%": (cur / ma60 - 1) * 100,
        "vs_MA120_%": (cur / ma120 - 1) * 100 if ma120 else None,
        "RSI14": rsi14,
        "MACD": macd_line,
        "Signal": signal,
        "Hist": hist,
        "BB_pos": bb_pos,
        "52w_high": high_52w,
        "52w_low": low_52w,
        "52w_pos_%": pos_52w,
        "vol_ratio_5/60": vol_ratio,
    }


def main():
    end = datetime.today().strftime("%Y%m%d")
    start = (datetime.today() - timedelta(days=400)).strftime("%Y%m%d")
    print(f"[기간] {start} ~ {end}")
    results = []
    for i, (code, name) in enumerate(CODES, 1):
        try:
            r = analyze(code, name, end, start)
            results.append(r)
            cur = r.get("현재가")
            rsi14 = r.get("RSI14") or 0
            pos = r.get("52w_pos_%") or 0
            print(f"[{i}/{len(CODES)}] {name:20s} ({code}) cur={cur} RSI={rsi14:.1f} 52w={pos:.0f}%")
        except Exception as e:
            print(f"[{i}/{len(CODES)}] {name}: ERROR {e}")
            results.append({"종목코드": code, "종목명": name, "error": str(e)})
    out_path = Path("tech_indicators_result.json")
    out_path.write_text(json.dumps(results, ensure_ascii=False, indent=2, default=str))
    print(f"\n✅ 저장: {out_path.resolve()}")


if __name__ == "__main__":
    main()
