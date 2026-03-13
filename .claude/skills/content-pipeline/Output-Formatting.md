---
name: Output-Formatting
description: Formats the full pipeline output into a clean, structured document ready for Google Drive. Defines filename convention, document structure, and section rules.
---

# Output Formatting

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

Rules:
- Date format is always YYYY-MM-DD (e.g., 2026-03-07)
- Username is lowercase, no @ symbol
- For articles, use author last name or publication name
- Sequence number only appears when there is a collision
- No spaces anywhere in the filename -- use hyphens only

---

## Step 2: Structure the Document

Every section uses H1 (`#`) headings. Do not skip sections, do not change heading levels, do not add titles or Markdown links to the URL line.

The document must start with these sections in this exact order:

```markdown
# Sent by: ChrisLavergne

# https://www.dailymail.co.uk/example-url.html

# Post Option

**Format:** [Format name from Viral-Format-Functions.md]

**Headline:** [headline]

**Body:**

[image container body copy]

**Caption:**

[plain text caption]

# Viral Trends

[Grok output here -- paste verbatim, do not edit]

# Key Data Points

[bullet list of key facts, numbers, names, dates, quotes from the content]

# Raw Content

[verbatim transcript for video / full article text for articles / full tweet text for tweets]
```

---

## Section Details

**# Sent by: [NAME]** -- Always include. The sender name comes from the `[Sender: ...]` prefix in the prompt. Write it exactly as provided.

**# [URL]** -- The original source URL as plain text. Not a Markdown link. Not wrapped in brackets. Just the raw URL on its own line after the `#`.

**# Post Option** -- Single post option with Format, Headline, Body, and Caption fields.

**# [User Requested Field]** -- OPTIONAL. Only include if the sender's message contains additional instructions or a specific question beyond just the URL. Use the sender's words as the heading and answer their request in this section. If the message is just a URL with no extra text, skip this section entirely.

**# Viral Trends** -- Paste the full Grok response verbatim. Do not edit or summarize.

**# Key Data Points** -- The most important facts, numbers, names, dates, and quotes from the content. Bulleted list. These are the details a writer needs at a glance.

**# Cleaned Transcript** -- VIDEO ONLY. Skip entirely for articles and tweets. For video, rewrite the raw transcript as a blockquote (`>`) with filler words removed, punctuation added, run-ons broken at natural breath points. Preserve the speaker's voice.

**# Raw Content** -- For video: verbatim transcript (no edits). For articles: full article text. For tweets: full tweet text. Always goes at the bottom.

---

## Notes

- The date in the filename is the day the content was processed. Use the current date automatically.
- If the username is not provided, extract it from the yt-dlp metadata (uploader or channel field in the .info.json) or from WebFetch output.
- If Grok analysis failed or was unavailable, include a note in the Viral Trends section explaining the failure. Still generate the post option using only the raw content.
