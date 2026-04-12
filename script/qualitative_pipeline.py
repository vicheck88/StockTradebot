#!/usr/bin/env python3
"""
정성평가 데이터 파이프라인 — Obsidian vault에 저장

3개 소스에서 데이터를 수집하여 종목별 마크다운 노트를 생성:
1. FnGuide 컨센서스 (R 함수 호출)
2. 네이버 금융 리서치 리포트 PDF
3. OpenDART 공시 (자사주, 배당, 내부자)

Usage:
    # conda activate base
    python qualitative_pipeline.py --codes 005930,000660,383220 --count 5
    python qualitative_pipeline.py --codes-file ../screening_result_final.json --top 30 --count 3
"""

import argparse
import json
import subprocess
import sys
import time
from datetime import datetime, timedelta
from pathlib import Path

# Add script dir to path
SCRIPT_DIR = Path(__file__).parent
sys.path.insert(0, str(SCRIPT_DIR))

from naver_research_downloader import download_reports
from dart_disclosures import (
    load_api_key,
    stock_code_to_corp_code,
    get_dart_disclosures_by_stock_code,
    _corp_name_cache,
    _download_corp_code_xml,
)

OBSIDIAN_BASE = Path("/Users/chyouk.han/Documents/Obsidian Vault/StockAnalysis")
CONSENSUS_DIR = OBSIDIAN_BASE / "consensus"
REPORTS_DIR = OBSIDIAN_BASE / "reports"
SCREENING_DIR = OBSIDIAN_BASE / "screening"


def get_fnguide_consensus(code: str) -> dict | None:
    """R 함수를 호출하여 FnGuide 컨센서스 데이터를 가져온다."""
    r_script = f'''
    setwd("{SCRIPT_DIR}")
    suppressPackageStartupMessages({{
        library(httr); library(jsonlite); library(stringr)
    }})
    source("fnguide_consensus.R")
    r <- getConsensusFromFnGuide("{code}")
    if(!is.null(r)) cat(toJSON(r, auto_unbox=TRUE))
    '''
    try:
        result = subprocess.run(
            ["Rscript", "-e", r_script],
            capture_output=True, text=True, timeout=30
        )
        if result.returncode != 0 or not result.stdout.strip():
            return None
        return json.loads(result.stdout.strip())
    except Exception as e:
        print(f"  [WARN] FnGuide 컨센서스 실패 ({code}): {e}")
        return None


def format_consensus_md(code: str, name: str, consensus: dict) -> str:
    """컨센서스 데이터를 마크다운으로 변환."""
    lines = [
        f"# {name} ({code}) 컨센서스",
        f"",
        f"갱신: {datetime.now().strftime('%Y-%m-%d %H:%M')}",
        f"",
        f"## 투자의견",
        f"",
    ]

    op = consensus.get("opinion", {})
    lines.append(f"| 구분 | 건수 |")
    lines.append(f"|------|-----:|")
    lines.append(f"| 매수 | {op.get('buy', 0)} |")
    lines.append(f"| 중립 | {op.get('hold', 0)} |")
    lines.append(f"| 매도 | {op.get('sell', 0)} |")
    lines.append(f"| **평균 점수** | **{op.get('avg_score', '-')}** |")
    lines.append(f"")

    tp = consensus.get("target_price", {})
    lines.append(f"## 목표가")
    lines.append(f"")
    lines.append(f"| 구분 | 값 |")
    lines.append(f"|------|---:|")
    lines.append(f"| 평균 | {tp.get('avg', '-'):,} |" if tp.get('avg') else "| 평균 | - |")
    lines.append(f"| 최고 | {tp.get('max', '-'):,} |" if tp.get('max') else "| 최고 | - |")
    lines.append(f"| 최저 | {tp.get('min', '-'):,} |" if tp.get('min') else "| 최저 | - |")
    lines.append(f"| 증권사 수 | {tp.get('broker_count', 0)} |")
    lines.append(f"")

    for label, key in [("EPS", "eps"), ("매출", "revenue"), ("영업이익", "op_income")]:
        data = consensus.get(key, [])
        if data:
            lines.append(f"## {label} 전망")
            lines.append(f"")
            lines.append(f"| 기간 | 값 |")
            lines.append(f"|------|---:|")
            for item in data:
                val = item.get("value")
                val_str = f"{val:,.0f}" if val else "-"
                lines.append(f"| {item.get('period', '')} | {val_str} |")
            lines.append(f"")

    return "\n".join(lines)


