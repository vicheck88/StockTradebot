#!/usr/bin/env bash
# ctx-package.sh — /refine codex 호출용 컨텍스트 인라인 패키징.
#
# 사용법: ctx-package.sh [--full] RUN BASE PATH...
#   --full  : diff 대신 대상 파일 전문을 패키징한다. doc:* 사전 audit·라운드 1 전체 채점처럼
#             diff가 아니라 전문이 필요할 때 호출자가 명시한다(## Codex CLI job 호출 공통 규칙
#             > ### ⚡ 속도 규칙 1 참조). 생략하면 아래 판정을 따른다.
#   RUN     : 세션·run 유니크 토큰 (## Step 0 PREP 1번에서 잡은 값을 그대로 넘긴다 — 여기서 새로 잡지 않는다)
#   BASE    : diff 비교 기준 커밋/브랜치. 호출자가 미리 결정해서 넘긴다
#             (PR 브랜치면 git merge-base HEAD <기본 브랜치(main→develop 순 존재 확인)>,
#              PR이 아니면 라운드 시작 시점 HEAD 고정 — 이 판단은 이 스크립트의 책임이 아니다).
#   PATH... : 패키징 대상 파일(복수 가능).
#
# 판정(## Codex CLI job 호출 공통 규칙 > ### ⚡ 속도 규칙 1 원문 로직 이식):
#   --full                                                     → 대상 파일 전문을 "=== 파일 ===" 헤더와 함께 cat
#   git 저장소 + working tree dirty(대상 경로에 미커밋 변경 있음) → two-dot: git diff BASE -- PATHS  (dirty tree 포함)
#   git 저장소 + clean                                        → three-dot: git diff BASE...HEAD -- PATHS (커밋된 변경만)
#   non-git                                                    → 대상 파일 전문을 "=== 파일 ===" 헤더와 함께 cat
#   (위 git 판정 결과 diff가 빈 파일 — 예: 라운드 1 PREP처럼 BASE==HEAD — 이면 빈 .diff를 지우고 전문 cat으로
#    자동 폴백해, 호출자의 "-f .diff || .txt" 산출물 선택이 정확히 .txt 하나만 보게 한다)
#
# RUN당 아티팩트 1개 보장: 매 호출은 이번에 만들 유형과 반대되는 유형의 stale 산출물을 rm한다
# (--full 호출 → 이전 .diff 제거, diff 모드 호출 → 이전 .txt 제거). 같은 RUN에서 diff 호출과
# --full 호출이 번갈아 일어나도(예: delta 라운드 뒤 doc:* 전체 재audit) 호출자의 "-f .diff || .txt"
# 재도출이 항상 가장 최근 호출의 산출물만 가리키게 하기 위함이다.
#
# 산출 파일 경로를 stdout에 1줄 출력한다(diff 모드: /tmp/refine_ctx_<RUN>.diff, cat 모드: /tmp/refine_ctx_<RUN>.txt).
set -euo pipefail

MODE="diff"
if [ "${1:-}" = "--full" ]; then
  MODE="full"
  shift
fi

if [ "$#" -lt 3 ]; then
  echo "usage: ctx-package.sh [--full] RUN BASE PATH..." >&2
  exit 1
fi

RUN="$1"; shift
BASE="$1"; shift
PATHS=("$@")

pack_full() {
  local out="/tmp/refine_ctx_${RUN}.txt"
  rm -f "/tmp/refine_ctx_${RUN}.diff"   # RUN당 아티팩트 1개만 남긴다 — stale .diff가 이번 .txt(전문)를 가리지 않도록 제거.
  : > "$out"
  for f in "${PATHS[@]}"; do
    echo "=== $f ===" >> "$out"
    cat "$f" >> "$out"
  done
  echo "$out"
}

if [ "$MODE" = "full" ]; then
  OUT="$(pack_full)"
elif git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  OUT="/tmp/refine_ctx_${RUN}.diff"
  rm -f "/tmp/refine_ctx_${RUN}.txt"   # RUN당 아티팩트 1개만 남긴다 — stale .txt가 이번 .diff를 가리지 않도록 제거.
  if [ -n "$(git status --porcelain -- "${PATHS[@]}")" ]; then
    git diff "$BASE" -- "${PATHS[@]}" > "$OUT"          # dirty tree 포함(two-dot)
  else
    git diff "$BASE"...HEAD -- "${PATHS[@]}" > "$OUT"   # 커밋된 변경만(three-dot)
  fi
  if [ ! -s "$OUT" ]; then
    echo "ctx-package.sh: diff가 비어 있어 전문 cat으로 폴백한다 (BASE==HEAD 등)" >&2
    rm -f "$OUT"   # 빈 .diff를 남기지 않는다 — 호출자가 "-f .diff || .txt"로 산출물을 찾을 때 빈 .diff를 오채택하지 않도록 정확히 하나만 남긴다.
    OUT="$(pack_full)"
  fi
else
  OUT="$(pack_full)"
fi

echo "$OUT"
