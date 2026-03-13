---
name: Grok-Logic
description: Grok API enrichment step for the content pipeline. Handles prompt construction, script call, and response handling. Update this file when changing the enrichment prompt, adding content-type routing, or modifying the Grok model.
---

# Grok Enrichment

After content is extracted, send it to Grok to surface what's being said on X about this topic. The Grok response feeds directly into the Viral Trends section of the output document and informs post angle selection.

---

## The Call

```bash
echo "What are the tweets about this and what is going viral in this context? Include direct links to the most relevant tweets and posts.

SOURCE METADATA:
<metadata>

CONTENT:
<content>" | uv run --project "$PROJECT_DIR" "$PROJECT_DIR/.claude/skills/content-pipeline/scripts/grok-query.py" grok-4-1-fast-reasoning
```

Replace `<metadata>` with the source metadata (title, author, URL, description) and `<content>` with the full extracted content.

`$PROJECT_DIR` is the tc-transcript-bot root directory (set by the bot script as `$TC_PROJECT_DIR`).

The script prints Grok's response to stdout.

---

## What to Pass In

**Metadata** (always include what's available):
- Source URL
- Author name or username
- Title or video description
- Publication or platform
- Date if available

**Content:**
- Full verbatim transcript for video
- Full article body for articles
- Full tweet text for tweets

The more context Grok has on the source, the more accurate its X analysis will be.

---

## What Grok Returns

Grok surfaces:
- What people on X are saying about this topic right now
- The most relevant tweets with direct links
- What angle or element is generating the most reaction
- Contradictions, pile-ons, or supporting reactions

---

## Handling the Response

Paste Grok's full response verbatim into the **Viral Trends** section of the output document. Do not edit, summarize, or filter it.

If the Grok call fails or times out:
- Include a note in the Viral Trends section: "Grok enrichment unavailable for this document."
- Continue to Step 3 and generate the post option using only the raw content.

---

## Future Routing

This file is the single place to add content-type routing when the pipeline evolves. Examples of changes to make here:
- Route video content to a different prompt optimized for spoken word
- Route investigative documents to a deeper research prompt
- Add a second Grok call for breaking news to capture real-time reaction
- Swap model version (currently `grok-4-1-fast-reasoning`)