def format_dart_md(code: str, name: str, dart_data: dict) -> str:
    """DART 공시 데이터를 마크다운으로 변환."""
    lines = [
        f"# {name} ({code}) DART 공시",
        f"",
        f"갱신: {datetime.now().strftime('%Y-%m-%d %H:%M')}",
        f"",
    ]

    # 배당
    div = dart_data.get("dividend", [])
    if div:
        lines.append(f"## 배당")
        lines.append(f"")
        lines.append(f"| 구분 | 당기 | 전기 |")
        lines.append(f"|------|-----:|-----:|")
        for d in div:
            se = d.get("se", "")
            if any(k in se for k in ["주당배당금", "배당성향", "배당수익률", "현금배당금총액"]):
                lines.append(f"| {se} | {d.get('thstrm', '-')} | {d.get('frmtrm', '-')} |")
        lines.append(f"")

    # 자사주
    acq = dart_data.get("treasury_stock_acquisition", [])
    disp = dart_data.get("treasury_stock_disposal", [])
    if acq or disp:
        lines.append(f"## 자사주")
        lines.append(f"")
        if acq:
            lines.append(f"### 취득 결정 ({len(acq)}건)")
            for a in acq:
                lines.append(f"- 보통주 {a.get('aqpln_stk_ostk', '-')}주, "
                           f"목적: {a.get('aq_pp', '-')}, "
                           f"기간: {a.get('aqexpd_bgd', '')}~{a.get('aqexpd_edd', '')}")
            lines.append(f"")
        if disp:
            lines.append(f"### 처분 결정 ({len(disp)}건)")
            for d in disp:
                lines.append(f"- 보통주 {d.get('dppln_stk_ostk', '-')}주")
            lines.append(f"")

    # 최대주주 변동
    changes = dart_data.get("major_shareholder_changes", [])
    if changes:
        lines.append(f"## 최대주주 변동")
        lines.append(f"")
        lines.append(f"| 변동일 | 최대주주 | 지분율 | 변동사유 |")
        lines.append(f"|--------|---------|------:|---------|")
        for c in changes[:10]:
            lines.append(
                f"| {c.get('change_on', '-')} | {c.get('mxmm_shrholdr_nm', '-')} | "
                f"{c.get('qota_rt', '-')} | {c.get('change_cause', '-')} |"
            )
        lines.append(f"")

    # 임원 지분변동
    exec_report = dart_data.get("executive_shareholder_report", [])
    if exec_report:
        lines.append(f"## 임원 지분변동 (최근 10건)")
        lines.append(f"")
        lines.append(f"| 접수일 | 보고자 | 직위 | 소유비율 | 증감비율 |")
        lines.append(f"|--------|--------|------|--------:|--------:|")
        for e in exec_report[:10]:
            lines.append(
                f"| {e.get('rcept_dt', '-')} | {e.get('repror', '-')} | "
                f"{e.get('isu_exctv_ofcps', '-')} | {e.get('sp_stock_lmp_rate', '-')} | "
                f"{e.get('sp_stock_lmp_irds_rate', '-')} |"
            )
        lines.append(f"")

    return "\n".join(lines)


def format_reports_md(code: str, name: str, reports: list[dict]) -> str:
    """리포트 메타데이터를 마크다운으로 변환."""
    lines = [
        f"# {name} ({code}) 애널리스트 리포트",
        f"",
        f"갱신: {datetime.now().strftime('%Y-%m-%d %H:%M')}",
        f"",
        f"| 일자 | 증권사 | 제목 | 목표가 | 의견 |",
        f"|------|--------|------|------:|------|",
    ]
    for r in reports:
        tp = r.get("target_price") or "-"
        op = r.get("opinion") or "-"
        pdf = r.get("saved_path")
        title = r.get("title", "")
        if pdf:
            title = f"[[{Path(pdf).name}|{title}]]"
        lines.append(f"| {r.get('date', '')} | {r.get('broker', '')} | {title} | {tp} | {op} |")
    lines.append(f"")
    return "\n".join(lines)


