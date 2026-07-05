#!/usr/bin/env bash
# snapshot.sh — /refine APPLY 0번 스냅샷(ROLLBACK 자산) + codex 격리 위반 복원.
#
# 사용법: snapshot.sh BACKUP_DIR FILE...
#   대상 파일들의 pre-해시(shasum)를 BACKUP_DIR/pre.sha 에 기록하고, git 여부와 무관하게
#   각 파일을 BACKUP_DIR 로 cp 한다. 라운드 diff(round-diff.sh)와 ROLLBACK 역적용은 이 백업을
#   기준으로 한다 — pre-해시 이전부터 있던 dirty 변경도 백업에 그대로 담겨, 이번 라운드
#   적용분과 자동으로 분리된다.
#
#   BACKUP_DIR/manifest.tsv: "백업파일명<TAB>원본절대경로" 한 줄씩 기록한다. 백업 파일명은
#   원본 절대경로의 '/'를 '__'로 치환해 유니크화한다 — 서로 다른 디렉토리의 동일 basename이
#   같은 백업 파일을 덮어쓰는 충돌을 없앤다. 대상 파일이 스냅샷 시점에 아직 없으면(이번
#   라운드에 새로 생성될 파일) 백업 자체는 생략하고 백업파일명 자리에 "added"를 기록한다 —
#   round-diff.sh가 이 행을 `diff -u /dev/null 현재파일`로 처리해 신규 파일을 patch에 담는다.
#   지원 경로는 TAB·개행을 포함하지 않는 일반 파일시스템 경로다 — /refine 대상은 항상 이 범위 안의
#   문서·스크립트·소스 경로이므로 manifest.tsv의 TAB 구분 파싱 범위와 정확히 일치한다.
#
# 사용법: snapshot.sh restore BACKUP_DIR
#   위 스냅샷을 manifest.tsv 기준으로 원본 절대경로에 되돌린다(일반 행=cp, "added" 행=rm).
#   codex-job.sh launch가 --write 발사 직전 떠 두는 격리 스냅샷의 복원 경로로 쓰인다(refine-steps.md
#   `## Codex CLI job 호출 공통 규칙`의 격리 위반 문단) — `git checkout HEAD --`와 달리 pre-해시
#   이전의 미커밋 변경을 건드리지 않고 정확히 이 스냅샷 시점 상태로만 되돌린다. manifest 행 하나라도
#   백업 파일이 없으면 그 행에서 즉시 실패(exit 1)한다 — 호출자는 부분 복원 상태로 방치하지 말고
#   blocked로 보고해야 한다.
set -euo pipefail

if [ "${1:-}" = "restore" ]; then
  shift
  if [ "$#" -lt 1 ]; then
    echo "usage: snapshot.sh restore BACKUP_DIR" >&2
    exit 1
  fi
  BACKUP_DIR="$1"
  MANIFEST="$BACKUP_DIR/manifest.tsv"
  if [ ! -f "$MANIFEST" ]; then
    echo "snapshot.sh restore: manifest 없음 — $MANIFEST" >&2
    exit 1
  fi
  while IFS=$'\t' read -r bn abs; do
    [ -z "$abs" ] && continue
    if [ "$bn" = "added" ]; then
      rm -f "$abs"
    else
      if [ ! -f "$BACKUP_DIR/$bn" ]; then
        echo "snapshot.sh restore: 백업 파일 없음 — $BACKUP_DIR/$bn (원본 $abs)" >&2
        exit 1
      fi
      cp "$BACKUP_DIR/$bn" "$abs"
    fi
  done < "$MANIFEST"
  echo "$BACKUP_DIR"
  exit 0
fi

if [ "$#" -lt 2 ]; then
  echo "usage: snapshot.sh BACKUP_DIR FILE..." >&2
  exit 1
fi

BACKUP_DIR="$1"; shift
FILES=("$@")

abs_path() {
  case "$1" in
    /*) printf '%s' "$1" ;;
    *)  printf '%s/%s' "$(pwd)" "$1" ;;
  esac
}

mangle() {
  # 절대경로의 '/'를 '__'로 치환해 유니크한 백업 파일명을 만든다(basename 충돌 제거).
  local abs="${1#/}"
  printf '%s' "${abs//\//__}"
}

mkdir -p "$BACKUP_DIR"
: > "$BACKUP_DIR/pre.sha"
: > "$BACKUP_DIR/manifest.tsv"
for f in "${FILES[@]}"; do
  ABS="$(abs_path "$f")"
  if [ ! -f "$f" ]; then
    printf 'added\t%s\n' "$ABS" >> "$BACKUP_DIR/manifest.tsv"
    continue
  fi
  BN="$(mangle "$ABS")"
  printf '%s\t%s\n' "$BN" "$ABS" >> "$BACKUP_DIR/manifest.tsv"
  shasum "$f" >> "$BACKUP_DIR/pre.sha"
  cp "$f" "$BACKUP_DIR/$BN"
done

echo "$BACKUP_DIR"
