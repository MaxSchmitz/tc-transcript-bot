# TC Transcript Bot

Text an Instagram Reel link via iMessage, get back a transcript saved to Google Drive.

## How it works

```
Text Reel URL via iMessage
  -> imsg watch detects the message
  -> claude -p processes it (auto-invokes the instagram-reel-transcript skill)
  -> yt-dlp downloads the Reel (using Chrome cookies for auth)
  -> ffmpeg extracts audio
  -> Deepgram transcribes audio
  -> Transcript saved to local Google Drive folder (synced automatically)
  -> imsg send replies with confirmation
```

## Requirements

- macOS (required for iMessage)
- Homebrew
- Claude Code installed and authenticated
- Chrome installed and signed into Instagram
- [Google Drive for Desktop](https://www.google.com/drive/download/) installed and signed in
- Deepgram API key

## Setup

```bash
./install.sh
```

The installer walks through everything: dependencies, macOS permissions, API keys, Google Drive MCP, and auto-start. Config is saved to `.env` (see `.env.example` for the format).

### Manual test

```bash
./scripts/tc-transcript-bot.sh
```

Then text an Instagram Reel link to the watched number/email.

### Auto-start

The installer offers to set up a launchd agent that starts the bot on login and restarts it if it crashes.

To manage manually:

```bash
# Start
launchctl load ~/Library/LaunchAgents/com.thoughtcatalog.transcript-bot.plist

# Stop
launchctl unload ~/Library/LaunchAgents/com.thoughtcatalog.transcript-bot.plist
```

## Google Drive setup

Install [Google Drive for Desktop](https://www.google.com/drive/download/) and sign in. The bot saves transcripts to a local folder that Drive syncs automatically -- no API credentials needed.

The default folder is `~/Google Drive/My Drive/TC Transcripts`. The install script will prompt for a custom path if needed.

## Project structure

```
tc-transcript-bot/
  .claude/
    skills/
      instagram-reel-transcript/
        SKILL.md              # Claude Code skill for the pipeline
  scripts/
    tc-transcript-bot.sh      # iMessage relay (imsg watch -> claude -p)
  .env                        # config (created by install.sh, gitignored)
  .env.example                # config template
  install.sh                  # interactive setup
  logs/
    bot.log                   # relay logs
```

## Transcript format

Each Reel gets its own `.md` file in a daily folder:

```
Google Drive/My Drive/TC Transcripts/
  2026-03-05/
    DVTsJralDwI.md
  2026-03-06/
    ...
```

File contents:

```
https://www.instagram.com/reels/DVTsJralDwI/

## Raw Transcript

[Verbatim transcript -- every word preserved, no editing]

## Grok Fact Check & Additional Context

[Left blank -- filled in separately]
```

## Troubleshooting

**yt-dlp 403 error**: Chrome cookies are stale. Log into Instagram in Chrome. The bot also attempts to refresh cookies automatically.

**imsg not picking up messages**: Check Full Disk Access is enabled for your terminal. Run `imsg chats --limit 3` to verify.

**Bot not responding**: Check `logs/bot.log`. Run `./scripts/tc-transcript-bot.sh` directly to see output in real time.

**Transcripts not syncing**: Make sure Google Drive for Desktop is running and the transcript folder is inside your Google Drive path.
