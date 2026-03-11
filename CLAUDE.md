# TC Transcript Bot

iMessage bot that turns video URLs into enriched content documents with post options.

## Architecture

```
iMessage URL -> imsg rpc -> claude -p (skills auto-invoke) -> Google Drive
```

Pipeline steps (handled by `instagram-reel-transcript` skill):
1. yt-dlp downloads video (Chrome cookies for auth)
2. ffmpeg extracts audio
3. OpenAI Whisper transcribes
4. Grok API enriches (background, fact-check, viral framing)
5. Claude generates 5 post options (headline, body, caption)
6. Saves structured document to `$GDRIVE_TRANSCRIPT_DIR`

## Key Files

- `scripts/tc-transcript-bot.sh` -- main bot process (bash coproc + imsg rpc)
- `.claude/skills/content-pipeline/SKILL.md` -- full pipeline skill (video, articles, tweets)
- `.claude/skills/transcript-formatter/SKILL.md` -- output formatting
- `skills/` -- content skill files (viral-post, headline, caption, curation)
- `.env` -- all config and API keys
- `allowed-senders.txt` -- phone numbers and emails, re-read per message
- `transcripts/` -- local output directory

## Rules

- **NEVER modify `.env`.** Paths are correct as configured.
- **NEVER modify `allowed-senders.txt`** unless explicitly asked.
- Output folder naming: `YYYY-MM-DD-@Handle-concise-slug/`
- Output file naming: `YYYY-MM-DD-username.md`
- Transcripts are verbatim. Never edit raw transcripts.
- Skills drive the pipeline. Modify skills to change behavior, not the bot script.

## APIs

- **OpenAI Whisper**: `$OPENAI_API_KEY` -- audio transcription
- **Grok (x.ai)**: `$GROK_API_KEY` -- viral trends. Via xai-sdk (`.claude/skills/content-pipeline/scripts/grok-query.py`), model `grok-4-1-fast-reasoning`
- **iMessage**: imsg rpc (JSON-RPC over stdio)
- **Google Drive**: local folder sync (no API)

## Running

```bash
cd ~/tc-transcript-bot && source .env && ./scripts/tc-transcript-bot.sh
```

Or via launchd: `com.thoughtcatalog.transcript-bot`

## Troubleshooting

- **yt-dlp 403**: Chrome cookies stale. Open Instagram in Chrome, retry.
- **imsg not picking up**: Full Disk Access not granted for terminal + `/opt/homebrew/bin/bash`.
- **Bot not responding**: Check `logs/bot.log`. Run manually to see output.
- **Sender not matched**: Check `allowed-senders.txt`. iMessage may route via email instead of phone number. Check `imsg chats --limit 5 --json` for the actual identifier format.

## Setup

Full setup instructions: @docs/setup.md
