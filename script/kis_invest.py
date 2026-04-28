#!/usr/bin/env python3
"""
KIS 자동 분할 매수 스크립트.

매 실행 시 전체 현황 (잔고 + 기술적 분석 + SOFR 잔여) 기반으로
종목별 목표 vs 현재 갭을 다시 계산하고 RSI 트리거에 따라 매수량 산출.

사용:
    python kis_invest.py status                  # 전체 현황 + 갭 분석
    python kis_invest.py plan                    # 매수 계획 출력 (실행 안 함)
    python kis_invest.py execute --dry           # 주문 시뮬레이션
    python kis_invest.py execute --confirm       # 실제 주문 실행 (KIS 매수)
    python kis_invest.py execute --confirm --include-sofr  # SOFR 매도 + 매수
"""

import argparse
import json
import os
import sys
import time
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path

import requests

CONFIG_PATH = os.path.expanduser("~/config.json")
TOKEN_CACHE = Path("/tmp/kis_token.json")
PLAN_LOG = Path("script/invest_plan.log.json")

LOCKED_PORTFOLIO = {
    "000660": {"name": "SK하이닉스", "weight": 30.0},
    "005930": {"name": "삼성전자", "weight": 25.0},
    "071050": {"name": "한국금융지주", "weight": 25.0},
    "000270": {"name": "기아", "weight": 20.0},
}

NON_LOCKED_TO_LIQUIDATE = ["017670", "055550", "005830"]

SOFR_ETF_CODE = "456610"
SOFR_ETF_NAME = "TIGER 미국달러SOFR금리액티브(합성)"

TOTAL_NEW_CAPITAL = 100_000_000

SCHEDULE = [
    {"round": 1, "date": "2026-04-28", "remaining_rounds_after": 3},
    {"round": 2, "date": "2026-05-12", "remaining_rounds_after": 2},
    {"round": 3, "date": "2026-05-26", "remaining_rounds_after": 1},
    {"round": 4, "date": "2026-06-09", "remaining_rounds_after": 0},
]

RSI_TRIGGER = [
    (65, 1.00),
    (75, 0.75),
    (85, 0.50),
    (999, 0.25),
]

LOCKED_BUY_GUARD_RSI = 88


@dataclass
class Position:
    code: str
    name: str
    qty: int
    avg_price: float
    current: int
    eval_amt: int
    pnl_rt: float


@dataclass
class TechSnapshot:
    code: str
    name: str
    current: int
    rsi14: float | None
    vs_ma20: float | None
    return_5d: float | None
    return_20d: float | None
    return_60d: float | None
    from_52w_high: float | None


@dataclass
class BuyOrder:
    code: str
    name: str
    qty: int
    price: int
    amount: int
    rsi: float | None
    rsi_ratio: float
    note: str = ""


def load_config() -> dict:
    with open(CONFIG_PATH) as f:
        return json.load(f)


def get_token(api_url: str, app_key: str, app_secret: str) -> str:
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


def kis_headers(app_key: str, app_secret: str, token: str, tr_id: str) -> dict:
    return {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {token}",
        "appkey": app_key,
        "appsecret": app_secret,
        "tr_id": tr_id,
    }


def get_balance(api_url: str, app_key: str, app_secret: str, token: str, acc_no: str) -> tuple[list[Position], dict]:
    cano, prdt = acc_no[:8], acc_no[8:]
    resp = requests.get(
        f"{api_url}/uapi/domestic-stock/v1/trading/inquire-balance",
        headers=kis_headers(app_key, app_secret, token, "TTTC8434R"),
        params={
            "CANO": cano, "ACNT_PRDT_CD": prdt,
            "AFHR_FLPR_YN": "N", "OFL_YN": "", "INQR_DVSN": "02",
            "UNPR_DVSN": "01", "FUND_STTL_ICLD_YN": "N",
            "FNCG_AMT_AUTO_RDPT_YN": "N", "PRCS_DVSN": "01",
            "CTX_AREA_FK100": "", "CTX_AREA_NK100": "",
        },
        timeout=10,
    )
    data = resp.json()
    positions = []
    for x in data.get("output1", []):
        qty = int(x.get("hldg_qty", 0))
        if qty <= 0:
            continue
        positions.append(Position(
            code=x["pdno"],
            name=x["prdt_name"],
            qty=qty,
            avg_price=float(x.get("pchs_avg_pric", 0)),
            current=int(x.get("prpr", 0)),
            eval_amt=int(x.get("evlu_amt", 0)),
            pnl_rt=float(x.get("evlu_pfls_rt", 0)),
        ))
    summary = data.get("output2", [{}])[0] if data.get("output2") else {}
    return positions, summary


