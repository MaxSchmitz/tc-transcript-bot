# TC Transcript Bot

iMessage bot: text an Instagram Reel or TikTok URL, get a transcribed .md file saved to Google Drive.

## Setup

When asked to set up this bot, do the following:

### 1. Install dependencies

```bash
# Homebrew (skip if already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# CLI tools (bash 5 required for coproc support)
brew install bash steipete/tap/imsg jq ffmpeg yt-dlp
```

Verify each command exists: `bash` (should be 5.x from Homebrew), `imsg`, `jq`, `ffmpeg`, `yt-dlp`.

### 2. Check macOS permissions

imsg needs Full Disk Access to read the Messages database. Test with:

```bash
imsg chats --limit 1 --json
```

If it fails, tell the user to grant Full Disk Access:
- System Settings > Privacy & Security > Full Disk Access
- Enable their terminal app (Terminal.app, iTerm, etc.)
- Also add `/opt/homebrew/bin/bash` (required for the launchd agent to access Messages)

### 3. Gather configuration

Ask the user for:
- **Phone numbers or iMessage emails** of allowed senders (E.164 format, e.g. +15551234567 or user@icloud.com)
- **OpenAI API key** (from platform.openai.com -- free tier works)
- **Instagram credentials** (optional, for auto-login when cookies expire)
- **Google Drive transcript folder path** (default: `~/Google Drive/My Drive/TC Transcripts`)

Confirm that:
- Chrome is installed and logged into Instagram
- Google Drive for Desktop is installed and signed in

### 4. Create config files

Write a `.env` file in the project root:

```
TC_PROJECT_DIR="<absolute path to this project>"
CLAUDE_BIN="<output of which claude>"
OPENAI_API_KEY="<key>"
INSTAGRAM_USER="<username or blank>"
INSTAGRAM_PASS="<password or blank>"
GDRIVE_TRANSCRIPT_DIR="<path to transcript folder>"
PATH="/opt/homebrew/bin:<path to claude binary's dir>:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
```

Write an `allowed-senders.txt` file in the project root with one phone number or email per line:

```
+15551234567
user@icloud.com
```

The bot re-reads this file on each message, so senders can be added or removed without restarting.

Create the transcript folder if it doesn't exist.

### 5. Install launchd agent

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

### 6. Test

Run manually to verify:

```bash
source .env && ./scripts/tc-transcript-bot.sh
```

Then text an Instagram Reel link to the watched number. Confirm a transcript .md file appears in the Google Drive folder.

## How it works

```
Text a Reel or TikTok URL via iMessage
  -> imsg rpc detects the message (JSON-RPC over stdio)
  -> claude -p processes it (auto-invokes the instagram-reel-transcript skill)
  -> yt-dlp downloads the video (using Chrome cookies for auth)
  -> ffmpeg extracts audio
  -> OpenAI Whisper transcribes audio
  -> Transcript saved to local Google Drive folder (synced automatically)
  -> imsg rpc replies with confirmation
```

## Important rules

- **NEVER modify the `.env` file.** The paths in `.env` are correct as configured. The `GDRIVE_TRANSCRIPT_DIR` path is a Google Drive shared-drive shortcut path that looks unusual but is correct. Do not "fix", edit, or alter it under any circumstances.
- **NEVER modify `allowed-senders.txt`** unless explicitly asked by the user.

## Troubleshooting

- **yt-dlp 403**: Chrome cookies are stale. Log into Instagram in Chrome, retry.
- **imsg not picking up messages**: Full Disk Access not granted for terminal.
- **Bot not responding**: Check `logs/bot.log`. Run the script manually to see output.
- **Transcripts not syncing**: Google Drive for Desktop must be running.
