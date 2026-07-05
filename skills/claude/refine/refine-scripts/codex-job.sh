#!/usr/bin/env bash
# codex-job.sh — /refine codex CLI job 발사/폴링 공통 스크립트.
#
# 서브커맨드:
#   codex-job.sh launch ROLE ROUND RUN PROMPT_FILE [TARGET_FILE...]
#     PROMPT_FILE(프롬프트 원문이 담긴 파일)을 codex task로 --background 발사하고,
#     stdout에 "TASK_ID=<id> OUTFILE=<path> ISOLATE=<dir|none>" 한 줄을 출력한다.
#     PROMPT_FILE 자리에 "-"를 주면 stdin에서 프롬프트 원문을 읽는다 — 호출부에서
#     `codex-job.sh launch ROLE ROUND RUN - <<PROMPT_EOF ... PROMPT_EOF` 형태로 프롬프트를
#     바로 heredoc으로 흘려 넣어, 임시 파일을 미리 만드는 단계를 생략할 수 있다.
#     TARGET_FILE...(가변 인자, 생략 가능)을 주면 --write 발사 직전 snapshot.sh로 그 파일들의
#     격리 스냅샷을 떠 ISOLATE 경로에 담는다 — codex가 이 파일을 직접 고치는 격리 위반이
#     감지되면 `git checkout HEAD --` 대신 이 스냅샷에서 복원한다(pre-해시 이전의 미커밋
#     변경까지 되돌리지 않는다. refine-steps.md `## Codex CLI job 호출 공통 규칙`의 격리 위반
#     문단). TARGET_FILE을 생략하면 ISOLATE=none이며, 그 경우 위반 시 자동 복구 없이 blocked로
#     보고한다.
#     CODEX_SCRIPT 미발견 시 "UNAVAILABLE" 출력 + exit 2 (## Codex CLI job 호출 공통 규칙 > ### 즉시 실패).
#     PROMPT_FILE read 실패 또는 빈 프롬프트 시 "EMPTY_PROMPT" 출력 + exit 3.
#     프롬프트가 150KB 초과 시 "OVERSIZE_PROMPT" 출력 + exit 4.
#     spawn 실패(task-id 캡처 불가) 시 "SPAWN_FAILED" 출력 + exit 5.
#     격리 스냅샷 실패(TARGET_FILE 지정 시 snapshot.sh 실패) 시 "ISOLATE_SNAPSHOT_FAILED" 출력 + exit 6.
#
#   codex-job.sh poll TASK_ID OUTFILE DEADLINE_TS
#     완료/실패/정체/타임아웃까지 polling하며 "=== <토큰> ===" 형태로 결과를 echo한다.
#     이 토큰 문자열은 refine-steps.md ## Codex CLI job 호출 공통 규칙의 "결과 분기" 표와 1:1 계약이다 —
#     문자열을 바꾸면 grep 기반 결과 판정이 깨진다. 절대 변경하지 말 것.
#     CODEX_SCRIPT 탐색이 시작부터 빈값이면 폴링 루프 진입 전 즉시 "=== UNAVAILABLE ===" 출력 + exit 2
#     (STALLED 오분류 방지 — ## Codex CLI job 호출 공통 규칙 > ### 즉시 실패로 연결).
#
# 결과 파일(OUTFILE) 네이밍:
#   기본값 : /tmp/refine_<ROLE>_r<ROUND>_<RUN>.md  (### 결과 파일 규칙 — role·round·run 유니크)
#   예외   : ROLE=codex-prep  → /tmp/codex_prenotes_<RUN>.md
#            ROLE=codex-audit → /tmp/codex_audit_<RUN>.md
#            (## Step 0 PREP은 라운드 개념이 없어 round-based 네이밍 대신 PREP 전용 고정명을 쓴다 —
#             문서 전역에서 이미 이 두 이름을 참조하므로 여기서만 별도 분기한다.)
set -uo pipefail

