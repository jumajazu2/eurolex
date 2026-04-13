# Multilingual Sentence Alignment Options

## How the parsing currently works

The pipeline flows through these stages:

1. **Fetch** — `loadHtmtFromCellar()` (preparehtml.dart) downloads one HTML file per language for a given CELEX.

2. **Extract lines** — `extractPlainTextLines()` (processDOM.dart) walks the DOM tree depth-first. Every block-level element (`<p>`, `<div>`, `<li>`, `<td>`, `<h1>`–`<h6>`, etc.) triggers a `flush()`, producing one text line tagged with the CSS class of its enclosing block element (e.g. `"Article 1 text#@#eli-title"`).

3. **Split** — `splitTextAndClass()` (testHtmlDumps.dart) separates text from class into `[text, class]` pairs.

4. **Zip by index** — `processMultilingualMap()` (processDOM.dart) iterates `for (int i = 0; i < numParagraphs; i++)` and zips all language arrays by **positional index**. Line `i` of EN is matched with line `i` of SK, CS, FR, etc.

5. **Upload** — Each zipped entry becomes one OpenSearch document with `en_text`, `sk_text`, `cs_text`, etc.

## The root problem

**Alignment is purely positional.** There are no structural anchors — the code simply trusts that line `i` in English corresponds to line `i` in Slovak. When source HTMLs differ structurally (even slightly), the count mismatches and everything after the divergence point is shifted. Common causes:

- A language variant has an **extra `<div>` wrapper** or `<br>` that produces an extra empty-then-flushed line
- A footnote, date line, or translator note exists in one language but not another
- A `<table>` renders with different `<tr>`/`<td>` counts across languages
- One language has a legal notice paragraph that another lacks
- A `<p>` tag is self-closing in one variant but wraps content in another

The code **detects** the mismatch (`paragraphsNotMatched` flag, length logging) but doesn't **correct** it.

---

## Proposed solutions (from simplest to most robust)

### 1. Class-sequence alignment (low effort, high impact)

We already extract and tag each line with its CSS class (`eli-title`, `normal`, `oj-hd-date`, `doc-ti`, `tbl-*`, etc.). EUR-Lex uses **consistent semantic CSS classes** across all language variants of the same CELEX.

**Approach:** Before zipping, align language arrays by matching the **sequence of CSS class labels**, not by raw index. This is essentially a diff/LCS (longest common subsequence) on the class sequences:

```
EN classes: [eli-title, doc-ti, normal, normal, tbl-hdr, tbl-cell, tbl-cell, normal]
SK classes: [eli-title, doc-ti, normal, normal, normal, tbl-hdr, tbl-cell, tbl-cell, normal]
                                        ^^^ extra "normal" in SK
```

Compute the LCS of class sequences, then only zip lines at positions that have matching class labels. Unmatched lines get flagged or dropped. This would eliminate most shifts caused by extra wrapper divs or language-specific boilerplate.

**Pros:** Uses data we already have; no external dependencies; handles the most common shift cause.
**Cons:** Won't help if the same class appears many times in a row (e.g. 50 consecutive `normal` paragraphs) — ambiguity within runs of identical classes.

### 2. Structural anchor points (medium effort, high impact)

EUR-Lex documents have a consistent structural skeleton: title, preamble, recitals ("Whereas..."), articles ("Article 1", "Article 2"), annexes. These are marked by distinctive CSS classes like `eli-title`, `doc-ti`, `oj-doc-ti`, `sti-art`, `sti-art-ti`, etc.

**Approach:** In a pre-pass, identify "anchor" lines by recognisable classes (or by regex matching "Article \d+", "ANNEX", "CHAPTER", etc. which is language-independent in numbering). Split each language's line list into **segments** between anchors, then align segment-by-segment. Within each segment, fall back to positional alignment.

This is essentially the same principle as sentence alignment tools (like Hunalign) use: first align "hard" anchor points (numbers, proper nouns, structure), then align the soft content between them.

**Pros:** Robust against shifts that cross structural boundaries; limits damage from one mismatch to a single segment.
**Cons:** Requires a curated list of EUR-Lex class prefixes that act as anchors; some documents may have non-standard markup.

### 3. Length-ratio heuristic (low effort, moderate impact)

For each line pair (EN[i], SK[i]), compute the character-length ratio. Parallel translations of EU legal text have a fairly stable ratio per language pair (e.g. SK/EN ≈ 0.95–1.15). If a pair suddenly has ratio 0.3 or 3.0, it signals a shift.