def process_stock(code: str, name: str, api_key: str, report_count: int = 5):
    """단일 종목의 정성 데이터를 수집하고 Obsidian에 저장."""
    print(f"\n{'='*60}")
    print(f"[{name} ({code})]")
    print(f"{'='*60}")

    CONSENSUS_DIR.mkdir(parents=True, exist_ok=True)
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)

    # 1. FnGuide 컨센서스
    print(f"  [1/3] FnGuide 컨센서스...")
    consensus = get_fnguide_consensus(code)
    if consensus:
        md = format_consensus_md(code, name, consensus)
        (CONSENSUS_DIR / f"{code}_{name}_컨센서스.md").write_text(md, encoding="utf-8")
        op = consensus.get("opinion", {})
        tp = consensus.get("target_price", {})
        print(f"    매수{op.get('buy',0)} 중립{op.get('hold',0)} 매도{op.get('sell',0)} | "
              f"목표가 {tp.get('avg','?'):,}")
    else:
        print(f"    컨센서스 없음 (커버리지 미존재)")

    time.sleep(0.5)

    # 2. 네이버 리서치 리포트
    print(f"  [2/3] 네이버 리서치 리포트 ({report_count}건)...")
    reports = download_reports(code, count=report_count, save_dir=REPORTS_DIR, with_meta=True)
    if reports:
        md = format_reports_md(code, name, reports)
        (CONSENSUS_DIR / f"{code}_{name}_리포트.md").write_text(md, encoding="utf-8")
        print(f"    {len(reports)}건 수집")
    else:
        print(f"    리포트 없음")

    time.sleep(0.5)

    # 3. DART 공시
    print(f"  [3/3] DART 공시...")
    try:
        end_date = datetime.now().strftime("%Y%m%d")
        start_date = (datetime.now() - timedelta(days=365)).strftime("%Y%m%d")
        bsns_year = str(datetime.now().year - 1)
        dart_data = get_dart_disclosures_by_stock_code(
            code, api_key, start_date, end_date, bsns_year
        )
        md = format_dart_md(code, name, dart_data)
        (CONSENSUS_DIR / f"{code}_{name}_DART.md").write_text(md, encoding="utf-8")
        counts = {k: len(v) for k, v in dart_data.items() if isinstance(v, list)}
        print(f"    {counts}")
    except Exception as e:
        print(f"    DART 실패: {e}")

    return {"code": code, "name": name, "consensus": consensus, "reports": reports}


def load_codes_from_screening(json_path: str, top_n: int = 30) -> list[tuple[str, str]]:
    """screening_result JSON에서 상위 N개 종목코드+종목명 추출."""
    with open(json_path, "r") as f:
        data = json.load(f)
    candidates = data["candidates"]
    sorted_cands = sorted(candidates, key=lambda x: x.get("score_best", 0) or 0, reverse=True)
    return [(c["종목코드"], c["종목명"]) for c in sorted_cands[:top_n]]


def main():
    parser = argparse.ArgumentParser(description="정성평가 데이터 파이프라인")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--codes", help="종목코드 (쉼표 구분, 예: 005930,000660)")
    group.add_argument("--codes-file", help="screening_result JSON 파일 경로")
    parser.add_argument("--top", type=int, default=30, help="JSON에서 상위 N개 (기본: 30)")
    parser.add_argument("--count", type=int, default=5, help="종목당 리포트 수 (기본: 5)")
    args = parser.parse_args()

    api_key = load_api_key()

    # corp_code 캐시 미리 로드
    print("[INIT] DART corp_code 캐시 로드 중...")
    _download_corp_code_xml(api_key)
    print(f"  {len(_corp_name_cache)}개 기업 로드 완료")

    if args.codes:
        codes = [(c.strip(), _corp_name_cache.get(c.strip(), c.strip()))
                 for c in args.codes.split(",")]
    else:
        codes = load_codes_from_screening(args.codes_file, args.top)

    print(f"\n대상: {len(codes)}개 종목, 리포트 {args.count}건/종목")

    results = []
    for i, (code, name) in enumerate(codes):
        print(f"\n[{i+1}/{len(codes)}]", end="")
        result = process_stock(code, name, api_key, args.count)
        results.append(result)
        time.sleep(1)

    # 요약 저장
    summary_lines = [
        f"# 정성평가 데이터 수집 요약",
        f"",
        f"실행: {datetime.now().strftime('%Y-%m-%d %H:%M')}",
        f"대상: {len(codes)}개 종목",
        f"",
        f"| 종목 | 컨센서스 | 리포트 | DART |",
        f"|------|:-------:|:------:|:----:|",
    ]
    for r in results:
        con = "O" if r.get("consensus") else "X"
        rep = f"{len(r.get('reports', []))}건" if r.get("reports") else "X"
        dart_file = CONSENSUS_DIR / f"{r['code']}_{r['name']}_DART.md"
        dart = "O" if dart_file.exists() else "X"
        summary_lines.append(f"| {r['name']} ({r['code']}) | {con} | {rep} | {dart} |")

    (SCREENING_DIR / f"{datetime.now().strftime('%Y-%m-%d')}_정성데이터_수집.md").write_text(
        "\n".join(summary_lines), encoding="utf-8"
    )
    print(f"\n\n완료. Obsidian vault: {OBSIDIAN_BASE}")


if __name__ == "__main__":
    main()