def get_orderable_cash(api_url: str, app_key: str, app_secret: str, token: str, acc_no: str) -> int:
    cano, prdt = acc_no[:8], acc_no[8:]
    resp = requests.get(
        f"{api_url}/uapi/domestic-stock/v1/trading/inquire-psbl-order",
        headers=kis_headers(app_key, app_secret, token, "TTTC8908R"),
        params={
            "CANO": cano, "ACNT_PRDT_CD": prdt,
            "PDNO": "", "ORD_UNPR": "0", "ORD_DVSN": "01",
            "CMA_EVLU_AMT_ICLD_YN": "Y", "OVRS_ICLD_YN": "N",
        },
        timeout=10,
    )
    data = resp.json()
    out = data.get("output", {})
    return int(out.get("ord_psbl_cash", 0))


def get_current_price(api_url: str, app_key: str, app_secret: str, token: str, code: str) -> int:
    resp = requests.get(
        f"{api_url}/uapi/domestic-stock/v1/quotations/inquire-price",
        headers=kis_headers(app_key, app_secret, token, "FHKST01010100"),
        params={"FID_COND_MRKT_DIV_CODE": "J", "FID_INPUT_ISCD": code},
        timeout=10,
    )
    data = resp.json()
    if data.get("rt_cd") != "0":
        return 0
    return int(data["output"]["stck_prpr"])


def get_tech(api_url: str, app_key: str, app_secret: str, token: str, code: str, name: str) -> TechSnapshot:
    from datetime import timedelta
    end = datetime.now()
    start = end - timedelta(days=200)
    resp = requests.get(
        f"{api_url}/uapi/domestic-stock/v1/quotations/inquire-daily-itemchartprice",
        headers=kis_headers(app_key, app_secret, token, "FHKST03010100"),
        params={
            "FID_COND_MRKT_DIV_CODE": "J", "FID_INPUT_ISCD": code,
            "FID_INPUT_DATE_1": start.strftime("%Y%m%d"),
            "FID_INPUT_DATE_2": end.strftime("%Y%m%d"),
            "FID_PERIOD_DIV_CODE": "D", "FID_ORG_ADJ_PRC": "0",
        },
        timeout=10,
    )
    data = resp.json()
    rows = data.get("output2", [])
    closes = []
    for r in reversed(rows):
        if not r.get("stck_bsop_date"):
            continue
        closes.append(int(r["stck_clpr"]))
    if len(closes) < 21:
        return TechSnapshot(code, name, closes[-1] if closes else 0, None, None, None, None, None, None)
    cur = closes[-1]

    def ma(n):
        if len(closes) < n: return None
        return sum(closes[-n:]) / n

    def rsi(n=14):
        # Wilder RSI: 첫 n개 SMA 시드 → 재귀 평활(α=1/n)
        if len(closes) < n + 1: return None
        diffs = [closes[i] - closes[i - 1] for i in range(1, len(closes))]
        gains = [d if d > 0 else 0 for d in diffs]
        losses = [-d if d < 0 else 0 for d in diffs]
        if len(diffs) < n: return None
        ag = sum(gains[:n]) / n
        al = sum(losses[:n]) / n
        for i in range(n, len(diffs)):
            ag = (ag * (n - 1) + gains[i]) / n
            al = (al * (n - 1) + losses[i]) / n
        if al == 0: return 100.0
        rs = ag / al
        return round(100 - 100 / (1 + rs), 1)

    def ret(n):
        if len(closes) < n + 1: return None
        return round((cur - closes[-n - 1]) / closes[-n - 1] * 100, 1)

    ma20 = ma(20)
    high_window = closes[-min(252, len(closes)):]
    high_52w = max(high_window)

    return TechSnapshot(
        code=code, name=name, current=cur, rsi14=rsi(14),
        vs_ma20=round((cur / ma20 - 1) * 100, 1) if ma20 else None,
        return_5d=ret(5), return_20d=ret(20), return_60d=ret(60),
        from_52w_high=round((cur - high_52w) / high_52w * 100, 1),
    )


def rsi_to_ratio(rsi: float | None) -> float:
    if rsi is None:
        return 0.5
    for thresh, ratio in RSI_TRIGGER:
        if rsi < thresh:
            return ratio
    return 0.25


def determine_round(today: str | None = None) -> dict:
    today = today or datetime.now().strftime("%Y-%m-%d")
    for s in SCHEDULE:
        if today <= s["date"]:
            return s
    return SCHEDULE[-1]


