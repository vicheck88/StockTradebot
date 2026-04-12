"""
OpenDART API - 종목별 주요 공시 조회 모듈

APIs:
  1. 종목코드 → DART corp_code 변환
  2. 자기주식 취득/처분 현황 (정기보고서)
  3. 자기주식 취득/처분 결정 (주요사항보고서)
  4. 배당에 관한 사항 (정기보고서)
  5. 최대주주 변동현황 (정기보고서)
  6. 임원·주요주주 소유보고 (지분공시)

Usage:
    from dart_disclosures import load_api_key, get_dart_disclosures_by_stock_code
    api_key = load_api_key()
    result = get_dart_disclosures_by_stock_code("005930", api_key, "20250101", "20251231")

Ref: https://opendart.fss.or.kr
"""

import io
import json
import logging
import time
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Optional

import requests

logger = logging.getLogger(__name__)

BASE_URL = "https://opendart.fss.or.kr/api"

REPRT_CODES = {
    "Q1": "11013",
    "half": "11012",
    "Q3": "11014",
    "annual": "11011",
}

STATUS_CODES = {
    "000": "정상",
    "010": "등록되지 않은 인증키",
    "013": "조회된 데이터가 없음",
    "020": "요청 제한 초과",
}

_corp_code_cache: dict[str, str] = {}
_corp_name_cache: dict[str, str] = {}


def load_api_key(config_path: str = "~/config.json") -> str:
    path = Path(config_path).expanduser()
    with open(path, "r", encoding="utf-8") as f:
        config = json.load(f)
    return config["dart"]["api_key"]


def _download_corp_code_xml(api_key: str) -> None:
    global _corp_code_cache, _corp_name_cache
    url = f"{BASE_URL}/corpCode.xml"
    resp = requests.get(url, params={"crtfc_key": api_key}, timeout=30)
    resp.raise_for_status()
    with zipfile.ZipFile(io.BytesIO(resp.content)) as zf:
        xml_name = zf.namelist()[0]
        with zf.open(xml_name) as xf:
            tree = ET.parse(xf)
    for item in tree.getroot().iter("list"):
        stock_code = (item.findtext("stock_code") or "").strip()
        corp_code = (item.findtext("corp_code") or "").strip()
        corp_name = (item.findtext("corp_name") or "").strip()
        if stock_code:
            _corp_code_cache[stock_code] = corp_code
            _corp_name_cache[stock_code] = corp_name


def stock_code_to_corp_code(stock_code: str, api_key: str) -> str:
    if not _corp_code_cache:
        _download_corp_code_xml(api_key)
    code = stock_code.zfill(6)
    if code not in _corp_code_cache:
        raise ValueError(f"종목코드 '{code}'에 해당하는 DART 고유번호를 찾을 수 없습니다.")
    return _corp_code_cache[code]


def _request(endpoint: str, params: dict, retry: int = 2) -> dict:
    url = f"{BASE_URL}/{endpoint}.json"
    for attempt in range(retry + 1):
        resp = requests.get(url, params=params, timeout=30)
        resp.raise_for_status()
        data = resp.json()
        status = data.get("status", "")
        if status == "000":
            return data
        if status == "013":
            return {"status": "013", "list": []}
        if status == "020" and attempt < retry:
            time.sleep(3)
            continue
        logger.error("[%s] API 오류: status=%s", endpoint, status)
        return data
    return data


def _get_all_reprt_codes(endpoint, api_key, corp_code, bsns_year, reprt_codes=None):
    codes = reprt_codes or list(REPRT_CODES.values())
    results = []
    for rc in codes:
        data = _request(endpoint, {
            "crtfc_key": api_key, "corp_code": corp_code,
            "bsns_year": bsns_year, "reprt_code": rc,
        })
        results.extend(data.get("list", []))
    return results


def get_treasury_stock_status(api_key, corp_code, bsns_year, reprt_codes=None):
    """자기주식 취득/처분 현황 (정기보고서)."""
    return _get_all_reprt_codes("tesstkAcqsDspsSttus", api_key, corp_code, bsns_year, reprt_codes)


def get_treasury_stock_acquisition(api_key, corp_code, bgn_de, end_de):
    """자기주식 취득 결정 (주요사항보고서)."""
    return _request("tsstkAqDecsn", {
        "crtfc_key": api_key, "corp_code": corp_code,
        "bgn_de": bgn_de, "end_de": end_de,
    }).get("list", [])


def get_treasury_stock_disposal(api_key, corp_code, bgn_de, end_de):
    """자기주식 처분 결정 (주요사항보고서)."""
    return _request("tsstkDpDecsn", {
        "crtfc_key": api_key, "corp_code": corp_code,
        "bgn_de": bgn_de, "end_de": end_de,
    }).get("list", [])


def get_dividend_info(api_key, corp_code, bsns_year, reprt_codes=None):
    """배당에 관한 사항 (정기보고서)."""
    return _get_all_reprt_codes("alotMatter", api_key, corp_code, bsns_year, reprt_codes)


def get_major_shareholder_changes(api_key, corp_code, bsns_year, reprt_codes=None):
    """최대주주 변동현황 (정기보고서)."""
    return _get_all_reprt_codes("hyslrChgSttus", api_key, corp_code, bsns_year, reprt_codes)


def get_executive_shareholder_report(api_key, corp_code):
    """임원·주요주주 소유보고 (지분공시)."""
    return _request("elestock", {
        "crtfc_key": api_key, "corp_code": corp_code,
    }).get("list", [])


def get_dart_disclosures(corp_code, api_key, start_date, end_date, bsns_year=None):
    """종목별 주요 공시 통합 조회."""
    if bsns_year is None:
        bsns_year = start_date[:4]
    annual_only = [REPRT_CODES["annual"]]

    return {
        "treasury_stock_status": get_treasury_stock_status(api_key, corp_code, bsns_year, annual_only),
        "treasury_stock_acquisition": get_treasury_stock_acquisition(api_key, corp_code, start_date, end_date),
        "treasury_stock_disposal": get_treasury_stock_disposal(api_key, corp_code, start_date, end_date),
        "dividend": get_dividend_info(api_key, corp_code, bsns_year, annual_only),
        "major_shareholder_changes": get_major_shareholder_changes(api_key, corp_code, bsns_year, annual_only),
        "executive_shareholder_report": get_executive_shareholder_report(api_key, corp_code),
    }


def get_dart_disclosures_by_stock_code(stock_code, api_key, start_date, end_date, bsns_year=None):
    """종목코드(6자리) 기반 주요 공시 통합 조회."""
    corp_code = stock_code_to_corp_code(stock_code, api_key)
    corp_name = _corp_name_cache.get(stock_code.zfill(6), "")
    result = get_dart_disclosures(corp_code, api_key, start_date, end_date, bsns_year)
    result["_meta"] = {
        "stock_code": stock_code, "corp_code": corp_code,
        "corp_name": corp_name, "start_date": start_date, "end_date": end_date,
    }
    return result