find_codex_script() {
  # 후보가 여럿이면 mtime 최신을 선택한다(-t: mtime 내림차순 정렬 → head -1).
  ls -1dt "$HOME"/.claude/plugins/cache/openai-codex/codex/*/scripts/codex-companion.mjs 2>/dev/null | head -1
}

outfile_for() {
  # outfile_for ROLE ROUND RUN
  case "$1" in
    codex-prep) echo "/tmp/codex_prenotes_${3}.md" ;;
    codex-audit) echo "/tmp/codex_audit_${3}.md" ;;
    *) echo "/tmp/refine_${1}_r${2}_${3}.md" ;;
  esac
}

cmd="${1:-}"; shift || true

case "$cmd" in
  launch)
    if [ "$#" -lt 4 ]; then
      echo "usage: codex-job.sh launch ROLE ROUND RUN PROMPT_FILE [TARGET_FILE...]" >&2
      exit 1
    fi
    ROLE="$1"; ROUND="$2"; RUN="$3"; PROMPT_FILE="$4"; shift 4
    TARGET_FILES=("$@")
    CODEX_SCRIPT="$(find_codex_script)"
    if [ -z "$CODEX_SCRIPT" ]; then
      echo "UNAVAILABLE"
      exit 2
    fi
    OUTFILE="$(outfile_for "$ROLE" "$ROUND" "$RUN")"
    rm -f "$OUTFILE"   # ### 결과 파일 규칙: 발사 전 이 run·role·round 파일만 제거(stale 방지). ⛔ 와일드카드·고정명 rm 금지 — 다른 세션 산출물을 지운다.
    if [ "$PROMPT_FILE" = "-" ]; then PROMPT_CONTENT="$(cat)"; else PROMPT_CONTENT="$(cat "$PROMPT_FILE" 2>/dev/null)"; fi
    if [ -z "$PROMPT_CONTENT" ]; then
      echo "EMPTY_PROMPT"
      echo "codex-job.sh launch: PROMPT_FILE 읽기 실패 또는 빈 프롬프트 ($PROMPT_FILE)" >&2
      exit 3
    fi
    PROMPT_BYTES=$(printf '%s' "$PROMPT_CONTENT" | wc -c | tr -d ' ')
    if [ "$PROMPT_BYTES" -gt 153600 ]; then   # 150KB(150*1024) — refine-steps.md ⚡ 속도 규칙 1 "프롬프트가 과대해지면(>150KB)" 기준과 동일
      echo "OVERSIZE_PROMPT"
      echo "codex-job.sh launch: 프롬프트가 150KB(${PROMPT_BYTES}B)를 초과했다 — 핵심 파일만 인라인하고 나머지는 경로로 축소하라" >&2
      exit 4
    fi
    ISOLATE="none"   # 격리 위반 복구 자산: TARGET_FILE이 있으면 --write 발사 직전 상태를 떠 두어, 위반 시 git checkout이 아니라 이 스냅샷에서 복원한다.
    if [ "${#TARGET_FILES[@]}" -gt 0 ]; then
      ISOLATE="/tmp/refine_isolate_${ROLE}_r${ROUND}_${RUN}"
      if ! "$(dirname "$0")/snapshot.sh" "$ISOLATE" "${TARGET_FILES[@]}" >/dev/null; then
        echo "ISOLATE_SNAPSHOT_FAILED"
        echo "codex-job.sh launch: 격리 스냅샷 실패 — $ISOLATE (codex 발사 보류)" >&2
        exit 6
      fi
    fi
    LAUNCH_OUT=$(node "$CODEX_SCRIPT" task --background --write "$PROMPT_CONTENT" 2>&1)
    # 발사 명령의 stdout에서 task ID를 직접 캡처한다 ("... started in the background as <task-id>" 형식).
    # status --all 로 찾지 않는다 — 동시 발사한 다른 role/task와 섞여 혼동된다.
    TASK_ID=$(echo "$LAUNCH_OUT" | sed -n 's/.*started in the background as \(task-[A-Za-z0-9_-]*\).*/\1/p' | head -1)
    if [ -z "$TASK_ID" ]; then
      echo "SPAWN_FAILED"
      echo "$LAUNCH_OUT" >&2
      exit 5
    fi
    echo "TASK_ID=$TASK_ID OUTFILE=$OUTFILE ISOLATE=$ISOLATE"
    ;;

  poll)
    if [ "$#" -lt 3 ]; then
      echo "usage: codex-job.sh poll TASK_ID OUTFILE DEADLINE_TS" >&2
      exit 1
    fi
    TASK_ID="$1"; OUTFILE="$2"
    # 한 작업(라운드) 안에서는 멤버 cap과 codex job cap이 이 DEADLINE_TS 하나를 공유한다(직렬 60분 방지) — 미설정 시에만 now+1800 fallback.
    DEADLINE_TS="${3:-$(( $(date +%s) + 1800 ))}"
    CODEX_SCRIPT="$(find_codex_script)"
    if [ -z "$CODEX_SCRIPT" ]; then
      echo "=== UNAVAILABLE ==="   # CODEX_SCRIPT 미발견 — 폴링 루프 진입 전 즉시 종료(300초 무변화 STALLED로 오분류되는 것을 방지)
      exit 2
    fi

    echo "POLL START $TASK_ID"   # 폴링 생존 마커: output 파일이 이 줄조차 없으면 루프가 시작 못 한 것(폴링 사망과 "아직 조용함"을 구분)
    LOG=""   # liveness probe용 job 로그 경로 — 루프마다 최신 status에서 재획득해 늦게 나타나는 Log: 경로까지 포착한다
    _it=0; _last_sig=""; _last_progress=$(date +%s)

    while true; do
      out=$(node "$CODEX_SCRIPT" status "$TASK_ID" 2>&1)
      _log_now=$(echo "$out" | sed -n 's/^  Log: //p' | head -1); [ -n "$_log_now" ] && LOG="$_log_now"
      # status <id> 단일 호출은 dash bullet 형식: "- $TASK_ID | <status> | rescue | Codex Task"
      # status --all 은 표 형식: "| $TASK_ID | rescue | <status> | ..." — 둘 다 매칭되도록 보수적 패턴 사용.
      # ⛔ 느슨한 `grep completed` 금지 — status 출력의 'Command completed: ...' 로그 echo 에 오탐해 codex 가 끝나기 전 completed 로 착각한다(실측 2026-06-16). 반드시 위처럼 task_id 라인 앵커.
      if echo "$out" | grep -E "(^- |^\| )$TASK_ID \|" | grep -qE "\b(completed)\b"; then
        # ⚠️ completed 직후 OUTFILE 이 host /tmp 로 flush 되기까지 수초 지연될 수 있다(실측: codex 가 정상 기록했는데 폴링이 그 전에 [ -s ] false 로 보고 EMPTY 오판→rm→직후 파일 출현). 즉시 EMPTY 판정 말고 grace-retry.
        # ⛔ result 폴백 금지: `result <id>` 는 codex *요약*("Wrote ... wc -l N")일 뿐 --write 파일 내용이 아니다 → 요약을 결과로 오인하면 채점 오염.
        for _i in $(seq 1 15); do [ -s "$OUTFILE" ] && break; sleep 2; done
        if [ -s "$OUTFILE" ]; then echo "=== DONE (file) ==="; else echo "=== EMPTY RESULT — codex 실패 처리 ==="; fi
        break
      fi
      if echo "$out" | grep -E "(^- |^\| )$TASK_ID \|" | grep -qE "\b(failed|cancelled)\b"; then
        echo "=== FAILED/CANCELLED ==="; break
      fi
      # ⚡ file-stable 조기 채택: status 가 completed 로 전이되지 않아도(실측 2026-07-03: 완결 보고 기록 후 25분+ running 잔존)
      #    OUTFILE 이 non-empty 이고 mtime 이 90초+ 정지면 결과가 이미 나온 것으로 보고 조기 break.
      #    호출자는 결과 분기 표의 완결 형식 게이트를 통과할 때만 채택한다 (부분 쓰기 오채택 방지).
      if [ -s "$OUTFILE" ]; then
        _now=$(date +%s); _mt=$(stat -f %m "$OUTFILE" 2>/dev/null || stat -c %Y "$OUTFILE" 2>/dev/null || echo "$_now")
        if [ $(( _now - _mt )) -ge 90 ]; then echo "=== DONE (file-stable, status!=completed) ==="; break; fi
      fi
      # ⚡ liveness probe — "실제 작업 중인가"를 관측한다: Phase 변화·job 로그(size/mtime) 성장·OUTFILE 변화 중
      #    무엇도 300초간 안 변하면 stalled 로 조기 종결(실측 2026-07-03: scorer r2 가 phase 'starting' 23분 정체 → 30분 deadline 전부 낭비. 이 probe 는 5분에 끊는다).
      _sig="$(echo "$out" | sed -n 's/^  Phase: //p')|$(stat -f '%z %m' "$LOG" 2>/dev/null || stat -c '%s %Y' "$LOG" 2>/dev/null)|$(stat -f %m "$OUTFILE" 2>/dev/null || stat -c %Y "$OUTFILE" 2>/dev/null)"
      if [ "$_sig" != "$_last_sig" ]; then _last_sig="$_sig"; _last_progress=$(date +%s); fi
      if [ $(( $(date +%s) - _last_progress )) -ge 300 ] && [ ! -s "$OUTFILE" ]; then
        echo "=== STALLED — cancel (phase/로그/산출물 300s 무변화) ==="; node "$CODEX_SCRIPT" cancel "$TASK_ID"; break
      fi
      # HEARTBEAT(~100초마다): 폴링 output 파일을 Read 하면 진행 이력이 보인다 — "지금 실제로 돌고 있나"의 관측 로그.
      _it=$(( _it + 1 ))
      [ $(( _it % 5 )) -eq 0 ] && echo "HEARTBEAT $(date +%H:%M:%S) phase=$(echo "$out" | sed -n 's/^  Phase: //p') log=$([ -f "$LOG" ] && wc -c < "$LOG" | tr -d ' ' || echo -)B out=$([ -s "$OUTFILE" ] && wc -c < "$OUTFILE" | tr -d ' ' || echo 0)B"
      if [ "$(date +%s)" -ge "$DEADLINE_TS" ]; then
        echo "=== DEADLINE TIMEOUT — cancel ==="; node "$CODEX_SCRIPT" cancel "$TASK_ID"; break
      fi
      sleep 20
    done
    ;;

  *)
    echo "usage: codex-job.sh launch ROLE ROUND RUN PROMPT_FILE | codex-job.sh poll TASK_ID OUTFILE DEADLINE_TS" >&2
    exit 1
    ;;
esac
