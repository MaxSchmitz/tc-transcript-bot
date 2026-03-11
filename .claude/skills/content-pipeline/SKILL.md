---
name: content-pipeline
description: Process any URL (video, article, tweet) into an enriched content document with Grok analysis and 5 post options
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

When you receive a URL, determine the source type, extract its content, enrich with Grok, and generate post options.

**Sender detection:** The input may be prefixed with `[Sender: Name]`. Extract and strip this prefix. Pass the sender name to the formatter so it appears at the top of the output document.

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

This becomes the "raw content" equivalent of a transcript.

### Tweet / Twitter thread URLs

If the URL contains `twitter.com` or `x.com`:

Use the **WebFetch** tool to fetch the tweet or thread. Ask it to extract:
- Author name and handle
- Full text of the tweet or thread (all tweets in order)
- Engagement metrics if visible (likes, retweets, replies)

This becomes the "raw content" equivalent of a transcript.

### Source metadata

For all source types, capture whatever metadata is available:
- **Video**: username, title, description from yt-dlp .info.json
- **Article**: author, publication, date from WebFetch
- **Tweet**: author handle, date, engagement from WebFetch

Pass this metadata to Grok so it can accurately identify speakers and sources.

## 2. Get viral trends from Grok

Send the extracted content and source metadata to the Grok API and ask what's being said about this topic on X.

```bash
echo "What are the tweets about this and what is going viral in this context? Include direct links to the most relevant tweets and posts.

SOURCE METADATA:
<metadata>

CONTENT:
<content>" | "$PROJECT_DIR/.venv/bin/python3" "$PROJECT_DIR/.claude/skills/content-pipeline/scripts/grok-query.py" grok-4-1-fast-reasoning
```

Replace `<metadata>` with the source metadata (title, author, URL, description) and `<content>` with the full extracted content. The script prints Grok's response to stdout.

`$PROJECT_DIR` is the tc-transcript-bot root directory (set by the bot script as `$TC_PROJECT_DIR`).

## 3. Generate post option

Using the extracted content, the Grok analysis, and the reference files in this skill directory, generate 1 post option. Read these files before generating:

- [core-writing-rules.md](core-writing-rules.md) -- banned phrases, dead AI language, writing rules
- [viral-post-formats.md](viral-post-formats.md) -- 14 post formats and when to use each
- [facebook-post-containers.md](facebook-post-containers.md) -- two-container architecture (image + caption)
- [headline-base.md](headline-base.md) -- headline writing with before/after examples
- [caption-base.md](caption-base.md) -- caption writing rules and structure

The post option must contain:
1. **Format** -- Which viral post format (from `viral-post-formats.md`) best fits this content. Pick the single strongest format.
2. **Headline** -- The hook. Not "researchers say" but the specific, concrete detail that makes someone click. Think "A scientific study of strippers said" not "A new study found."
3. **Body copy** -- The post text. Written for Facebook. Conversational but authoritative. Uses the enrichment details from Grok.
4. **Caption** -- The social media caption that goes with the post. Shorter, punchier, optimized for engagement.

Rules for post generation:
- Use specific details from the Grok enrichment (names, numbers, quotes) -- never be vague
- Write at a high school reading level. Short sentences. No jargon.
- The headline does the heavy lifting. If the headline doesn't make someone stop scrolling, the rest doesn't matter.
- Do NOT start headlines with "How", "Why", "What", or "The" -- those are invisible on a feed
- Do NOT use clickbait formulas ("You won't believe..."). Use specificity instead.

## 4. Format and save

Format the full document using [document-format.md](document-format.md). It defines the document structure, filename convention, and output template.

The document must contain ALL of these sections in order:
1. Sent by (the sender's name, extracted from the `[Sender: ...]` prefix in the prompt)
2. Content URL (the original source URL)
3. Post Option (from step 3)
4. User Requested Field (OPTIONAL -- only if the sender included extra instructions beyond the URL)
5. Viral Trends (Grok's response -- tweets and viral context)
6. Key Data Points (important facts, numbers, names, dates from the content)
7. Cleaned Transcript (VIDEO ONLY -- skip for articles and tweets)
8. Raw Content (transcript for video, article text for articles, tweet text for tweets)

### Save location

Determine the subdirectory and folder name BEFORE writing the file:

- **SUBDIR**: `Reels` for video sources (Instagram Reels, TikTok), `Articles` for articles and tweets
- **FOLDER_NAME**: `YYYY-MM-DD-@Handle-concise-slug` (date is today, include @ before handle, 2-4 word slug)
- **FILENAME**: from [document-format.md](document-format.md) -- `YYYY-MM-DD-username` (lowercase, no @)

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

## 5. Reply

Send back a single message: "Done. Saved to `{folder_name}/{filename}.md`"

If any step failed, reply with a clear description of what went wrong and at which step.
