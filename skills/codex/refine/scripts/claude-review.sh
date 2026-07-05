#!/bin/bash
# Runs a non-interactive Claude Code review prompt.
# Exit 0: review output on stdout.
# Exit 10: Claude unavailable; caller should fall back to Codex-only review.
# Exit 11: caller error.

set -u

TIMEOUT_SECONDS=${CLAUDE_REVIEW_TIMEOUT_SECONDS:-1800}
CLAUDE_REVIEW_MODEL=${CLAUDE_REVIEW_MODEL:-sonnet}
PROMPT=$(cat)

if [ -z "$PROMPT" ]; then
  echo "CLAUDE_REVIEW_UNAVAILABLE: empty prompt" >&2
  exit 11
fi

if ! command -v claude >/dev/null 2>&1; then
  echo "CLAUDE_REVIEW_UNAVAILABLE: claude CLI not found" >&2
  exit 10
fi

VERSION=$(claude --version 2>&1)
VERSION_STATUS=$?
if [ "$VERSION_STATUS" -ne 0 ]; then
  echo "CLAUDE_REVIEW_UNAVAILABLE: claude --version failed: $(printf '%s' "$VERSION" | head -1)" >&2
  exit 10
fi

OUT_FILE=$(mktemp "${TMPDIR:-/tmp}/claude-review-out.XXXXXX")
ERR_FILE=$(mktemp "${TMPDIR:-/tmp}/claude-review-err.XXXXXX")
cleanup() {
  rm -f "$OUT_FILE" "$ERR_FILE"
}
trap cleanup EXIT

claude --model "$CLAUDE_REVIEW_MODEL" -p "$PROMPT" >"$OUT_FILE" 2>"$ERR_FILE" &
PID=$!
START=$SECONDS

while kill -0 "$PID" 2>/dev/null; do
  if [ $((SECONDS - START)) -ge "$TIMEOUT_SECONDS" ]; then
    kill "$PID" 2>/dev/null || true
    sleep 1
    kill -9 "$PID" 2>/dev/null || true
    echo "CLAUDE_REVIEW_UNAVAILABLE: timed out after ${TIMEOUT_SECONDS}s" >&2
    exit 10
  fi
  sleep 1
done

wait "$PID"
STATUS=$?

if [ "$STATUS" -ne 0 ]; then
  REASON=$(head -20 "$ERR_FILE" | tr '\n' ' ' | sed 's/[[:space:]][[:space:]]*/ /g')
  if [ -z "$REASON" ]; then
    REASON=$(head -20 "$OUT_FILE" | tr '\n' ' ' | sed 's/[[:space:]][[:space:]]*/ /g')
  fi
  echo "CLAUDE_REVIEW_UNAVAILABLE: claude --model $CLAUDE_REVIEW_MODEL -p failed with status $STATUS: $REASON" >&2
  exit 10
fi

if [ ! -s "$OUT_FILE" ]; then
  echo "CLAUDE_REVIEW_UNAVAILABLE: empty claude output" >&2
  exit 10
fi

cat "$OUT_FILE"
