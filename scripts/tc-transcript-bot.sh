#!/usr/bin/env bash
# Watches for iMessages and processes them with Claude Code.
# Uses imsg rpc (JSON-RPC over stdio) for robust message I/O.
# Claude Code auto-invokes the content-pipeline skill for any URL.
# Requires bash 5+ (coproc + associative arrays). macOS: brew install bash
#
# Message accumulation: iMessage splits "text + URL" into separate deliveries.
# This script buffers messages per-sender for BUFFER_WINDOW seconds so split
# parts arrive as one concatenated prompt to Claude.

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

# --- Message accumulation buffer ---
# iMessage splits messages with URLs into separate deliveries.
# Buffer messages per-sender and flush after BUFFER_WINDOW seconds.
declare -A MSG_BUFFER          # buffer_key -> accumulated text
declare -A BUFFER_TIME         # buffer_key -> epoch when first message buffered
declare -A BUFFER_SENDER_NAME  # buffer_key -> sender display name
declare -A BUFFER_CHAT_ID      # buffer_key -> numeric chat_id for reply
declare -A BUFFER_SENDER_ID    # buffer_key -> sender identifier for fallback reply
BUFFER_WINDOW=3                # seconds to wait for split message parts

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_DIR/bot.log"
}

# Check if a sender is in the allowed list (re-reads file each time)
# Sets SENDER_NAME as a side effect when matched
is_allowed_sender() {
  local check="$1"
  [ ! -f "$ALLOWED_SENDERS_FILE" ] && return 1
  while IFS= read -r entry || [ -n "$entry" ]; do
    entry="${entry%%#*}"          # strip comments
    entry="${entry// /}"          # strip leading/trailing spaces
    [ -z "$entry" ] && continue
    local id="${entry%%|*}"       # part before pipe
    id="${id// /}"
    [ "$id" = "$check" ] && {
      # Extract name if pipe-delimited
      if [[ "$entry" == *"|"* ]]; then
        SENDER_NAME="${entry#*|}"
        SENDER_NAME="${SENDER_NAME## }"  # trim leading space
      fi
      return 0
    }
  done < "$ALLOWED_SENDERS_FILE"
  return 1
}

# Process a buffered message: run claude -p, log, reply
process_message() {
  local text="$1"
  local sender_name="$2"
  local chat_id="$3"
  local sender_id="$4"

  log "Processing buffered message: ${text:0:200}"

  local start_time end_time elapsed
  start_time=$(date +%s)
  log "Starting claude -p..."

  local prompt="$text"
  if [ -n "$sender_name" ]; then
    prompt="[Sender: $sender_name] $text"
  fi

  local response
  response=$( cd "$PROJECT_DIR" && "$CLAUDE_BIN" -p "$prompt" \
    --dangerously-skip-permissions --output-format text --verbose \
    2>>"$LOG_DIR/claude-verbose.log" < /dev/null ) || true
  end_time=$(date +%s)
  elapsed=$(( end_time - start_time ))

  if [ -z "$response" ]; then
    response="Something went wrong processing that. Check the logs."
    log "ERROR: Empty response after ${elapsed}s"
  else
    log "Success in ${elapsed}s"
  fi

  # Full response log
  {
    echo "=== $(date '+%Y-%m-%d %H:%M:%S') ==="
    echo "Input: $text"
    echo "Duration: ${elapsed}s"
    echo "$response"
    echo ""
  } >> "$LOG_DIR/responses.log"

  log "Responding (${#response} chars, ${elapsed}s): ${response:0:200}"

  # Reply via RPC -- prefer chat_id (most stable), fall back to sender
  local escaped_text
  escaped_text=$(echo "$response" | jq -Rs '.')
  if [ -n "$chat_id" ] && [ "$chat_id" != "null" ]; then
    send_rpc "send" "{\"chat_id\":$chat_id,\"text\":$escaped_text}"
  else
    local escaped_to
    escaped_to=$(printf '%s' "$sender_id" | jq -Rs '.')
    send_rpc "send" "{\"to\":$escaped_to,\"text\":$escaped_text}"
  fi
}

