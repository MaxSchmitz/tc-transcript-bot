#!/usr/bin/env bash
# Watches for iMessages and processes them with Claude Code.
# Uses imsg rpc (JSON-RPC over stdio) for robust message I/O.
# Claude Code auto-invokes the instagram-reel-transcript skill for Reel URLs.
# Only processes messages containing instagram.com/reel (prevents loops when self-testing).
# Requires bash 4+ (coproc). macOS: brew install bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${TC_PROJECT_DIR:-$(dirname "$SCRIPT_DIR")}"

# Load .env if it exists
if [ -f "$PROJECT_DIR/.env" ]; then
  set -a
  source "$PROJECT_DIR/.env"
  set +a
fi

CLAUDE_BIN="${CLAUDE_BIN:-claude}"
LOG_DIR="$PROJECT_DIR/logs"
ALLOWED_SENDERS_FILE="$PROJECT_DIR/allowed-senders.txt"

mkdir -p "$LOG_DIR"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_DIR/bot.log"
}

# Check if a sender is in the allowed list (re-reads file each time)
is_allowed_sender() {
  local check="$1"
  [ ! -f "$ALLOWED_SENDERS_FILE" ] && return 1
  while IFS= read -r entry || [ -n "$entry" ]; do
    entry="${entry%%#*}"          # strip comments
    entry="${entry// /}"          # strip spaces
    [ -z "$entry" ] && continue
    [ "$entry" = "$check" ] && return 0
  done < "$ALLOWED_SENDERS_FILE"
  return 1
}

# Start imsg rpc as a coprocess (JSON-RPC over stdio)
coproc IMSG { imsg rpc 2>>"$LOG_DIR/imsg-rpc-stderr.log"; }
sleep 0.5

if [[ -z "${IMSG_PID:-}" ]] || ! kill -0 "$IMSG_PID" 2>/dev/null; then
  log "ERROR: imsg rpc failed to start"
  exit 1
fi

cleanup() {
  kill "$IMSG_PID" 2>/dev/null || true
  wait "$IMSG_PID" 2>/dev/null || true
}
trap cleanup EXIT

REQ_ID=0

send_rpc() {
  local method="$1"
  local params="${2:-"{}"}"
  REQ_ID=$((REQ_ID + 1))
  local req
  req=$(jq -nc --arg m "$method" --argjson p "$params" --arg id "$REQ_ID" \
    '{jsonrpc:"2.0", id:($id|tonumber), method:$m, params:$p}')
  echo "$req" >&"${IMSG[1]}"
  log "RPC >> $req"
}

log "Bot started (rpc mode), using allowed-senders.txt"

# Subscribe to message notifications
send_rpc "watch.subscribe" '{"attachments":false}'

# Read lines from imsg rpc stdout
while IFS= read -r line <&"${IMSG[0]}"; do
  # Determine if this is a notification (has method, no id) or a response (has id)
  MSG_METHOD=$(echo "$line" | jq -r '.method // empty' 2>/dev/null) || continue

  # Log RPC responses (subscription confirmation, send confirmation)
  if [ -z "$MSG_METHOD" ]; then
    RESULT=$(echo "$line" | jq -c '.result // .error // empty' 2>/dev/null)
    [ -n "$RESULT" ] && log "RPC << $RESULT"
    continue
  fi

  # Handle error notifications
  if [ "$MSG_METHOD" = "error" ]; then
    log "RPC error: $(echo "$line" | jq -r '.params.error // "unknown"' 2>/dev/null)"
    continue
  fi

  # Only process message notifications
  [ "$MSG_METHOD" != "message" ] && continue

  # Extract message fields
  IS_FROM_ME=$(echo "$line" | jq -r '.params.message.is_from_me // false' 2>/dev/null)
  [ "$IS_FROM_ME" = "true" ] && continue

  # Check if this message is from an allowed sender
  SENDER=$(echo "$line" | jq -r '.params.message.sender // empty' 2>/dev/null)
  CHAT_IDENTIFIER=$(echo "$line" | jq -r '.params.message.chat_identifier // empty' 2>/dev/null)

  MATCH=false
  if is_allowed_sender "$SENDER" || is_allowed_sender "$CHAT_IDENTIFIER"; then
    MATCH=true
  fi
  [ "$MATCH" != "true" ] && continue

  TEXT=$(echo "$line" | jq -r '.params.message.text // empty' 2>/dev/null)
  CHAT_ID=$(echo "$line" | jq -r '.params.message.chat_id // empty' 2>/dev/null)

  # Only process messages containing an Instagram Reel URL
  if ! echo "$TEXT" | grep -qi 'instagram\.com/reel'; then
    continue
  fi

  log "Received: $TEXT"

  START_TIME=$(date +%s)
  log "Starting claude -p..."

  RESPONSE=$( cd "$PROJECT_DIR" && "$CLAUDE_BIN" -p "$TEXT" \
    --dangerously-skip-permissions --output-format text --verbose \
    2>>"$LOG_DIR/claude-verbose.log" < /dev/null ) || true
  END_TIME=$(date +%s)
  ELAPSED=$(( END_TIME - START_TIME ))

  if [ -z "$RESPONSE" ]; then
    RESPONSE="Something went wrong processing that. Check the logs."
    log "ERROR: Empty response after ${ELAPSED}s"
  else
    log "Success in ${ELAPSED}s"
  fi

  # Full response log
  {
    echo "=== $(date '+%Y-%m-%d %H:%M:%S') ==="
    echo "URL: $TEXT"
    echo "Duration: ${ELAPSED}s"
    echo "$RESPONSE"
    echo ""
  } >> "$LOG_DIR/responses.log"

  log "Responding (${#RESPONSE} chars, ${ELAPSED}s): ${RESPONSE:0:200}"

  # Reply via RPC -- prefer chat_id (most stable), fall back to sender
  ESCAPED_TEXT=$(echo "$RESPONSE" | jq -Rs '.')
  if [ -n "$CHAT_ID" ] && [ "$CHAT_ID" != "null" ]; then
    send_rpc "send" "{\"chat_id\":$CHAT_ID,\"text\":$ESCAPED_TEXT}"
  else
    ESCAPED_TO=$(printf '%s' "$SENDER" | jq -Rs '.')
    send_rpc "send" "{\"to\":$ESCAPED_TO,\"text\":$ESCAPED_TEXT}"
  fi
done

log "imsg rpc exited"
