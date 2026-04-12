"""
네이버 금융 리서치 - 종목별 애널리스트 리포트 PDF 자동 다운로드

Usage:
    python naver_research_downloader.py --code 005930 --count 5
    python naver_research_downloader.py --code 005930 --count 10 --with-meta
"""

import argparse
import re
import time
from dataclasses import dataclass
from pathlib import Path

import requests
from bs4 import BeautifulSoup

BASE_URL = "https://finance.naver.com/research"
HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/120.0.0.0 Safari/537.36"
    ),
    "Referer": "https://finance.naver.com/research/company_list.naver",
}
SAVE_DIR = Path("/Users/chyouk.han/Documents/Obsidian Vault/StockAnalysis/reports")


@dataclass
class Report:
    stock_name: str
    title: str
    broker: str
    date: str
    views: int
    pdf_url: str
    detail_url: str
    target_price: str = ""
    opinion: str = ""


def fetch_page(url: str) -> BeautifulSoup:
    resp = requests.get(url, headers=HEADERS, timeout=15)
    resp.encoding = "euc-kr"
    resp.raise_for_status()
    return BeautifulSoup(resp.text, "html.parser")


def parse_report_list(item_code: str, page: int = 1) -> list[Report]:
    url = (
        f"{BASE_URL}/company_list.naver"
        f"?searchType=itemCode&itemCode={item_code}&page={page}"
    )
    soup = fetch_page(url)
    table = soup.find("table", class_="type_1")
    if not table:
        return []

    reports = []
    for row in table.find_all("tr"):
        cells = row.find_all("td")
        if len(cells) < 6:
            continue

        stock_link = cells[0].find("a")
        if not stock_link:
            continue
        stock_name = stock_link.text.strip()

        title_link = cells[1].find("a")
        if not title_link:
            continue
        title = title_link.text.strip()
        detail_href = title_link.get("href", "")
        detail_url = f"{BASE_URL}/{detail_href}" if detail_href else ""

        broker = cells[2].text.strip()

        pdf_link = cells[3].find("a")
        pdf_url = pdf_link.get("href", "") if pdf_link else ""

        date = cells[4].text.strip()

        views_text = cells[5].text.strip().replace(",", "")
        views = int(views_text) if views_text.isdigit() else 0

        reports.append(Report(
            stock_name=stock_name, title=title, broker=broker,
            date=date, views=views, pdf_url=pdf_url, detail_url=detail_url,
        ))

    return reports


def fetch_report_meta(report: Report) -> Report:
    if not report.detail_url:
        return report
    try:
        soup = fetch_page(report.detail_url)
        meta_text = soup.get_text(separator=" ")
        target_match = re.search(r"목표가\s*([\d,]+)", meta_text)
        if target_match:
            report.target_price = target_match.group(1)
        opinion_match = re.search(r"투자의견\s*(\S+)", meta_text)
        if opinion_match:
            report.opinion = opinion_match.group(1)
    except Exception as e:
        print(f"  [WARN] 메타 추출 실패 ({report.title}): {e}")
    return report


def collect_reports(item_code: str, count: int) -> list[Report]:
    reports: list[Report] = []
    page = 1
    while len(reports) < count:
        page_reports = parse_report_list(item_code, page)
        if not page_reports:
            break
        reports.extend(page_reports)
        page += 1
        time.sleep(0.3)
    return reports[:count]


def download_pdf(report: Report, save_dir: Path) -> Path | None:
    if not report.pdf_url:
        return None

    safe_title = re.sub(r'[\\/*?:"<>|]', "", report.title)[:60]
    date_compact = report.date.replace(".", "")
    filename = f"{date_compact}_{report.broker}_{safe_title}.pdf"
    filepath = save_dir / filename

    if filepath.exists():
        return filepath

    try:
        resp = requests.get(report.pdf_url, headers=HEADERS, timeout=30)
        resp.raise_for_status()
        filepath.write_bytes(resp.content)
        return filepath
    except Exception as e:
        print(f"  [FAIL] {filename}: {e}")
        return None


def download_reports(
    item_code: str,
    count: int = 5,
    save_dir: Path = SAVE_DIR,
    with_meta: bool = False,
) -> list[dict]:
    """종목코드의 최근 N개 리포트 PDF 다운로드."""
    save_dir.mkdir(parents=True, exist_ok=True)

    print(f"[1/3] 리포트 목록 수집 중... (종목: {item_code}, 최근 {count}건)")
    reports = collect_reports(item_code, count)
    if not reports:
        print("[ERROR] 리포트를 찾을 수 없습니다.")
        return []
    print(f"  수집 완료: {len(reports)}건")

    if with_meta:
        print("[2/3] 목표가/투자의견 추출 중...")
        for i, report in enumerate(reports):
            fetch_report_meta(report)
            if (i + 1) % 5 == 0:
                time.sleep(0.5)

    print(f"[3/3] PDF 다운로드 중... → {save_dir}")
    results = []
    for report in reports:
        filepath = download_pdf(report, save_dir)
        time.sleep(0.2)
        results.append({
            "stock_name": report.stock_name,
            "title": report.title,
            "broker": report.broker,
            "date": report.date,
            "views": report.views,
            "target_price": report.target_price,
            "opinion": report.opinion,
            "pdf_url": report.pdf_url,
            "saved_path": str(filepath) if filepath else None,
        })

    return results


def main():
    parser = argparse.ArgumentParser(description="네이버 금융 리서치 리포트 PDF 다운로드")
    parser.add_argument("--code", required=True, help="종목코드 (예: 005930)")
    parser.add_argument("--count", type=int, default=10, help="다운로드할 리포트 수 (기본: 10)")
    parser.add_argument("--save-dir", type=str, default=str(SAVE_DIR))
    parser.add_argument("--with-meta", action="store_true")
    args = parser.parse_args()

    download_reports(
        item_code=args.code, count=args.count,
        save_dir=Path(args.save_dir), with_meta=args.with_meta,
    )


if __name__ == "__main__":
    main()
