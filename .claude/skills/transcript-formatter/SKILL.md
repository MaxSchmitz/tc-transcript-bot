---
name: transcript-formatter
description: Format pipeline output into a structured Google Drive document. Invoked by the content-pipeline skill after all steps complete.
user-invocable: false
---

# Content Document Formatter

Format the full pipeline output into a clean, structured document ready for Google Drive.

## Step 1: Determine the Google Drive File Name

Use this naming convention:

```
YYYY-MM-DD-username
```

If the same username has multiple sources on the same date, append a sequence number:

```
YYYY-MM-DD-username-2
YYYY-MM-DD-username-3
```

**Rules:**
- Date format is always YYYY-MM-DD (e.g., 2026-03-07)
- Username is lowercase, no @ symbol
- For articles, use author last name or publication name
- Sequence number only appears when there is a collision
- No spaces anywhere in the filename -- use hyphens only

## Step 2: Structure the Document

Use H1 headings for all sections. Present them in this exact order:

---

# Sent by: [SENDER NAME]

If a sender name was provided, display it here at the very top of the document. If no sender name is available, omit this section entirely.

---

# [CONTENT URL]

The original source URL, displayed as a clickable link.

---

# Raw Content

For video: paste the transcript exactly as extracted -- no edits, no punctuation fixes, no paragraph breaks added. Preserve stutters, filler words, run-ons, and any transcription artifacts. This is the archival record.

For articles: paste the full article text as extracted by WebFetch.

For tweets: paste the full tweet or thread text.

---

# Context Analysis

Paste the Context Analysis section from the Grok response. This covers what the content is, who the speaker/author is, what broader story or trend it connects to, and key data points.

Do not edit or summarize. Paste as returned.

---

# Additional Information

Paste the Additional Information section from the Grok response. Background details, related developments, things worth noting beyond the source material.

Do not edit or summarize. Paste as returned.

---

# Viral Media

Paste the Viral Media section from the Grok response. Links to viral posts about this topic on X, Facebook, or other platforms, with explanation of what angles are getting traction.

Do not edit or summarize. Paste as returned.

---

# Cleaned Transcript

**Only include this section for video sources (Instagram Reels, TikTok).** Articles and tweets already have clean text -- skip this section entirely for non-video content.

For video transcripts, rewrite the raw transcript as a **blockquote** using Markdown `>` formatting.

Rules for cleaning:
- Keep it as close to the original wording as possible
- Fix run-on sentences by breaking them at natural breath points
- Add punctuation where clearly implied
- Remove all filler sounds and words: um, uh, hmm, ah, er, like, you know, right, okay (when used as filler), and similar verbal tics
- Do not paraphrase or reword -- preserve the speaker's voice
- Do not add words that weren't said
- Format as a single flowing quote, or break into paragraphs if there are clear topic shifts

---

# Post Options

Present all 5 post options, clearly numbered and separated. Use this format for each:

## Option 1

**Headline:** [headline text]

**Body:**

[Full post body copy]

**Caption:** [social media caption]

---

## Option 2

[same format]

---

[...through Option 5]

---

## Notes

- The date in the filename is the day the content was processed. Use the current date automatically.
- If the username is not provided, extract it from the yt-dlp metadata (uploader or channel field in the .info.json) or from WebFetch output.
- If Grok analysis failed or was unavailable, include a note in the relevant sections explaining the failure, and still generate the 5 post options using only the raw content.
