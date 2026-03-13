# TC Transcript Bot

iMessage bot that turns URLs into publication-ready content documents. Text a link — video, article, or tweet — and get back an enriched document with a viral post option, Grok trend analysis, key data points, and a cleaned transcript, saved to Google Drive.

Built on Claude Code. The bot is a thin bash relay. All content logic lives in Claude skills.

## How it works

```
You text a URL via iMessage
  |
  v
tc-transcript-bot.sh (bash coproc running imsg rpc)
  - validates sender against allowed-senders.txt
  - passes URL + sender name to claude -p
  |
  v
Claude Code (skills auto-invoke on URL pattern)
  |
  |-- Video URLs (Instagram Reels, TikTok)
  |     1. yt-dlp downloads video (Chrome cookies for auth)
  |     2. ffmpeg extracts audio
  |     3. OpenAI Whisper transcribes
  |
  |-- Article URLs
  |     1. WebFetch extracts title, author, body
  |
  |-- Tweet URLs
  |     1. WebFetch extracts author, text, engagement
  |
  v
Grok enrichment (xai-sdk, grok-4-1-fast-reasoning)
  - what's trending on X about this topic
  - relevant tweets with direct links
  - angle generating most reaction
  |
  v
Post option generation (1 viral format selected from 14 functions)
  - headline, body copy, caption
  |
  v
Output document (.md + .docx via pandoc)
  - saved to Google Drive folder
  - bot replies via iMessage with confirmation
```

## What the output looks like

Each URL produces a folder in Google Drive:

```
TC Transcripts/
  Reels/
    2026-03-07-@username-topic-slug/
      2026-03-07-username.md
      2026-03-07-username.docx
  Articles/
    2026-03-07-@publication-topic-slug/
      2026-03-07-publication.md
      2026-03-07-publication.docx
```

Document sections, in order:

1. **Sent by** — who texted the link
2. **Source URL** — the original link
3. **Post Option** — format name, headline, body copy, caption
4. **Viral Trends** — Grok response (verbatim)
5. **Key Data Points** — facts, numbers, names, dates, quotes
6. **Cleaned Transcript** — (video only) filler removed, punctuation added
7. **Raw Content** — verbatim transcript, article text, or tweet

## Requirements

- macOS (required for iMessage)
- Bash 5+ (`brew install bash` — required for coproc)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed and authenticated
- Chrome installed and signed into Instagram
- [Google Drive for Desktop](https://www.google.com/drive/download/) installed and signed in
- API keys: OpenAI (Whisper), Grok/xai (trend analysis)

System tools: `imsg` (steipete/tap), `jq`, `ffmpeg`, `yt-dlp`, `pandoc`

## Quick start

```bash
# Install dependencies
brew install bash steipete/tap/imsg jq ffmpeg yt-dlp pandoc

# Configure (copy and fill in)
cp .env.example .env
cp allowed-senders.example.txt allowed-senders.txt

# Run manually
cd ~/tc-transcript-bot && source .env && ./scripts/tc-transcript-bot.sh
```

Text a URL to the watched iMessage account. A document should appear in Google Drive.

Full setup guide: [docs/setup.md](docs/setup.md)

## Auto-start (launchd)

```bash
# Start on login, restart on crash
launchctl load ~/Library/LaunchAgents/com.thoughtcatalog.transcript-bot.plist

# Stop
launchctl unload ~/Library/LaunchAgents/com.thoughtcatalog.transcript-bot.plist
```

See [docs/setup.md](docs/setup.md) for plist creation.

## Project structure

```
tc-transcript-bot/
  scripts/
    tc-transcript-bot.sh            # iMessage relay (imsg rpc coproc -> claude -p)

  .claude/skills/content-pipeline/
    SKILL.md                        # Main pipeline skill (orchestrates everything)
    Grok-Logic.md                   # Grok enrichment step
    Output-Formatting.md            # Document structure and file naming
    Viral-Format-Functions.md       # 14 viral format functions
    Headline-Writing-Rules.md       # Headline generation rules
    Facebook-Caption-Writing-Rules.md  # Caption writing rules
    core-writing-rules.md           # Banned phrases, style rules
    scripts/
      grok-query.py                 # xai-sdk wrapper for Grok API

  docs/
    setup.md                        # Full setup instructions

  .env                              # Config and API keys (gitignored)
  .env.example                      # Config template
  allowed-senders.txt               # Allowed phone/email list (gitignored)
  allowed-senders.example.txt       # Sender list template
  CLAUDE.md                         # Project rules for Claude sessions
  pyproject.toml                    # Python deps (xai-sdk for Grok)

  logs/                             # Runtime logs (gitignored)
    bot.log
    claude-verbose.log
    responses.log
```

## Configuration

**`.env`** — API keys and paths. See `.env.example`. Never commit this file.

**`allowed-senders.txt`** — one sender per line, optional name after pipe:

```
+15551234567|John Smith
user@icloud.com|Jane Doe
```

Re-read on every message. Add or remove senders without restarting the bot.

## How the skills work

The bot script is just a relay. All content logic lives in Claude skills under `.claude/skills/content-pipeline/`.

**`SKILL.md`** is the orchestrator. It triggers on URL patterns (instagram.com, tiktok.com, twitter.com, x.com, any http/https) and coordinates the full pipeline: download, transcribe, enrich, generate post, format output, save.

The skill delegates to focused modules:

| Module | Purpose |
|--------|---------|
| `Grok-Logic.md` | Queries Grok for trending X context about the topic |
| `Viral-Format-Functions.md` | 14 copywriting functions — the skill picks one that fits the source material |
| `Headline-Writing-Rules.md` | Rules for writing scroll-stopping headlines |
| `Facebook-Caption-Writing-Rules.md` | Rules for writing Facebook captions |
| `core-writing-rules.md` | Banned phrases and style rules applied to all output |
| `Output-Formatting.md` | Document section order, file naming, folder structure |

To change how the bot processes content, modify these skill files. Don't touch the bot script.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| yt-dlp 403 error | Chrome cookies stale. Open Instagram in Chrome, browse briefly, retry. |
| imsg not picking up messages | Full Disk Access not granted. System Settings > Privacy & Security > Full Disk Access. Enable terminal app + `/opt/homebrew/bin/bash`. |
| Bot not responding | Check `logs/bot.log`. Run script manually to see output. |
| Sender not matched | iMessage may route via email instead of phone. Run `imsg chats --limit 5 --json` to see actual identifier format. Update `allowed-senders.txt`. |
| Grok fails | Pipeline continues. Viral Trends section will note the failure. |
| Transcripts not syncing | Confirm Google Drive for Desktop is running and `GDRIVE_TRANSCRIPT_DIR` points inside your Drive path. |
