---
name: transcript-formatter
description: Format video transcripts with proper Google Drive file naming and structured sections. Invoked by the instagram-reel-transcript skill after transcription.
user-invocable: false
---

# Video Transcript Formatter

Format video transcripts into a clean, structured document ready for Google Drive filing.

## Step 1: Determine the Google Drive File Name

Use this naming convention:

```
YYYY-MM-DD-instagramusername
```

If the same username has multiple reels on the same date, append a sequence number:

```
YYYY-MM-DD-instagramusername-2
YYYY-MM-DD-instagramusername-3
```

**Rules:**
- Date format is always YYYY-MM-DD (e.g., 2026-03-07)
- Username is lowercase, no @ symbol
- Sequence number only appears when there is a collision (same date + same username)
- No spaces anywhere in the filename -- use hyphens only

## Step 2: Structure the Document

Use H2 headings for all sections. Present them in this order:

---

## Raw Transcript

Paste the transcript exactly as extracted -- no edits, no punctuation fixes, no paragraph breaks added. Preserve stutters, filler words, run-ons, and any transcription artifacts. This is the archival record.

---

## Clean Transcript

Rewrite the transcript as a **blockquote** using Markdown `>` formatting.

Rules for cleaning:
- Keep it as close to the original wording as possible
- Fix run-on sentences by breaking them at natural breath points
- Add punctuation where clearly implied
- Remove all filler sounds and words: um, uh, hmm, ah, er, like, you know, right, okay (when used as filler), and similar verbal tics
- Do not paraphrase or reword -- preserve the speaker's voice
- Do not add words that weren't said
- Format as a single flowing quote, or break into paragraphs if there are clear topic shifts

Example format:
> First sentence here. Second sentence here.
>
> New paragraph if there is a clear topic shift.

---

## Top 3 Most Hearted Comments

List the top 3 comments ranked by heart/like count, highest first.

Format each comment as:

**1. @username** -- [heart count] hearts
"Comment text exactly as written."

**2. @username** -- [heart count] hearts
"Comment text exactly as written."

**3. @username** -- [heart count] hearts
"Comment text exactly as written."

Preserve the original spelling, capitalization, and emoji in each comment. Do not clean or edit them.

If heart counts are not provided, list them in the order given and omit the heart count.

---

## Notes

- The date in the filename is the day the transcript was requested. Use the current date automatically.
- If the username is not provided, extract it from the yt-dlp metadata (uploader or channel field in the .info.json).
- If comments are not available, omit the Top 3 section entirely rather than leaving it blank.
