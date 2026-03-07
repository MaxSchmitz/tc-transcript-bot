---
name: instagram-reel-transcript
description: Download an Instagram Reel, transcribe it, and save a transcript file to Google Drive
triggers:
  - instagram.com/reel
  - instagram.com/reels
  - transcript
---

# Instagram Reel Transcript

When you receive an Instagram Reel URL, process it through this pipeline. Run each step in sequence and handle errors at each stage.

## 1. Download the Reel

```bash
yt-dlp --cookies-from-browser chrome -o "/tmp/reel_%(id)s.%(ext)s" --merge-output-format mp4 "{URL}"
```

If yt-dlp returns a 403, the Chrome cookies are stale. Refresh them by opening Instagram in Chrome:

```bash
open -a "Google Chrome" "https://www.instagram.com/"
sleep 5
```

This loads the page using the existing saved login, which refreshes the session cookies. Then retry the yt-dlp command. If it still fails, the user may be fully logged out -- use Playwright or browser automation to log in with the credentials stored in the environment variables `INSTAGRAM_USER` and `INSTAGRAM_PASS`, then retry.

If the Reel is private or unavailable, reply: "That Reel is private or has been removed."

## 2. Extract audio

```bash
ffmpeg -i /tmp/reel_{id}.mp4 -vn -ac 1 -ar 16000 -f wav /tmp/reel_{id}.wav -y
```

## 3. Transcribe with Deepgram

POST the WAV file to Deepgram nova-2:

```bash
curl -s -X POST "https://api.deepgram.com/v1/listen?model=nova-2&smart_format=true" \
  -H "Authorization: Token $DEEPGRAM_API_KEY" \
  -H "Content-Type: audio/wav" \
  --data-binary @/tmp/reel_{id}.wav
```

Extract the transcript from `.results.channels[0].alternatives[0].transcript` in the JSON response.

Preserve the transcript verbatim. Never edit, summarize, clean up filler words, or remove false starts.

## 4. Format and save transcript

Format the transcript using the `transcript-formatter` skill. It defines the document structure, template, and output format.

Save the formatted file to the Google Drive folder. The environment variable `GDRIVE_TRANSCRIPT_DIR` points to a local folder synced by Google Drive for Desktop.

```bash
# Create daily subfolder if needed
DATE_DIR=$(date +%Y-%m-%d)
mkdir -p "$GDRIVE_TRANSCRIPT_DIR/$DATE_DIR"
```

Save the file inside the daily folder. The filename should be the Reel ID (extracted from the URL).

## 5. Clean up

```bash
rm -f /tmp/reel_{id}.mp4 /tmp/reel_{id}.wav
```

## 6. Reply

Send back a single message: "Done. Saved to {YYYY-MM-DD}/{reel_id}.md"

If any step failed, reply with a clear description of what went wrong and at which step.
