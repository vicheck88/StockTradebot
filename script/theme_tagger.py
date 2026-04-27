"""
Step 2a theme tagger for screening_result.json.
Themes: 밸류업(고정) + AI반도체, 원전/전력, 방산, 조선, 로봇.
"""
import json
import re
import sys
from pathlib import Path

IN_PATH = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("screening_result.json")
OUT_PATH = Path(sys.argv[2]) if len(sys.argv) > 2 else Path("screening_tagged.json")

THEME_KEYWORDS = {
    "AI반도체": [
        "삼성전자", "SK하이닉스", "SK스퀘어", "DB하이텍", "한미반도체", "주성엔지니어링",
        "원익IPS", "원익QnC", "리노공업", "티씨케이", "동진쎄미켐", "솔브레인", "이오테크닉스",
        "디엔에프", "피에스케이", "유진테크", "네패스", "테스", "심텍", "대덕전자",
        "LX세미콘", "에스에프에이", "해성디에스", "덕산네오룩스", "에스앤에스텍", "HPSP",
        "파크시스템스", "케이씨텍", "와이아이케이", "실리콘투", "두산테스나", "엘비세미콘",
        "제주반도체", "에이디테크놀로지", "가온칩스", "샘씨엔에스", "유니테스트", "메타바이오메드",
        "퀄리타스반도체", "파두", "에이피알", "에이팩트", "와이씨", "넥스틴", "아이에이",
        "비에이치", "해성옵틱스", "LG이노텍", "LG디스플레이", "삼성디스플레이", "덕산하이메탈",
        "와이씨켐", "엑시콘", "오로스테크놀로지", "케이엔제이", "서플러스글로벌", "티이엠씨",
        "미코", "브이엠", "넥스트칩", "오픈엣지테크놀로지", "파이오링크",
    ],
    "원전/전력": [
        "한국전력", "한국가스공사", "한전KPS", "한전기술", "두산에너빌리티", "비에이치아이",
        "보성파워텍", "우진", "우진엔텍", "지투파워", "광명전기", "제룡전기", "제룡산업",
        "대한전선", "LS ELECTRIC", "LS전선", "효성중공업", "효성첨단소재", "현대일렉트릭",
        "일진전기", "가온전선", "서전기전", "산일전기", "선도전기", "대원전선",
        "SNT에너지", "삼광", "한신기계", "비츠로셀", "비츠로테크", "센트랄모텍", "태광",
        "성광벤드", "하이록코리아", "화성밸브", "조광ILI", "동국S&C",
    ],
    "방산": [
        "한화에어로스페이스", "한화시스템", "한화오션", "한국항공우주", "LIG넥스원", "현대로템",
        "풍산", "휴니드", "빅텍", "퍼스텍", "스페코", "삼양컴텍", "아이쓰리시스템",
        "코츠테크놀로지", "한화", "한화솔루션", "에스앤티모티브", "에스앤티다이내믹스", "SNT다이내믹스",
        "인텔리안테크", "쎄트렉아이", "AP위성", "한일단조", "케이피에프", "하이즈항공",
    ],
    "조선": [
        "HD현대", "HD한국조선해양", "HD현대중공업", "HD현대미포", "HD현대인프라코어",
        "HD현대건설기계", "HD현대일렉트릭", "HD현대마린솔루션",
        "삼성중공업", "한화오션", "대우조선해양", "케이에스피", "세진중공업", "동성화인텍",
        "HSD엔진", "STX엔진", "STX중공업", "STX", "태광", "성광벤드", "하이록코리아",
        "현대미포조선", "대창솔루션", "인화정공", "대양전기공업",
    ],
    "로봇": [
        "두산로보틱스", "레인보우로보틱스", "에스피지", "뉴로메카", "에스비비테크", "티로보틱스",
        "유일로보틱스", "로보스타", "해성티피씨", "코닉오토메이션", "삼익THK", "케이엔알시스템",
        "로보티즈", "휴림로봇", "링크제니시스", "하이젠알앤엠", "알에스오토메이션", "에스엠코어",
    ],
}

# theme name -> list of pre-compiled regex
COMPILED = {
    theme: re.compile("|".join(re.escape(k) for k in keys))
    for theme, keys in THEME_KEYWORDS.items()
}

# 산업분류 heuristic (보조)
INDUSTRY_BOOST = {
    "AI반도체": {"전기·전자"},
    "원전/전력": {"전기·가스", "전기·가스·수도", "전기·전자"},
    "조선": {"운송장비·부품"},
    "방산": {"운송장비·부품", "기계·장비"},
    "로봇": {"기계·장비", "전기·전자"},
}


def themes_for(row: dict) -> list[str]:
    name = row.get("종목명") or ""
    industry = row.get("산업분류") or ""
    pbr = row.get("PBR")
    mkt_rank = row.get("mkt_rank")

    tags: list[str] = []

    # 밸류업: PBR<1 AND 시총 상위 300위
    if isinstance(pbr, (int, float)) and pbr > 0 and pbr < 1.0 and mkt_rank and mkt_rank <= 300:
        tags.append("밸류업")

    for theme, regex in COMPILED.items():
        if regex.search(name):
            tags.append(theme)
            continue
        # industry fallback (only add when strong signal: exact industry belong + boost)
        if industry in INDUSTRY_BOOST.get(theme, set()):
            # industry alone is weak; only add for 전기·가스 -> 원전/전력 (small sector)
            if theme == "원전/전력" and industry in ("전기·가스", "전기·가스·수도"):
                tags.append(theme)
    return tags


def main() -> None:
    data = json.loads(IN_PATH.read_text())
    candidates = data["candidates"]

    counts: dict[str, int] = {}
    for row in candidates:
        tags = themes_for(row)
        row["themes"] = tags
        for t in tags:
            counts[t] = counts.get(t, 0) + 1

    data["meta"]["themes"] = {
        "fixed": ["밸류업"],
        "dynamic": ["AI반도체", "원전/전력", "방산", "조선", "로봇"],
        "counts": counts,
    }

    OUT_PATH.write_text(json.dumps(data, ensure_ascii=False, indent=2))
    print(f"wrote {OUT_PATH}")
    print("tag counts:")
    for t, n in sorted(counts.items(), key=lambda x: -x[1]):
        print(f"  {t}: {n}")


if __name__ == "__main__":
    main()
