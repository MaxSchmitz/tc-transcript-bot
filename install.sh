#!/bin/bash
# TC Transcript Bot installer
# Text an Instagram Reel link via iMessage, get back a Google Doc with the transcript.

set -euo pipefail

echo "=== TC Transcript Bot Setup ==="
echo ""

# --- Check for Homebrew ---
if ! command -v brew &>/dev/null; then
  echo "Homebrew is required. Install it from https://brew.sh"
  exit 1
fi

# --- Install dependencies ---
echo "Installing dependencies..."
brew install steipete/tap/imsg jq ffmpeg yt-dlp 2>/dev/null || true

# Verify
for cmd in imsg jq ffmpeg yt-dlp; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: $cmd failed to install."
    exit 1
  fi
done
echo "All dependencies installed."
echo ""

# --- Check for Claude Code ---
if ! command -v claude &>/dev/null; then
  echo "Claude Code is required. Install it from https://claude.ai/download"
  exit 1
fi
CLAUDE_BIN=$(which claude)
echo "Found Claude Code at $CLAUDE_BIN"
echo ""

# --- Project directory ---
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
echo "Project directory: $PROJECT_DIR"
echo ""

# --- macOS permissions ---
echo "=== macOS Permissions ==="
echo ""
echo "imsg needs two permissions to work:"
echo ""
echo "1. Full Disk Access (to read the Messages database)"
echo "   System Settings > Privacy & Security > Full Disk Access"
echo "   Enable: $(basename "$SHELL") or your terminal app"
echo ""
echo "2. Automation (to send messages via Messages.app)"
echo "   This will prompt automatically on first use."
echo ""

# Test if Full Disk Access is granted
if imsg chats --limit 1 --json &>/dev/null; then
  echo "Full Disk Access: OK"
else
  echo "Full Disk Access: NOT GRANTED"
  echo "Please grant it now, then re-run this script."
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
  exit 1
fi
echo ""

# --- Instagram ---
echo "=== Instagram ==="
echo ""
echo "yt-dlp uses Chrome cookies to download Reels."
echo "Make sure you are logged into Instagram in Google Chrome."
echo ""
read -p "Are you logged into Instagram in Chrome? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Please log in first, then re-run this script."
  open -a "Google Chrome" "https://www.instagram.com/"
  exit 1
fi
echo ""

# --- Environment variables ---
echo "=== Configuration ==="
echo ""

read -p "Phone number or iMessage email to watch (e.g. +15551234567 or user@icloud.com): " WATCH_NUMBER
read -p "Deepgram API key (from deepgram.com): " DEEPGRAM_KEY

echo ""
echo "Optional: Instagram credentials for auto-login on cookie expiry."
echo "Leave blank to skip (you'll need to manually re-login when cookies expire)."
read -p "Instagram username (or blank): " INSTA_USER
read -p "Instagram password (or blank): " INSTA_PASS

# --- Google Drive for Desktop ---
echo ""
echo "=== Google Drive ==="
echo ""
echo "Install Google Drive for Desktop if you haven't already:"
echo "  https://www.google.com/drive/download/"
echo ""
echo "The bot saves transcripts to a local folder that Google Drive syncs automatically."
echo "Default location: $HOME/Google Drive/My Drive/TC Transcripts"
echo ""
read -p "Google Drive transcript folder path (or press Enter for default): " GDRIVE_DIR
if [ -z "$GDRIVE_DIR" ]; then
  GDRIVE_DIR="$HOME/Google Drive/My Drive/TC Transcripts"
fi
mkdir -p "$GDRIVE_DIR"
echo "Transcript folder: $GDRIVE_DIR"

# Write .env file
cat > "$PROJECT_DIR/.env" << EOF
TC_WATCH_NUMBER="$WATCH_NUMBER"
TC_PROJECT_DIR="$PROJECT_DIR"
CLAUDE_BIN="$CLAUDE_BIN"
DEEPGRAM_API_KEY="$DEEPGRAM_KEY"
INSTAGRAM_USER="$INSTA_USER"
INSTAGRAM_PASS="$INSTA_PASS"
GDRIVE_TRANSCRIPT_DIR="$GDRIVE_DIR"
PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin"
EOF

echo ""
echo "Saved config to $PROJECT_DIR/.env"
echo ""

# --- Install launchd agent ---
echo "=== Auto-start ==="
echo ""

PLIST_NAME="com.thoughtcatalog.transcript-bot"
PLIST_SRC="$PROJECT_DIR/scripts/$PLIST_NAME.plist"
PLIST_DST="$HOME/Library/LaunchAgents/$PLIST_NAME.plist"

# Generate plist from .env values
cat > "$PLIST_DST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$PLIST_NAME</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>source "$PROJECT_DIR/.env" &amp;&amp; exec "$PROJECT_DIR/scripts/tc-transcript-bot.sh"</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$PROJECT_DIR/logs/launchd-stdout.log</string>
    <key>StandardErrorPath</key>
    <string>$PROJECT_DIR/logs/launchd-stderr.log</string>
</dict>
</plist>
EOF

read -p "Start the bot now and on every login? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
  launchctl load "$PLIST_DST"
  echo "Bot started. It will also start automatically on login."
else
  echo "Skipped. To start later:"
  echo "  launchctl load $PLIST_DST"
fi
echo ""

# --- Test ---
echo "=== Test ==="
echo ""
echo "To test manually:"
echo "  source $PROJECT_DIR/.env && $PROJECT_DIR/scripts/tc-transcript-bot.sh"
echo ""
echo "Then text an Instagram Reel link to the watched number."
echo ""
echo "Logs: $PROJECT_DIR/logs/bot.log"
echo ""
echo "Setup complete."