**Approach:** After positional zipping, scan for outlier ratios. When found, attempt local re-alignment by checking if skipping 1–2 lines in one language restores a reasonable ratio for subsequent pairs.

**Pros:** Very simple to implement; catches obvious misalignments.
**Cons:** Heuristic — can't handle complex multi-line shifts; may produce false positives on short lines.

### 4. Numbered element matching (medium effort, high impact)

EU legislation is heavily numbered: articles, paragraphs, subparagraphs, recitals, annexes all carry numbers that are **identical across all language versions**. Numbers like "1.", "(a)", "(i)", "(23)" appear at the start of paragraphs and are language-invariant.

**Approach:** Extract a "numbering fingerprint" from each line (regex for leading numbers, letters in parens, Roman numerals). Match lines across languages that share the same fingerprint. Lines between matched numbered anchors are aligned positionally.

**Pros:** Extremely reliable for legislative text; numbers don't change across translations.
**Cons:** Not all document types are numbered; needs regex tuning for different numbering styles.

### 5. DOM-ID or data-attribute alignment (low effort if available)

Some EUR-Lex XHTML variants include `id` attributes on structural elements (e.g. `id="art_1"`, `id="rec_23"`). If present, these are identical across language versions.

**Approach:** During `extractPlainTextLines`, capture element `id`s alongside classes. Use matching IDs as hard alignment anchors.

**Pros:** Perfect alignment when IDs exist; zero ambiguity.
**Cons:** Not all EUR-Lex documents have IDs; HTML variants have fewer than XHTML.

---

## Recommended approach: combine 1 + 2 + 4

The highest-value implementation would be a **two-pass alignment**:

1. **Pass 1 — Anchor detection.** Scan each language's line list for structural anchors: recognisable CSS classes (`eli-*`, `doc-ti`, `sti-art*`) AND numbered element fingerprints ("Article 1", "(a)", "ANNEX I"). These create hard sync points shared across all languages.

2. **Pass 2 — Segment alignment.** Between each pair of adjacent anchors, align the sub-arrays using class-sequence LCS (approach 1). Within runs of identical classes, fall back to positional.

This would be implemented as a new function (e.g. `alignMultilingualLines()`) called inside `processMultilingualMap` **before** the zipping loop, replacing the current raw positional index.

The `paragraphsNotMatched` flag already tells us which documents need this — we could even run the alignment only when lengths differ, keeping the fast path for documents that already match.

---

## Repairing already-uploaded documents in OpenSearch

### What's stored per OpenSearch document

Each document (one per `sequence_id`) contains:
```json
{
  "sequence_id": 0,
  "en_text": "Article 1 Scope",
  "sk_text": "Článok 1 Rozsah pôsobnosti",
  "cs_text": "Článek 1 Oblast působnosti",
  "celex": "32022R1379",
  "class": "sti-art",
  "paragraphsNotMatched": true
}
```

### Why in-place repair is not feasible

1. **Per-language structure is lost.** The original per-language line arrays (with individual CSS classes per language) were discarded after zipping. Only the `class` from whichever EU language happened to have a non-empty value first is stored (the `classForIndex` function in `processDOM.dart` picks the first match from `langsEU`). The per-language class sequences cannot be reconstructed from OpenSearch data.

2. **The shift origin is unknown.** If EN had 100 lines and SK had 102, the stored documents have SK text at wrong positions from some unknown divergence point onward. Without the original per-language arrays, it's impossible to determine which lines are the "extra" ones.

3. **Text-only re-alignment is fragile.** Pulling all docs for a CELEX back, extracting per-language columns, and re-aligning by length ratios or numbering is theoretically possible but unreliable — it would be aligning already-damaged data without the structural metadata that the new algorithm would use.

### Recommended approach: targeted re-upload

**Re-upload is the right path**, but it can be targeted and efficient:

- **Only re-upload misaligned documents.** The `paragraphsNotMatched: true` flag is already indexed. A single OpenSearch query finds all affected CELEXes:
  ```json
  {
    "query": {"term": {"paragraphsNotMatched": true}},
    "aggs": {
      "celexes": {
        "terms": {"field": "celex.keyword", "size": 10000}
      }
    }
  }
  ```
  This gives the exact list of CELEXes that need re-processing.

- **Delete-then-reupload per CELEX.** For each affected CELEX, delete its documents (`DELETE-by-query` on `celex.keyword`), re-download from EUR-Lex, run through the new alignment algorithm, and upload.

- **Clean documents stay untouched.** Anything with `paragraphsNotMatched: false` and matching line counts is already correctly aligned — no action needed.
