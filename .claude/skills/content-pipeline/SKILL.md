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

## 2. Enrich with Grok

Send the extracted content AND the source metadata to the Grok API. Including metadata (who the speaker is, what video/article this came from) prevents misattribution.

```bash
curl -s https://api.x.ai/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $GROK_API_KEY" \
  -d '{
    "messages": [
      {
        "role": "system",
        "content": "You are a research analyst for a viral content team. Given source content, provide deep enrichment that a content writer needs to turn this into a high-performing post. Be specific, not generic."
      },
      {
        "role": "user",
        "content": "SOURCE METADATA:\n<metadata>\n\nCONTENT:\n<content>\n\nAnalyze this and return a structured analysis with these exact sections:\n\n## Context Analysis\nWhat is this? Who is the speaker/author? What broader story or trend does this connect to? Include specific names, dates, studies, or events referenced. Key data points a writer needs to know.\n\n## Additional Information\nAnything else worth noting about this topic. Background details, related developments, things a content writer should know that aren't in the source material itself.\n\n## Viral Media\nAre there viral posts about this on X, Facebook, or other platforms? Link to them and explain what is going viral about it. What angles are getting the most traction? What framing is working?"
      }
    ],
    "model": "grok-3-latest",
    "stream": false,
    "temperature": 0.3
  }'
```

Replace `<metadata>` with the source metadata and `<content>` with the full extracted content. Extract the response from `.choices[0].message.content`.

## 3. Generate 5 post options

Using the extracted content, the Grok analysis, and the reference files in this skill directory, generate 5 distinct post options. Read these files before generating:

- [core-writing-rules.md](core-writing-rules.md) -- banned phrases, dead AI language, writing rules
- [viral-post-formats.md](viral-post-formats.md) -- 14 post formats and when to use each
- [facebook-post-containers.md](facebook-post-containers.md) -- two-container architecture (image + caption)
- [headline-base.md](headline-base.md) -- headline writing with before/after examples
- [caption-base.md](caption-base.md) -- caption writing rules and structure

Each post option must contain:
1. **Format** -- Which viral post format (from `viral-post-formats.md`) this option uses. Each option should use a different format.
2. **Headline** -- The hook. Not "researchers say" but the specific, concrete detail that makes someone click. Think "A scientific study of strippers said" not "A new study found." The headline is the hardest part. Make each one a different angle on the same material.
3. **Body copy** -- The post text. Written for Facebook. Conversational but authoritative. Uses the enrichment details from Grok. Each option should take a different angle or emphasize a different part of the story.
4. **Caption** -- The social media caption that goes with the post. Shorter, punchier, optimized for engagement.

Rules for post generation:
- All 5 options use the same source material but take DIFFERENT angles
- Use specific details from the Grok enrichment (names, numbers, quotes) -- never be vague
- Write at a high school reading level. Short sentences. No jargon.
- The headline does the heavy lifting. If the headline doesn't make someone stop scrolling, the rest doesn't matter.
- Do NOT start headlines with "How", "Why", "What", or "The" -- those are invisible on a feed
- Do NOT use clickbait formulas ("You won't believe..."). Use specificity instead.

## 4. Format and save

Format the full document using [document-format.md](document-format.md). It defines the document structure, filename convention, and output template.

The document must contain ALL of these sections in order:
1. Sent by (the sender's phone number or email, extracted from the `[Sender: ...]` prefix in the prompt)
2. Content URL (the original source URL)
3. Raw Content (transcript for video, article text for articles, tweet text for tweets)
4. Context Analysis (from Grok)
5. Additional Information (from Grok)
6. Viral Media (from Grok -- viral posts about this topic on X, Facebook, etc.)
7. Cleaned Transcript (VIDEO ONLY -- skip for articles and tweets)
8. Post Options (all 5 options from step 3)

Save the formatted file to the Google Drive folder. The environment variable `GDRIVE_TRANSCRIPT_DIR` points to a local folder synced by Google Drive for Desktop.

**Subdirectory by source type:**
- **Video** (Instagram Reels, TikTok): save to `$GDRIVE_TRANSCRIPT_DIR/Reels/`
- **Articles** (news, blogs, webpages): save to `$GDRIVE_TRANSCRIPT_DIR/Articles/`
- **Tweets**: save to `$GDRIVE_TRANSCRIPT_DIR/Articles/`

Each source gets its own folder within the subdirectory:

```
YYYY-MM-DD-@Handle-[concise-slug]
```

- Date is the day the content was processed
- Include the @ symbol before the handle/author, preserve original capitalization
- For articles with no handle, use the publication name or author name
- The slug is a concise 2-4 word summary of the content topic, lowercase, hyphenated
- For video: extract username from yt-dlp metadata (.info.json)
- For articles/tweets: extract from WebFetch output

```bash
# Set SUBDIR to "Reels" for video sources, "Articles" for articles and tweets
mkdir -p "$GDRIVE_TRANSCRIPT_DIR/$SUBDIR/$FOLDER_NAME"
```

The [document-format.md](document-format.md) reference determines the filename. Save the formatted file inside the folder.

## 5. Reply

Send back a single message: "Done. Saved to `{folder_name}/{filename}.md`"

If any step failed, reply with a clear description of what went wrong and at which step.
