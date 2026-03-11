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

**CRITICAL: Follow this structure exactly. Every section uses H1 (`#`) headings. Do not skip sections, do not change heading levels, do not add titles or Markdown links to the URL line.**

The document MUST start with these lines in this exact order. Here is a concrete example:

```markdown
# Sent by: ChrisLavergne

# https://www.dailymail.co.uk/tvshowbiz/article-15633973/example.html

# Post Option

**Format:** Extract Thrilling Sequence of Facts

**Headline:** [headline]

**Body:**

[body]

**Caption:** [caption]

# Viral Trends

[Grok output here]

# Key Data Points

[key facts, numbers, names, dates extracted from the content]

# Raw Content

[content here]
```

### Section details:

**# Sent by: [NAME]** -- Always include this. The sender name comes from the `[Sender: ...]` prefix in the prompt. Write it exactly as provided.

**# [URL]** -- The original source URL as plain text. NOT a Markdown link. NOT wrapped in brackets. Just the raw URL on its own line after the `#`.

**# Post Option** -- Single post option with Format, Headline, Body, Caption fields.

**# [User Requested Field]** -- OPTIONAL. Only include if the sender's message contains additional instructions or a specific question beyond just the URL. Use the sender's words as the heading and answer their request in this section. If the message is just a URL with no extra text, skip this section entirely.

**# Viral Trends** -- Paste the full Grok response. Do not edit.

**# Key Data Points** -- Extract the most important facts, numbers, names, dates, and quotes from the content. Bulleted list. These are the details a writer needs at a glance.

**# Cleaned Transcript** -- VIDEO ONLY. Skip entirely for articles and tweets. For video, rewrite the raw transcript as a blockquote (`>`) with filler words removed, punctuation added, run-ons broken at natural breath points. Preserve the speaker's voice.

**# Raw Content** -- For video: verbatim transcript (no edits). For articles: full article text. For tweets: full tweet text. This goes at the bottom of the document.

---

## Notes

- The date in the filename is the day the content was processed. Use the current date automatically.
- If the username is not provided, extract it from the yt-dlp metadata (uploader or channel field in the .info.json) or from WebFetch output.
- If Grok analysis failed or was unavailable, include a note in the relevant sections explaining the failure, and still generate the post option using only the raw content.
