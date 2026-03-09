# TC Transcript Bot

Text an Instagram Reel link via iMessage, get back a transcript saved to Google Drive.

## How it works

```
Text Reel URL via iMessage
  -> imsg rpc detects the message (JSON-RPC over stdio)
  -> claude -p processes it (auto-invokes the instagram-reel-transcript skill)
  -> yt-dlp downloads the Reel (using Chrome cookies for auth)
  -> ffmpeg extracts audio
  -> OpenAI Whisper transcribes audio
  -> Transcript saved to local Google Drive folder (synced automatically)
  -> imsg rpc replies with confirmation
```

## Requirements

- macOS (required for iMessage)
- Homebrew
- Bash 4+ (`brew install bash`)
- Claude Code installed and authenticated
- Chrome installed and signed into Instagram
- [Google Drive for Desktop](https://www.google.com/drive/download/) installed and signed in
- OpenAI API key (for Whisper transcription)

## Setup

See `CLAUDE.md` for full setup instructions including dependencies, permissions, configuration, and launchd agent setup. Config is saved to `.env` (see `.env.example` for the format).

### Manual test

```bash
source .env && ./scripts/tc-transcript-bot.sh
```

Then text an Instagram Reel link to the watched number/email.

### Auto-start

A launchd agent starts the bot on login and restarts it if it crashes.

```bash
# Start
launchctl load ~/Library/LaunchAgents/com.thoughtcatalog.transcript-bot.plist

# Stop
launchctl unload ~/Library/LaunchAgents/com.thoughtcatalog.transcript-bot.plist
```

## Google Drive setup

Install [Google Drive for Desktop](https://www.google.com/drive/download/) and sign in. The bot saves transcripts to a local folder that Drive syncs automatically -- no API credentials needed.

Set `GDRIVE_TRANSCRIPT_DIR` in `.env` to a folder inside your Google Drive path.

## Project structure

```
tc-transcript-bot/
  .claude/
    skills/
      instagram-reel-transcript/
        SKILL.md              # Claude Code skill for the pipeline
      transcript-formatter/
        SKILL.md              # Formatting/naming helper skill
  scripts/
    tc-transcript-bot.sh      # iMessage relay (imsg rpc -> claude -p)
  .env                        # config (gitignored)
  .env.example                # config template
  CLAUDE.md                   # setup instructions
  logs/
    bot.log                   # relay logs
```

## Transcript format

Each Reel gets its own `.md` file in a daily folder:

```
TC Transcripts/
  2026-03-07/
    2026-03-07-username.md
    2026-03-07-username-2.md
```

File contents:

```markdown
## Raw Transcript

[Verbatim transcript -- every word preserved, no editing]

## Clean Transcript

> [Cleaned up with punctuation, filler words removed, speaker's voice preserved]

## Notes

[Optional notes]
```

## Troubleshooting

**yt-dlp 403 error**: Chrome cookies are stale. Log into Instagram in Chrome. The bot also attempts to refresh cookies automatically.

**imsg not picking up messages**: Check Full Disk Access is enabled for your terminal. Run `imsg chats --limit 3` to verify.

**Bot not responding**: Check `logs/bot.log`. Run the script manually to see output in real time.

**Transcripts not syncing**: Make sure Google Drive for Desktop is running and the transcript folder is inside your Google Drive path.