# Flush any buffers whose accumulation window has expired
flush_expired_buffers() {
  local now
  now=$(date +%s)
  for key in "${!BUFFER_TIME[@]}"; do
    local elapsed=$(( now - BUFFER_TIME[$key] ))
    if (( elapsed >= BUFFER_WINDOW )); then
      log "Buffer flush [$key]: ${MSG_BUFFER[$key]:0:200}"
      process_message "${MSG_BUFFER[$key]}" "${BUFFER_SENDER_NAME[$key]}" "${BUFFER_CHAT_ID[$key]}" "${BUFFER_SENDER_ID[$key]}"
      unset "MSG_BUFFER[$key]" "BUFFER_TIME[$key]" "BUFFER_SENDER_NAME[$key]" "BUFFER_CHAT_ID[$key]" "BUFFER_SENDER_ID[$key]"
    fi
  done
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

log "Bot started (rpc mode), using allowed-senders.txt, buffer=${BUFFER_WINDOW}s"

# Subscribe to message notifications
send_rpc "watch.subscribe" '{"attachments":false}'

# Main loop: read with 1s timeout, buffer messages, flush when window expires
while true; do
  # Check if imsg rpc is still alive
  if ! kill -0 "$IMSG_PID" 2>/dev/null; then
    log "imsg rpc process died, exiting"
    break
  fi

  # Read with timeout so we can flush buffers even when no messages arrive
  if IFS= read -t 1 -r line <&"${IMSG[0]}"; then
    # Determine if this is a notification (has method, no id) or a response (has id)
    MSG_METHOD=$(echo "$line" | jq -r '.method // empty' 2>/dev/null) || { flush_expired_buffers; continue; }

    # Log RPC responses (subscription confirmation, send confirmation)
    if [ -z "$MSG_METHOD" ]; then
      RESULT=$(echo "$line" | jq -c '.result // .error // empty' 2>/dev/null)
      [ -n "$RESULT" ] && log "RPC << $RESULT"
      flush_expired_buffers
      continue
    fi

    # Handle error notifications
    if [ "$MSG_METHOD" = "error" ]; then
      log "RPC error: $(echo "$line" | jq -r '.params.error // "unknown"' 2>/dev/null)"
      flush_expired_buffers
      continue
    fi

    # Only process message notifications
    if [ "$MSG_METHOD" != "message" ]; then
      flush_expired_buffers
      continue
    fi

    # Extract message fields
    IS_FROM_ME=$(echo "$line" | jq -r '.params.message.is_from_me // false' 2>/dev/null)
    if [ "$IS_FROM_ME" = "true" ]; then
      flush_expired_buffers
      continue
    fi

    # Check if this message is from an allowed sender
    SENDER=$(echo "$line" | jq -r '.params.message.sender // empty' 2>/dev/null)
    CHAT_IDENTIFIER=$(echo "$line" | jq -r '.params.message.chat_identifier // empty' 2>/dev/null)

    SENDER_NAME="${SENDER:-$CHAT_IDENTIFIER}"
    MATCH=false
    if is_allowed_sender "$SENDER" || is_allowed_sender "$CHAT_IDENTIFIER"; then
      MATCH=true
    fi
    if [ "$MATCH" != "true" ]; then
      flush_expired_buffers
      continue
    fi

    TEXT=$(echo "$line" | jq -r '.params.message.text // empty' 2>/dev/null)
    CHAT_ID=$(echo "$line" | jq -r '.params.message.chat_id // empty' 2>/dev/null)

    # Skip empty messages (tapbacks, reactions, etc.)
    if [ -z "$TEXT" ]; then
      flush_expired_buffers
      continue
    fi

    log "Received: $TEXT"

    # Buffer key: use chat_id if available, fall back to sender identifier
    BUFFER_KEY="${CHAT_ID:-${SENDER:-$CHAT_IDENTIFIER}}"

    if [[ -v "MSG_BUFFER[$BUFFER_KEY]" ]]; then
      # Append to existing buffer
      MSG_BUFFER[$BUFFER_KEY]="${MSG_BUFFER[$BUFFER_KEY]}"$'\n'"$TEXT"
      log "Buffer append [$BUFFER_KEY]: now ${#MSG_BUFFER[$BUFFER_KEY]} chars"
    else
      # Start new buffer
      MSG_BUFFER[$BUFFER_KEY]="$TEXT"
      BUFFER_TIME[$BUFFER_KEY]=$(date +%s)
      BUFFER_SENDER_NAME[$BUFFER_KEY]="$SENDER_NAME"
      BUFFER_SENDER_ID[$BUFFER_KEY]="$SENDER"
      log "Buffer start [$BUFFER_KEY]: $TEXT"
    fi
    # Always update chat_id in case the URL part has a better one
    BUFFER_CHAT_ID[$BUFFER_KEY]="$CHAT_ID"
  fi

  # Flush any buffers past the accumulation window
  flush_expired_buffers
done

log "imsg rpc exited"
