#!/usr/bin/env bash
# round-diff.sh — /refine 라운드 diff 생성(APPLY 4번 codex-reviewer 프롬프트용, APPLY 8번 라운드 patch 저장 공용).
#
# 사용법: round-diff.sh BACKUP_DIR OUT_PATCH FILE...
#   snapshot.sh가 남긴 BACKUP_DIR/manifest.tsv("백업파일명<TAB>원본절대경로")로 FILE을 절대경로
#   매칭해 diff -u 누적으로 OUT_PATCH 에 쓴다. git diff가 아니라 백업 기준이다 — 이번 라운드
#   적용분만 정확히 담기고, 스냅샷 이전부터 있던 dirty 변경은 patch 밖에 자동으로 남는다.
#
#   manifest 행의 백업파일명이 "added"(스냅샷 시점에 파일 부재)면 diff -u /dev/null 현재파일 로
#   신규 파일을 patch에 담는다. 백업은 있는데 현재 FILE이 사라졌으면(이번 라운드에 삭제) diff -u
#   백업 /dev/null 로 삭제를 patch에 담는다.
#
#   FILE의 절대경로가 manifest에 없음(스냅샷되지 않은 대상) → stderr에 "MISSING BACKUP: <path>" 경고,
#   전체 처리 후 exit 1 (호출자는 codex-reviewer 발사 전에 backup 경로부터 해결해야 한다).
#   diff -u 종료코드 2 이상(파일 접근 오류 등)은 "차이 있음"(rc=1)과 구분해 즉시 exit 2 — 오류를
#   빈 patch·정상 무변화와 혼동하지 않는다.
#   변경 파일이 있는데 OUT_PATCH가 비면(diff -u는 차이 없을 때만 0바이트) stderr에 경고를 남기고
#   exit 1 — 빈 diff를 "리뷰 완료"로 오인해 codex-reviewer를 발사하지 않도록 호출자가 진행을 멈추고
#   재확인해야 한다는 신호다(APPLY 1번에서 이미 Edit이 적용된 뒤라 정상 라운드라면 비어 있을 수 없다).
set -uo pipefail

if [ "$#" -lt 3 ]; then
  echo "usage: round-diff.sh BACKUP_DIR OUT_PATCH FILE..." >&2
  exit 1
fi

BACKUP_DIR="$1"; shift
OUT_PATCH="$1"; shift
FILES=("$@")
MANIFEST="$BACKUP_DIR/manifest.tsv"

abs_path() {
  case "$1" in
    /*) printf '%s' "$1" ;;
    *)  printf '%s/%s' "$(pwd)" "$1" ;;
  esac
}

# run_diff OLD NEW — diff -u 실행 후 차이가 있으면 OUT_PATCH 에 누적.
# rc 0(무변경)/1(차이있음)은 정상, rc>=2(파일 접근 오류 등)는 즉시 exit 2로 "차이 있음"과 구분한다.
run_diff() {
  local old="$1" new="$2" out rc
  out="$(diff -u "$old" "$new")"
  rc=$?
  if [ "$rc" -ge 2 ]; then
    echo "round-diff.sh: diff 오류(rc=$rc) — $old / $new" >&2
    exit 2
  fi
  if [ -n "$out" ]; then
    printf '%s\n' "$out" >> "$OUT_PATCH"
  fi
}

: > "$OUT_PATCH"
MISSING=0
for f in "${FILES[@]}"; do
  ABS="$(abs_path "$f")"
  ROW=""
  if [ -f "$MANIFEST" ]; then
    ROW="$(awk -F'\t' -v p="$ABS" '$2 == p { print; exit }' "$MANIFEST")"
  fi
  if [ -z "$ROW" ]; then
    echo "MISSING BACKUP: $ABS" >&2
    MISSING=1
    continue
  fi
  bn="${ROW%%$'\t'*}"
  if [ "$bn" = "added" ]; then
    if [ ! -f "$f" ]; then
      echo "added target never created: $ABS" >&2
      MISSING=1
      continue
    fi
    run_diff /dev/null "$f"
    continue
  fi
  if [ ! -f "$BACKUP_DIR/$bn" ]; then
    echo "MISSING BACKUP: $ABS" >&2
    MISSING=1
    continue
  fi
  if [ ! -f "$f" ]; then
    run_diff "$BACKUP_DIR/$bn" /dev/null
    continue
  fi
  run_diff "$BACKUP_DIR/$bn" "$f"
done

if [ "$MISSING" -eq 1 ]; then
  echo "round-diff.sh: backup 누락으로 diff 불완전 — codex-reviewer 발사 전 backup 경로부터 해결하라" >&2
  exit 1
fi

if [ ! -s "$OUT_PATCH" ]; then
  echo "WARNING: $OUT_PATCH 가 비어 있다 — 이번 라운드에 실제 변경이 없는지 확인하라(빈 diff를 리뷰 완료로 오인 금지)" >&2
  echo "round-diff.sh: 빈 diff — codex-reviewer 발사 전 Edit 적용 여부·대상 경로부터 재확인하라" >&2
  exit 1
fi

echo "$OUT_PATCH"
