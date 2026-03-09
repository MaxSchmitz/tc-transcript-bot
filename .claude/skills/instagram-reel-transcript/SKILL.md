---
name: instagram-reel-transcript
description: Download a video from Instagram Reels or TikTok, transcribe it, and save a transcript file to Google Drive
triggers:
  - instagram.com/reel
  - instagram.com/reels
  - tiktok.com
  - transcript
---

# Video Transcript

When you receive an Instagram Reel or TikTok URL, process it through this pipeline. Run each step in sequence and handle errors at each stage.

## 1. Download the video

```bash
yt-dlp --cookies-from-browser chrome --write-info-json -o "/tmp/video_%(id)s.%(ext)s" --merge-output-format mp4 "{URL}"
```

If yt-dlp returns a 403, the Chrome cookies are stale. Refresh them by opening the relevant site in Chrome:

```bash
# For Instagram
open -a "Google Chrome" "https://www.instagram.com/"
# For TikTok
open -a "Google Chrome" "https://www.tiktok.com/"
sleep 5
```

This loads the page using the existing saved login, which refreshes the session cookies. Then retry the yt-dlp command. If it still fails, the user may be fully logged out -- use Playwright or browser automation to log in with the credentials stored in the environment variables `INSTAGRAM_USER` and `INSTAGRAM_PASS`, then retry.

If the video is private or unavailable, reply: "That video is private or has been removed."

## 2. Extract audio

```bash
ffmpeg -i /tmp/video_{id}.mp4 -vn -ac 1 -ar 16000 -f wav /tmp/video_{id}.wav -y
```

## 3. Transcribe with OpenAI Whisper

POST the WAV file to the OpenAI Whisper API:

```bash
curl -s -X POST "https://api.openai.com/v1/audio/transcriptions" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -F "file=@/tmp/video_{id}.wav" \
  -F "model=whisper-1"
```

Extract the transcript from the `text` field in the JSON response.

Preserve the transcript verbatim. Never edit, summarize, clean up filler words, or remove false starts.

## 4. Format and save transcript

Format the transcript using the `transcript-formatter` skill. It defines the document structure, template, and output format.

Save the formatted file to the Google Drive folder. The environment variable `GDRIVE_TRANSCRIPT_DIR` points to a local folder synced by Google Drive for Desktop.

Each video gets its own folder using this naming convention:

```
YYYY-MM-DD-@InstagramHandle-[concise-slug]
```

- Date is the day the transcript was requested
- Include the @ symbol before the handle, preserve original capitalization
- For TikTok, use the TikTok username with @ prefix
- The slug is a concise 2-4 word summary of the video topic, lowercase, hyphenated
- Extract the username from the yt-dlp metadata (uploader or channel field in the .info.json)

```bash
mkdir -p "$GDRIVE_TRANSCRIPT_DIR/$FOLDER_NAME"
```

The `transcript-formatter` skill determines the filename. Save the formatted file inside the video's folder.

## 5. Clean up

```bash
rm -f /tmp/video_{id}.mp4 /tmp/video_{id}.wav /tmp/video_{id}.info.json
```

## 6. Reply

Send back a single message: "Done. Saved to `{YYYY-MM-DD}/{filename}.md`"

If any step failed, reply with a clear description of what went wrong and at which step.
