"""
한경 컨센서스 - 종목별 애널리스트 리포트 PDF 다운로드 (메인 소스)

네이버 금융 리서치보다 커버리지가 넓음.
URL: consensus.hankyung.com/analysis/list?search_text={종목코드}
PDF: consensus.hankyung.com/analysis/downpdf?report_idx={id}

Usage:
    python hankyung_report_downloader.py --code 082920 --count 10
    python hankyung_report_downloader.py --code 000660 --count 5
"""

import argparse
import re
import time
from dataclasses import dataclass
from pathlib import Path

import requests
from bs4 import BeautifulSoup

BASE_URL = "https://consensus.hankyung.com"
HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/120.0.0.0 Safari/537.36"
    ),
}
SAVE_DIR = Path("/Users/chyouk.han/Documents/Obsidian Vault/StockAnalysis/reports")


@dataclass
class Report:
    stock_name: str
    title: str
    broker: str
    author: str
    date: str
    report_type: str
    pdf_url: str
    target_price: str = ""
    opinion: str = ""


def parse_report_list(stock_code: str, sdate: str = "2025-01-01",
                      edate: str = "2026-12-31", page: int = 1) -> list[Report]:
    """한경 컨센서스에서 종목코드로 리포트 목록을 검색한다."""
    url = (
        f"{BASE_URL}/analysis/list"
        f"?search_text={stock_code}&sdate={sdate}&edate={edate}&now_page={page}"
    )
    try:
        resp = requests.get(url, headers=HEADERS, timeout=15)
        resp.encoding = "utf-8"
        if resp.status_code != 200:
            return []
    except Exception:
        return []

    soup = BeautifulSoup(resp.text, "html.parser")
    tbody = soup.find("tbody")
    if not tbody:
        return []

    reports = []
    for row in tbody.find_all("tr"):
        cells = row.find_all("td")
        if len(cells) < 5:
            continue

        date = cells[0].text.strip()
        report_type = cells[1].text.strip()
        title_cell = cells[2]
        title_text = title_cell.text.strip()

        # 종목명과 제목 분리
        stock_name = ""
        title = title_text
        match = re.match(r"(.+?)\((\d{6})\)\s*(.*)", title_text, re.DOTALL)
        if match:
            stock_name = match.group(1).strip()
            title = match.group(3).strip()[:80]

        author = cells[3].text.strip()
        broker = cells[4].text.strip()

        # PDF 링크
        pdf_links = [a.get("href", "") for a in row.find_all("a")
                     if "downpdf" in str(a.get("href", ""))]
        pdf_url = f"{BASE_URL}{pdf_links[0]}" if pdf_links else ""

        # 기업 리포트만 (시장/산업 제외 옵션)
        reports.append(Report(
            stock_name=stock_name,
            title=title,
            broker=broker,
            author=author,
            date=date,
            report_type=report_type,
            pdf_url=pdf_url,
        ))

    return reports


def collect_reports(stock_code: str, count: int = 10,
                    sdate: str = "2025-01-01", edate: str = "2026-12-31") -> list[Report]:
    """종목코드의 기업 리포트를 수집한다. '기업' 타입만 필터."""
    all_reports = parse_report_list(stock_code, sdate, edate)
    # 기업 리포트만
    corp_reports = [r for r in all_reports if r.report_type == "기업"]
    return corp_reports[:count]


def download_pdf(report: Report, save_dir: Path) -> Path | None:
    """PDF를 다운로드하여 저장."""
    if not report.pdf_url:
        return None

    safe_title = re.sub(r'[\\/*?:"<>|]', "", report.title)[:50]
    date_compact = report.date.replace("-", "")
    filename = f"{date_compact}_{report.broker}_{safe_title}.pdf"
    filepath = save_dir / filename

    if filepath.exists():
        return filepath

    try:
        resp = requests.get(report.pdf_url, headers=HEADERS, timeout=30)
        resp.raise_for_status()
        if len(resp.content) < 1000:  # 너무 작으면 에러 페이지
            return None
        filepath.write_bytes(resp.content)
        return filepath
    except Exception as e:
        print(f"  [FAIL] {filename}: {e}")
        return None


def download_reports(
    stock_code: str,
    count: int = 10,
    save_dir: Path = SAVE_DIR,
) -> list[dict]:
    """종목코드의 리포트 PDF를 다운로드한다."""
    save_dir.mkdir(parents=True, exist_ok=True)

    print(f"[한경] 리포트 검색 중... (종목: {stock_code})")
    reports = collect_reports(stock_code, count)
    if not reports:
        print(f"  리포트 없음")
        return []
    print(f"  {len(reports)}건 발견")

    results = []
    for report in reports:
        filepath = download_pdf(report, save_dir)
        time.sleep(0.3)
        results.append({
            "stock_name": report.stock_name,
            "title": report.title,
            "broker": report.broker,
            "author": report.author,
            "date": report.date,
            "target_price": report.target_price,
            "opinion": report.opinion,
            "pdf_url": report.pdf_url,
            "saved_path": str(filepath) if filepath else None,
        })

    saved = sum(1 for r in results if r["saved_path"])
    print(f"  {saved}/{len(results)}건 다운로드 완료")
    return results


def main():
    parser = argparse.ArgumentParser(description="한경 컨센서스 리포트 PDF 다운로드")
    parser.add_argument("--code", required=True, help="종목코드 (예: 082920)")
    parser.add_argument("--count", type=int, default=10, help="리포트 수 (기본: 10)")
    parser.add_argument("--save-dir", type=str, default=str(SAVE_DIR))
    args = parser.parse_args()

    download_reports(stock_code=args.code, count=args.count, save_dir=Path(args.save_dir))


if __name__ == "__main__":
    main()