def compute_plan(positions: list[Position], techs: dict[str, TechSnapshot],
                 cash: int, sofr_eval: int, today: str | None = None) -> dict:
    """매수 계획 산출.

    - 종목별 목표 평가액 = weight × TOTAL_NEW_CAPITAL
      (단, 잠금 종목 중 기존 보유분이 있으면 평가액에서 차감하지 않고 별도 추적)
    - 갭 = 목표 - 현재 평가액 (신규 자금 기준)
    - 차수별 균등 분배: 갭 / 잔여차수 (당해 포함)
    - RSI 트리거로 당해 차수 비율 조정
    """
    cur = determine_round(today)
    rounds_left = cur["remaining_rounds_after"] + 1
    pos_map = {p.code: p for p in positions}
    pre_existing = {}
    for code, info in LOCKED_PORTFOLIO.items():
        p = pos_map.get(code)
        pre_existing[code] = p.eval_amt if p else 0

    orders: list[BuyOrder] = []
    total_amount = 0
    for code, info in LOCKED_PORTFOLIO.items():
        target_amt = TOTAL_NEW_CAPITAL * info["weight"] / 100
        held_amt = pos_map[code].eval_amt if code in pos_map else 0
        new_capital_held = max(0, held_amt - pre_existing.get(code, held_amt))
        gap = target_amt - new_capital_held
        if gap <= 0:
            continue
        round_share = gap / rounds_left
        tech = techs.get(code)
        rsi_val = tech.rsi14 if tech else None
        ratio = rsi_to_ratio(rsi_val)
        note_parts = []
        if rsi_val is not None and rsi_val >= LOCKED_BUY_GUARD_RSI:
            ratio = 0.0
            note_parts.append(f"RSI {rsi_val:.1f} >= {LOCKED_BUY_GUARD_RSI} 매수 보류")
        amount_target = round_share * ratio
        price = tech.current if tech else 0
        if price <= 0 or amount_target <= 0:
            qty = 0
        else:
            qty = int(amount_target // price)
        if qty <= 0:
            if not note_parts:
                note_parts.append("RSI 상한 또는 갭 부족")
            orders.append(BuyOrder(code, info["name"], 0, price, 0, rsi_val, ratio, "; ".join(note_parts)))
            continue
        amt = qty * price
        total_amount += amt
        orders.append(BuyOrder(code, info["name"], qty, price, amt, rsi_val, ratio, "; ".join(note_parts) or "정상"))

    cash_needed = total_amount
    cash_available = cash
    sofr_to_sell = max(0, cash_needed - cash_available) if cash_needed > cash_available else 0

    return {
        "round": cur["round"],
        "round_date": cur["date"],
        "rounds_left_inclusive": rounds_left,
        "orders": orders,
        "total_amount": total_amount,
        "cash_available": cash_available,
        "sofr_eval": sofr_eval,
        "sofr_to_sell": sofr_to_sell,
        "today": today or datetime.now().strftime("%Y-%m-%d"),
    }


def place_order(api_url: str, app_key: str, app_secret: str, token: str,
                acc_no: str, code: str, qty: int, price: int = 0,
                ord_dvsn: str = "01") -> dict:
    """현금 매수 주문. ord_dvsn=01 시장가, 00 지정가."""
    cano, prdt = acc_no[:8], acc_no[8:]
    body = {
        "CANO": cano, "ACNT_PRDT_CD": prdt, "PDNO": code,
        "ORD_DVSN": ord_dvsn,
        "ORD_QTY": str(qty),
        "ORD_UNPR": str(price) if ord_dvsn == "00" else "0",
    }
    resp = requests.post(
        f"{api_url}/uapi/domestic-stock/v1/trading/order-cash",
        headers={**kis_headers(app_key, app_secret, token, "TTTC0802U"),
                 "custtype": "P"},
        json=body, timeout=10,
    )
    return resp.json()


def place_sell(api_url: str, app_key: str, app_secret: str, token: str,
               acc_no: str, code: str, qty: int, price: int = 0,
               ord_dvsn: str = "01") -> dict:
    cano, prdt = acc_no[:8], acc_no[8:]
    body = {
        "CANO": cano, "ACNT_PRDT_CD": prdt, "PDNO": code,
        "ORD_DVSN": ord_dvsn,
        "ORD_QTY": str(qty),
        "ORD_UNPR": str(price) if ord_dvsn == "00" else "0",
    }
    resp = requests.post(
        f"{api_url}/uapi/domestic-stock/v1/trading/order-cash",
        headers={**kis_headers(app_key, app_secret, token, "TTTC0801U"),
                 "custtype": "P"},
        json=body, timeout=10,
    )
    return resp.json()


def fmt_won(n: int | float) -> str:
    return f"{int(n):,}"


def print_status(positions: list[Position], summary: dict, cash: int,
                 techs: dict[str, TechSnapshot], sofr_pos: Position | None) -> None:
    print("=" * 90)
    print(f"[보유 종목 {len(positions)}개]")
    print(f"  {'코드':<8}{'종목':<14}{'수량':>5} {'평단':>10} {'현재가':>10} {'평가액':>13} {'손익률':>8}")
    for p in positions:
        marker = " 🔒" if p.code in LOCKED_PORTFOLIO else ""
        print(f"  {p.code:<8}{p.name:<14}{p.qty:>5} {fmt_won(p.avg_price):>10} {fmt_won(p.current):>10} "
              f"{fmt_won(p.eval_amt):>13} {p.pnl_rt:>+7.2f}%{marker}")

    print(f"\n[잔고 요약]")
    print(f"  주식 평가액: {fmt_won(summary.get('scts_evlu_amt', 0)):>15}")
    print(f"  매입 원가: {fmt_won(summary.get('pchs_amt_smtl_amt', 0)):>15}")
    print(f"  평가 손익: {fmt_won(summary.get('evlu_pfls_smtl_amt', 0)):>15}")
    print(f"  예수금:   {fmt_won(summary.get('dnca_tot_amt', 0)):>15}")
    print(f"  총자산:   {fmt_won(summary.get('tot_evlu_amt', 0)):>15}")
    print(f"  매수가능 현금: {fmt_won(cash):>15}")

    if sofr_pos:
        print(f"\n[SOFR ETF]")
        print(f"  {sofr_pos.name} ({sofr_pos.code}): {sofr_pos.qty}주 평가 {fmt_won(sofr_pos.eval_amt)} "
              f"({sofr_pos.pnl_rt:+.2f}%)")

    print(f"\n[잠금 종목 기술적 상태]")
    print(f"  {'코드':<8}{'종목':<14}{'현재가':>10}{'RSI':>6}{'MA20%':>8}{'5d%':>7}{'20d%':>7}{'52H%':>7}")
    for code, info in LOCKED_PORTFOLIO.items():
        t = techs.get(code)
        if not t:
            continue
        rsi_str = f"{t.rsi14:.1f}" if t.rsi14 is not None else "-"
        print(f"  {code:<8}{t.name:<14}{fmt_won(t.current):>10}{rsi_str:>6}"
              f"{(f'{t.vs_ma20:+.1f}' if t.vs_ma20 is not None else '-'):>8}"
              f"{(f'{t.return_5d:+.1f}' if t.return_5d is not None else '-'):>7}"
              f"{(f'{t.return_20d:+.1f}' if t.return_20d is not None else '-'):>7}"
              f"{(f'{t.from_52w_high:+.1f}' if t.from_52w_high is not None else '-'):>7}")


def print_plan(plan: dict) -> None:
    print("\n" + "=" * 90)
    print(f"[매수 계획] {plan['round']}차 ({plan['round_date']}, 잔여 {plan['rounds_left_inclusive']}차수)")
    print(f"  {'코드':<8}{'종목':<14}{'RSI':>6}{'비율':>6}{'단가':>10}{'수량':>5}{'금액':>13}  비고")
    for o in plan["orders"]:
        rsi_str = f"{o.rsi:.1f}" if o.rsi is not None else "-"
        print(f"  {o.code:<8}{o.name:<14}{rsi_str:>6}{o.rsi_ratio*100:>5.0f}%"
              f"{fmt_won(o.price):>10}{o.qty:>5}{fmt_won(o.amount):>13}  {o.note}")
    print(f"  합계 매수액: {fmt_won(plan['total_amount'])}")
    print(f"  매수가능 현금: {fmt_won(plan['cash_available'])}")
    print(f"  SOFR 평가액: {fmt_won(plan['sofr_eval'])}")
    if plan["sofr_to_sell"] > 0:
        print(f"  ⚠️ 현금 부족 → SOFR ETF에서 {fmt_won(plan['sofr_to_sell'])} 매도 필요")


def save_plan_log(plan: dict, executed: bool) -> None:
    PLAN_LOG.parent.mkdir(parents=True, exist_ok=True)
    log = []
    if PLAN_LOG.exists():
        try:
            log = json.loads(PLAN_LOG.read_text())
        except Exception:
            log = []
    record = {
        "timestamp": datetime.now().isoformat(),
        "today": plan["today"],
        "round": plan["round"],
        "round_date": plan["round_date"],
        "executed": executed,
        "orders": [
            {"code": o.code, "name": o.name, "qty": o.qty, "price": o.price,
             "amount": o.amount, "rsi": o.rsi, "rsi_ratio": o.rsi_ratio, "note": o.note}
            for o in plan["orders"]
        ],
        "total_amount": plan["total_amount"],
        "sofr_to_sell": plan["sofr_to_sell"],
    }
    log.append(record)
    PLAN_LOG.write_text(json.dumps(log, ensure_ascii=False, indent=2))


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="cmd", required=True)
    sub.add_parser("status")
    sub.add_parser("plan")
    ex = sub.add_parser("execute")
    ex.add_argument("--dry", action="store_true", help="시뮬레이션만 (주문 미발송)")
    ex.add_argument("--confirm", action="store_true", help="실제 주문 발송")
    ex.add_argument("--include-sofr", action="store_true", help="현금 부족시 SOFR ETF 매도")
    ex.add_argument("--ord-dvsn", default="01", help="주문구분: 01=시장가(기본), 00=지정가")
    parser.add_argument("--today", default=None, help="YYYY-MM-DD (테스트용)")
    args = parser.parse_args()

    cfg = load_config()
    prod = cfg["api"]["config"]["prod"]
    acc = cfg["api"]["account"]["prod"]["main"]
    api_url = prod["url"]
    app_key = acc["appkey"]
    app_secret = acc["appsecret"]
    acc_no = acc["accNo"]
    token = get_token(api_url, app_key, app_secret)

    positions, summary = get_balance(api_url, app_key, app_secret, token, acc_no)
    cash = get_orderable_cash(api_url, app_key, app_secret, token, acc_no)
    sofr_pos = next((p for p in positions if p.code == SOFR_ETF_CODE), None)

    techs: dict[str, TechSnapshot] = {}
    for code, info in LOCKED_PORTFOLIO.items():
        try:
            techs[code] = get_tech(api_url, app_key, app_secret, token, code, info["name"])
            time.sleep(0.15)
        except Exception as e:
            print(f"  [경고] {code} 시세 조회 실패: {e}", file=sys.stderr)

    if args.cmd == "status":
        print_status(positions, summary, cash, techs, sofr_pos)
        return

    plan = compute_plan(positions, techs, cash, sofr_pos.eval_amt if sofr_pos else 0, args.today)

    if args.cmd == "plan":
        print_status(positions, summary, cash, techs, sofr_pos)
        print_plan(plan)
        save_plan_log(plan, executed=False)
        return

    print_status(positions, summary, cash, techs, sofr_pos)
    print_plan(plan)

    if not (args.dry or args.confirm):
        print("\n[안내] --dry 또는 --confirm 옵션 필요")
        return

    if args.dry:
        print("\n[DRY RUN] 실제 주문 발송하지 않음.")
        save_plan_log(plan, executed=False)
        return

    if not args.confirm:
        print("\n[안내] --confirm 없이는 실주문 발송하지 않음.")
        return

    if plan["sofr_to_sell"] > 0:
        if not args.include_sofr:
            print(f"\n❌ 현금 부족 ({fmt_won(plan['sofr_to_sell'])} 부족) — --include-sofr 필요")
            return
        if not sofr_pos:
            print("\n❌ SOFR ETF 보유 없음 — 매도 불가")
            return
        sofr_price = sofr_pos.current
        sofr_qty = -(-plan["sofr_to_sell"] // sofr_price)
        sofr_qty = min(sofr_qty, sofr_pos.qty)
        print(f"\n[SOFR 매도] {SOFR_ETF_NAME} {sofr_qty}주 @ {fmt_won(sofr_price)} (시장가)")
        r = place_sell(api_url, app_key, app_secret, token, acc_no, SOFR_ETF_CODE,
                       sofr_qty, ord_dvsn=args.ord_dvsn)
        print(f"  결과: rt_cd={r.get('rt_cd')} msg={r.get('msg1')}")
        time.sleep(2)

    print("\n[실주문 발송]")
    for o in plan["orders"]:
        if o.qty <= 0:
            print(f"  {o.code} {o.name}: 스킵 ({o.note})")
            continue
        r = place_order(api_url, app_key, app_secret, token, acc_no,
                        o.code, o.qty, o.price, ord_dvsn=args.ord_dvsn)
        print(f"  {o.code} {o.name} {o.qty}주: rt_cd={r.get('rt_cd')} msg={r.get('msg1')}")
        time.sleep(0.5)

    save_plan_log(plan, executed=True)


if __name__ == "__main__":
    main()
