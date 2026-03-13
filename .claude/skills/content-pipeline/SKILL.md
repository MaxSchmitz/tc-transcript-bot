---
name: content-pipeline
description: Process any URL (video, article, tweet) into an enriched content document with Grok analysis and 1 post option
triggers:
  - instagram.com/reel
  - instagram.com/reels
  - tiktok.com
  - twitter.com
  - x.com
  - http
  - https
  - transcript
---

# Content Pipeline

When you receive a URL, determine the source type, extract its content, enrich with Grok, and generate a post option.

**Sender detection:** The input may be prefixed with `[Sender: Name]`. Extract and strip this prefix. Pass the sender name to the formatter so it appears at the top of the output document.

---

## 1. Detect source type and extract content

### Video URLs (Instagram Reels, TikTok)

If the URL contains `instagram.com/reel`, `instagram.com/reels`, or `tiktok.com`:

**Download the video:**

```bash
yt-dlp --cookies-from-browser chrome --write-info-json -o "/tmp/video_%(id)s.%(ext)s" --merge-output-format mp4 "{URL}"
```

If yt-dlp returns a 403, the Chrome cookies are stale. Refresh them:

```bash
# For Instagram
open -a "Google Chrome" "https://www.instagram.com/"
# For TikTok
open -a "Google Chrome" "https://www.tiktok.com/"
sleep 5
```

Then retry. If the video is private or unavailable, reply: "That video is private or has been removed."

**Extract audio:**

```bash
ffmpeg -i /tmp/video_{id}.mp4 -vn -ac 1 -ar 16000 -f wav /tmp/video_{id}.wav -y
```

**Transcribe with OpenAI Whisper:**

```bash
curl -s -X POST "https://api.openai.com/v1/audio/transcriptions" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -F "file=@/tmp/video_{id}.wav" \
  -F "model=whisper-1"
```

Extract the transcript from the `text` field. Preserve it verbatim -- never edit, summarize, or clean up.

**Extract metadata** from the .info.json: username/uploader, video title, description.

**Clean up video files:**

```bash
rm -f /tmp/video_{id}.mp4 /tmp/video_{id}.wav /tmp/video_{id}.info.json
```

### Article URLs (news sites, blogs, any webpage)

If the URL is not a video or tweet, treat it as an article.

Use the **WebFetch** tool to fetch the page. Ask it to extract:
- Article title
- Author name
- Full article body text
- Publication date if available

### Tweet / Twitter thread URLs

If the URL contains `twitter.com` or `x.com`:

Use the **WebFetch** tool to fetch the tweet or thread. Ask it to extract:
- Author name and handle
- Full text of the tweet or thread (all tweets in order)
- Engagement metrics if visible (likes, retweets, replies)

### Source metadata

For all source types, capture whatever metadata is available:
- **Video**: username, title, description from yt-dlp .info.json
- **Article**: author, publication, date from WebFetch
- **Tweet**: author handle, date, engagement from WebFetch

Pass this metadata to Grok in Step 2.

---

## 2. Enrich with Grok

See [Grok-Logic.md](Grok-Logic.md) for the full enrichment prompt, script call, and response handling.

---

## 3. Generate post option

**Post structure -- read this before writing:**

Every post has two containers.

**Image container:** Headline + Body copy. Together they must work as a standalone unit. Someone who never reads the caption should still understand the point. The headline is the viral hook. The body is supporting copy.

**Caption container:** Plain text only. No formatting. Adds authority, evidence, and context the image couldn't hold. Never summarizes what the image already said. Never rescues an image that failed.

Now read these files before writing:

- [Core-Writing-Rules.md](Core-Writing-Rules.md) -- banned phrases, dead AI language, hard rules
- [Viral-Format-Functions.md](Viral-Format-Functions.md) -- 14 content functions and when to use each
- [Headline-Writing-Rules.md](Headline-Writing-Rules.md) -- headline writing with before/after examples
- [Facebook-Caption-Writing-Rules.md](Facebook-Caption-Writing-Rules.md) -- caption writing rules and examples

The post option must contain:
1. **Format** -- Which viral format function best fits this content. Pick the single strongest one.
2. **Headline** -- The hook. Specific, concrete, no "researchers say." Think finding first, always.
3. **Body copy** -- Image container text. Written for Facebook. Conversational but authoritative. Uses enrichment details from Grok where they strengthen the post.
4. **Caption** -- Plain text. Adds authority, evidence, context. Uses the rules in Facebook-Caption-Writing-Rules.md.

---

## 4. Format and save

Format the full document using [Output-Formatting.md](Output-Formatting.md). It defines the document structure, filename convention, and output template.

The document must contain ALL of these sections in order:
1. Sent by
2. Content URL
3. Post Option
4. User Requested Field (OPTIONAL -- only if the sender included extra instructions beyond the URL)
5. Viral Trends (Grok's full response)
6. Key Data Points
7. Cleaned Transcript (VIDEO ONLY)
8. Raw Content

### Save location

Determine the subdirectory and folder name BEFORE writing the file:

- **SUBDIR**: `Reels` for video sources (Instagram Reels, TikTok), `Articles` for articles and tweets
- **FOLDER_NAME**: `YYYY-MM-DD-@Handle-concise-slug` (date is today, include @ before handle, 2-4 word slug)
- **FILENAME**: from [Output-Formatting.md](Output-Formatting.md) -- `YYYY-MM-DD-username` (lowercase, no @)

For video: extract username from yt-dlp metadata (.info.json). For articles/tweets: extract from WebFetch output. For articles with no handle, use the publication name or author name.

### Save steps (ALL THREE are mandatory)

```bash
# Step 4a: Create the output directory
mkdir -p "$GDRIVE_TRANSCRIPT_DIR/$SUBDIR/$FOLDER_NAME"

# Step 4b: Write the .md file
# (use Write tool or cat heredoc to create the file)

# Step 4c: Convert to .docx -- DO NOT SKIP THIS
pandoc "$GDRIVE_TRANSCRIPT_DIR/$SUBDIR/$FOLDER_NAME/$FILENAME.md" \
  -o "$GDRIVE_TRANSCRIPT_DIR/$SUBDIR/$FOLDER_NAME/$FILENAME.docx"
```

All three steps must execute. If pandoc fails, report the error but still keep the .md file.

---

## 5. Reply

Send back a single message: "Done. Saved to `{folder_name}/{filename}.md`"

If any step failed, reply with a clear description of what went wrong and at which step.
