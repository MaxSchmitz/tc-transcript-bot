# Setup Guide

## 1. Install dependencies

```bash
# Homebrew (skip if already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# CLI tools (bash 5 required for coproc support)
brew install bash steipete/tap/imsg jq ffmpeg yt-dlp
```

Verify each command exists: `bash` (should be 5.x from Homebrew), `imsg`, `jq`, `ffmpeg`, `yt-dlp`.

## 2. Check macOS permissions

imsg needs Full Disk Access to read the Messages database. Test with:

```bash
imsg chats --limit 1 --json
```

If it fails, grant Full Disk Access:
- System Settings > Privacy & Security > Full Disk Access
- Enable the terminal app (Terminal.app, iTerm, etc.)
- Also add `/opt/homebrew/bin/bash` (required for the launchd agent)

## 3. Gather configuration

Required:
- **Phone numbers or iMessage emails** of allowed senders (E.164 format, e.g. +15551234567 or user@icloud.com)
- **OpenAI API key** (from platform.openai.com)
- **Grok API key** (from console.x.ai)
- **Google Drive transcript folder path** (default: `~/Google Drive/My Drive/TC Transcripts`)

Optional:
- **Instagram credentials** (for auto-login when cookies expire)

Confirm:
- Chrome is installed and logged into Instagram
- Google Drive for Desktop is installed and signed in

## 4. Create config files

Write a `.env` file in the project root:

```
TC_PROJECT_DIR="<absolute path to this project>"
CLAUDE_BIN="<output of which claude>"
OPENAI_API_KEY="<key>"
GROK_API_KEY="<key>"
INSTAGRAM_USER="<username or blank>"
INSTAGRAM_PASS="<password or blank>"
GDRIVE_TRANSCRIPT_DIR="<path to transcript folder>"
PATH="/opt/homebrew/bin:<path to claude binary's dir>:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
```

Write an `allowed-senders.txt` file in the project root with one entry per line. Optionally add a name after a pipe (`|`) -- the name appears at the top of output documents:

```
+15551234567|John Smith
user@icloud.com|John Smith
```

The bot re-reads this file on each message, so senders can be added or removed without restarting.

Create the transcript folder if it doesn't exist.

## 5. Install launchd agent

Create `~/Library/LaunchAgents/com.thoughtcatalog.transcript-bot.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.thoughtcatalog.transcript-bot</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    </dict>
    <key>ProgramArguments</key>
    <array>
        <string>/opt/homebrew/bin/bash</string>
        <string>-c</string>
        <string>source "{TC_PROJECT_DIR}/.env" &amp;&amp; exec "{TC_PROJECT_DIR}/scripts/tc-transcript-bot.sh"</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>{TC_PROJECT_DIR}/logs/launchd-stdout.log</string>
    <key>StandardErrorPath</key>
    <string>{TC_PROJECT_DIR}/logs/launchd-stderr.log</string>
</dict>
</plist>
```

Replace `{TC_PROJECT_DIR}` with the actual project path.

Load it:

```bash
mkdir -p {TC_PROJECT_DIR}/logs
launchctl load ~/Library/LaunchAgents/com.thoughtcatalog.transcript-bot.plist
```

## 6. Test

Run manually to verify:

```bash
cd ~/tc-transcript-bot && source .env && ./scripts/tc-transcript-bot.sh
```

Then text an Instagram Reel link to the watched number. Confirm a document appears in the Google Drive folder.
