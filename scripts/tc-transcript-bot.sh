#!/bin/bash
# Watches for iMessages and processes them with Claude Code.
# Uses imsg (https://github.com/steipete/imsg) for message I/O.
# Claude Code auto-invokes the instagram-reel-transcript skill for Reel URLs.
# Only processes messages containing instagram.com/reel (prevents loops when self-testing).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${TC_PROJECT_DIR:-$(dirname "$SCRIPT_DIR")}"

# Load .env if it exists
if [ -f "$PROJECT_DIR/.env" ]; then
  set -a
  source "$PROJECT_DIR/.env"
  set +a
fi

WATCH_NUMBER="${TC_WATCH_NUMBER:?Set TC_WATCH_NUMBER (phone E.164 format or email, e.g. +15551234567 or user@icloud.com)}"
CLAUDE_BIN="${CLAUDE_BIN:-claude}"
LOG_DIR="$PROJECT_DIR/logs"

mkdir -p "$LOG_DIR"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_DIR/bot.log"
}

log "Bot started, watching for messages from $WATCH_NUMBER"

imsg watch --participants "$WATCH_NUMBER" --json | while IFS= read -r msg; do
  TEXT=$(echo "$msg" | jq -r '.text // empty')

  # Only process messages containing an Instagram Reel URL
  if ! echo "$TEXT" | grep -qi 'instagram\.com/reel'; then
    continue
  fi

  log "Received: $TEXT"

  RESPONSE=$( cd "$PROJECT_DIR" && "$CLAUDE_BIN" -p "$TEXT" --dangerously-skip-permissions --output-format text 2>&1 ) || true

  if [ -z "$RESPONSE" ]; then
    RESPONSE="Something went wrong processing that. Check the logs."
  fi

  log "Responding: $RESPONSE"
  imsg send --to "$WATCH_NUMBER" --text "$RESPONSE"
done
