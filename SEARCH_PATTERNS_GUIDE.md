# OpenSearch Query Patterns Guide

Complete guide to the 6 search patterns available in the OSLex/EuroLex application.

---

## Pattern 1: Phrase Search (Phrase Button)

### Description
Searches for a phrase in the **primary language only** (lang1) with allowed word gaps.

### Query Structure
```javascript
{
  match_phrase: {
    [lang1_text]: {
      query: term,
      slop: 2,
      boost: 1.5
    }
  }
}
```

### Parameters
- **`slop: 2`** - Allows up to 2 words between search terms
- **`boost: 1.5`** - Increases relevance score by 50%
- **Word order matters** - Words must appear in the specified order

### What Matches ✅

**Search:** `"european commission"`

| Document Text | Match? | Reason |
|--------------|--------|---------|
| `"european commission directive"` | ✅ | Exact phrase |
| `"european economic commission"` | ✅ | 1 word gap (within slop=2) |
| `"european union and commission"` | ✅ | 2 word gap (at slop limit) |
| `"european parliament and commission"` | ❌ | 3 word gap (exceeds slop) |
| `"commission european"` | ❌ | Wrong word order |
| `"europaische kommission"` | ❌ | Different language (not in lang1) |

### Use Cases
- Exact legal term searches
- Finding specific phrases in regulations
- When word order is critical (e.g., "Member State" vs "State Member")

---

## Pattern 2: Multi-Match with Fuzziness (Multi Button)

### Description
Searches across **all configured languages** with typo tolerance. **Word order doesn't matter**. Only returns documents where all language fields exist.

### Query Structure
```javascript
{
  multi_match: {
    query: term,
    fields: ["en_text", "sk_text", "de_text"],
    fuzziness: "AUTO",
    minimum_should_match: "80%"
  },
  term: { paragraphsNotMatched: false }
}
```

### Parameters
- **`fuzziness: "AUTO"`** - Allows typos based on word length:
  - 0-2 chars: 0 typos (exact match)
  - 3-5 chars: 1 typo allowed
  - 6+ chars: 2 typos allowed
- **`minimum_should_match: "80%"`** - At least 80% of words must match
- **Bag-of-words** - Words can appear anywhere, in any order
- **`paragraphsNotMatched: false`** - Excludes misaligned translations

### What Matches ✅

**Search:** `"european commission directive"`

| Document Text | Match? | Reason |
|--------------|--------|---------|
| `"directive from the european commission"` | ✅ | All 3 words present (different order) |
| `"euroepan commision directive"` | ✅ | 2 typos allowed (fuzziness) |
| `"european parliament directive 2023"` | ✅ | 2/3 words = 67% but rounds to 3 words |
| `"commission regulation"` | ❌ | 1/3 words = 33% < 80% |
| `"europe commission"` | ❌ | Only 1/3 exact matches |

**Search:** `"translation memory"` (2 words)

| Document Text | Match? | Reason |
|--------------|--------|---------|
| `"translation memory system"` | ✅ | 2/2 words (100%) |
| `"memory for translation"` | ✅ | 2/2 words (any order) |
| `"translaton memry"` | ✅ | 2 typos (fuzziness applied) |
| `"translation"` | ❌ | 1/2 words = 50% |
| `"translator"` | ❌ | Too different (fuzziness limit) |

### Rounding Behavior
| Total Words | 80% | Required Matches |
|-------------|-----|------------------|
| 1 | 0.8 | 1 (100%) |
| 2 | 1.6 | 2 (100%) |
| 3 | 2.4 | 3 (100%) |
| 4 | 3.2 | 3 (75%) |
| 5 | 4.0 | 4 (80%) |
| 10 | 8.0 | 8 (80%) |

### Use Cases
- General searches across multilingual content
- When you're unsure of exact spelling
- Finding content regardless of language
- Forgiving searches for translation memory

---

## Pattern 3: Phrase + Fuzzy Hybrid (Multi+ Button)

### Description
Combines **phrase matching** (with word order) and **fuzzy matching** (without order). Rewards exact phrases but also finds scattered words.

### Query Structure
```javascript
{
  should: [
    { match_phrase: { [field]: { query, slop: 2, boost: 3.0 } } },  // Phrase
    { match: { [field]: { query, fuzziness: "AUTO", operator: "and", boost: 1.0 } } }  // Fuzzy
  ],
  minimum_should_match: 1
}
```

### Parameters
- **Phrase clauses** - `boost: 3.0` (3x score for exact phrases)
- **Fuzzy clauses** - `boost: 1.0` (normal score)
- **`operator: "and"`** - All words must appear (scattered anywhere)
- Applied to **each configured language field**

### Scoring System

**Search:** `"european commission directive"`

| Document Text | Phrase Match? | Fuzzy Match? | Score Weight |
|--------------|---------------|--------------|--------------|
| `"european commission directive"` | ✅ (boost 3x) | ✅ (boost 1x) | **4x total** |
| `"directive european commission"` | ❌ | ✅ (boost 1x) | **1x** |
| `"european union commission directive"` | ✅ (slop allows) | ✅ | **4x** |
| `"commission regulation europe"` | ❌ | ❌ (missing "directive") | **0** |

### What Matches ✅

Results are **ranked by score** - exact phrases appear first, scattered words appear later.

**Search:** `"translation memory management"`

| Rank | Document Text | Why Higher Rank? |
|------|--------------|------------------|
| 🥇 | `"translation memory management system"` | Exact phrase match (3x boost) |
| 🥈 | `"memory management for translation"` | Some phrase overlap + fuzzy |
| 🥉 | `"translation tools, memory systems, management"` | All words scattered (1x boost) |
| ❌ | `"translation memory"` | Missing "management" |

### Use Cases
- Best-of-both-worlds search
- Finding similar content with flexibility
- Prioritizing exact legal phrases while catching variations
- When you want precise results first, flexible results second

---

## Pattern 4: Intervals Query (A/B Button)

### Description
Searches for **ordered tokens** (words) with controlled gaps. Maintains word sequence while allowing some flexibility.

### Query Structure
```javascript
{
  intervals: {
    [field]: {
      all_of: {
        ordered: true,
        intervals: [
          { match: { query: "word1" } },
          { match: { query: "word2" } },
          { match: { query: "word3" } }
        ],
        max_gaps: 3
      }
    }
  }
}
```

### Parameters
- **`ordered: true`** - Words must appear in order
- **`max_gaps: 3`** - Maximum 3 words between tokens
- **Token filtering** - Only uses words >2 characters
- **Max 4 tokens** - Takes first 4 significant words

### Token Extraction

**Search:** `"The European Commission's new directive on data"`

Tokens extracted: `["European", "Commission", "new", "directive"]`
- ❌ "The" - too short (≤2 chars)
- ✅ "European" - token 1
- ✅ "Commission" - token 2
- ❌ "on" - too short
- (limited to 4 tokens max)

### What Matches ✅

**Tokens:** `["european", "commission", "directive"]`

| Document Text | Match? | Reason |
|--------------|--------|---------|
| `"european commission directive"` | ✅ | Exact order, no gaps |
| `"european economic commission new directive"` | ✅ | 3 gaps total (at limit) |
| `"european parliament and commission legal directive"` | ❌ | 4 gaps (exceeds max_gaps) |
| `"directive european commission"` | ❌ | Wrong order |
| `"european directive commission"` | ❌ | Tokens out of order |

### Gap Counting

```
"european [gap1] [gap2] commission [gap3] directive"
Total gaps: 3 ✅ (at limit)

"european [gap1] [gap2] [gap3] [gap4] commission directive"  
Total gaps: 4 ❌ (exceeds limit)
```

### Use Cases
- Finding specific sentence structures
- Legal citations with flexible formatting
- When word order matters but some variation is acceptable
- Searching for formulaic language patterns

---

## Pattern 5: Phrase Search All Indices (All Button)

### Description
Searches across **ALL indices** using wildcard field matching. Finds phrases in any language field across the entire database.

### Query Structure
```javascript
{
  multi_match: {
    type: "phrase",
    query: term,
    slop: 10,
    fields: ["*_text"],  // Wildcard: matches all language fields
    auto_generate_synonyms_phrase_query: false,
    lenient: true
  }
}
```

### Parameters
- **`fields: ["*_text"]`** - Searches ALL language fields (en_text, sk_text, de_text, etc.)
- **`slop: 10`** - Very forgiving gap allowance
- **`type: "phrase"`** - Maintains word order
- **`lenient: true`** - Ignores field mapping issues
- **Index: `"*"`** - Searches all available indices

### What Matches ✅

**Search:** `"data protection"`

| Index | Language Field | Document Text | Match? |
|-------|----------------|---------------|--------|
| `eu_2016_gdpr` | `en_text` | `"data protection regulation"` | ✅ |
| `eu_2016_gdpr` | `de_text` | `"datenschutz"` | ❌ |
| `eu_7239_custom` | `sk_text` | `"ochrana údajov"` | ❌ |
| `eu_directive` | `en_text` | `"data [8 words] protection"` | ✅ (within slop) |
| `eu_regulation` | `en_text` | `"data [11 words] protection"` | ❌ (exceeds slop) |

### Index Coverage

```
Search across:
├── eu_2016_gdpr
├── eu_2018_celex
├── eu_7239_custom_tm
├── eu_7239_0193tm
└── [all other indices in database]
```

### Use Cases
- Searching entire database without knowing which index
- Finding all occurrences of a phrase across different sources
- Cross-corpus searches
- When you need comprehensive coverage

---

## Pattern 6: Trados Auto-Lookup (Auto-Lookup Integration)

### Description
**Dedicated pattern for Trados Studio integration**. Currently identical to Pattern 2 but can be customized server-side without app updates.

### Query Structure
```javascript
// Same as Pattern 2
{
  multi_match: {
    query: term,
    fields: ["en_text", "sk_text", "de_text"],
    fuzziness: "AUTO",
    minimum_should_match: "80%"
  },
  term: { paragraphsNotMatched: false }
}
```

### Special Characteristics
- **Auto-triggered** - Fires when Trados sends segments
- **Sanitized input** - Removes `{...}` tags and `<...>` markup
- **Limited results** - Returns only 10 results (configurable)
- **Server-side tuning** - Can be modified without rebuilding app

### Input Sanitization

**Trados sends:** `"The <emphasis>European Commission</emphasis> {1}directive{2}"`

**After sanitization:** `"The European Commission directive"`

Removed:
- `{...}` tag pairs
- `<...>` XML/HTML tags
- Extra whitespace

### What Matches ✅

**Sanitized search:** `"translation memory system"`

| TM Segment | Match? | Reason |
|------------|--------|---------|
| `"translation memory system for CAT tools"` | ✅ | All words present |
| `"system for translation memory"` | ✅ | All words (different order) |
| `"translaton memry system"` | ✅ | Typos allowed |
| `"translation database"` | ❌ | Only 1/3 words |
| `"TM system"` | ❌ | Missing critical words |

### Use Cases
- Real-time translation memory lookup from Trados Studio
- Auto-suggesting translations during translation work
- Finding similar segments while translating
- Context-aware CAT tool integration

### Server-Side Customization

You can modify Pattern 6 in `server.js` without rebuilding the app:

```javascript
// Example: Make it more strict for Trados
if (pattern === 6) {
    return {
        query: {
            bool: {
                must: [
                    ...existsClauses,
                    {
                        multi_match: {
                            query: term,
                            fields,
                            fuzziness: "1",  // Changed: Only 1 typo allowed
                            minimum_should_match: "90%"  // Changed: 90% instead of 80%
                        }
                    }
                ]
            }
        },
        size
    };
}
```

Restart server → Changes apply immediately → No app redistribution needed.

---

## Comparison Table

| Feature | Pattern 1 | Pattern 2 | Pattern 3 | Pattern 4 | Pattern 5 | Pattern 6 |
|---------|-----------|-----------|-----------|-----------|-----------|-----------|
| **Word order matters** | ✅ Yes | ❌ No | Hybrid | ✅ Yes | ✅ Yes | ❌ No |
| **Typo tolerance** | ❌ No | ✅ AUTO | ✅ AUTO | ❌ No | ❌ No | ✅ AUTO |
| **Multi-language** | ❌ Lang1 only | ✅ All | ✅ All | ✅ All | ✅ All | ✅ All |
| **Gap tolerance** | 2 words | Any | 2 words | 3 words | 10 words | Any |
| **Index scope** | Active | Active | Active | Active | **ALL** | Active |
| **Partial word match** | ❌ No | ❌ No | ❌ No | ❌ No | ❌ No | ❌ No |
| **paragraphsNotMatched filter** | ❌ No | ✅ Yes | ❌ No | ❌ No | ❌ No | ✅ Yes |
| **Result size** | 50 | 50 | 25 | 50 | 50 | 10 |

---

## Technical Notes

### Fuzziness AUTO Behavior

| Word Length | Allowed Edits | Example |
|-------------|---------------|---------|
| 0-2 chars | 0 | `"EU"` → exact only |
| 3-5 chars | 1 | `"law"` → `"las"`, `"low"` |
| 6+ chars | 2 | `"directive"` → `"directiv"`, `"direktive"` |

**Edit distance** = Levenshtein distance (insertions, deletions, substitutions)

### minimum_should_match Rounding

OpenSearch rounds **down** to nearest integer:
- `ceil(word_count * 0.8)` logic is NOT used
- Instead: `floor(word_count * 0.8)` with minimum of 1

### Performance Considerations

**Fastest → Slowest:**
1. Pattern 1 (single field, phrase)
2. Pattern 2 (multi-field, fuzziness)
3. Pattern 3 (multiple queries per field)
4. Pattern 4 (intervals computation)
5. Pattern 5 (all indices, wildcard fields)

**Memory usage:** Pattern 5 > Pattern 3 > Pattern 2 > Pattern 4 > Pattern 1

### Field Requirements

All patterns (except Pattern 1) require **exists clauses**:
```javascript
{ exists: { field: "en_text" } }
{ exists: { field: "sk_text" } }
```

This ensures documents have content in configured languages.

---

## Choosing the Right Pattern

### Decision Tree

```
Do you know the exact phrase?
├─ Yes → Use Pattern 1 (Phrase)
└─ No
   ├─ Is word order important?
   │  ├─ Yes → Use Pattern 4 (Intervals)
   │  └─ No → Use Pattern 2 (Multi)
   │
   ├─ Do you want to search all indices?
   │  └─ Yes → Use Pattern 5 (All)
   │
   ├─ Do you want best of both worlds?
   │  └─ Yes → Use Pattern 3 (Multi+)
   │
   └─ Is this from Trados?
      └─ Yes → Pattern 6 (Auto)
```

---

## Examples by Use Case

### Legal Citation Search
**Best:** Pattern 1 or 4
```
Search: "Article 13 GDPR"
Reason: Word order matters, exact phrase needed
```

### Translation Memory Lookup
**Best:** Pattern 2 or 6
```
Search: "click the submit button"
Reason: Allow typos, word order flexible
```

### Finding Similar Regulations
**Best:** Pattern 3
```
Search: "data protection regulation"
Reason: Exact phrases ranked higher, but also find variations
```

### Cross-Database Search
**Best:** Pattern 5
```
Search: "competition law"
Reason: Need to search all available indices
```

### Auto-Complete/Suggestion
**Best:** Pattern 2
```
Search: partial user input
Reason: Forgiving, fast, handles incomplete queries
```

---

## API Usage Examples

### Pattern 1
```json
{
  "index": "eu_2016_gdpr",
  "term": "data protection officer",
  "langs": ["en", "sk", "de"],
  "pattern": 1,
  "size": 50,
  "existsLangs": ["en", "sk", "de"]
}
```

### Pattern 2
```json
{
  "index": "eu_7239_custom",
  "term": "translaton memry managment",
  "langs": ["en", "sk"],
  "pattern": 2,
  "size": 25
}
```

### Pattern 5
```json
{
  "index": "*",
  "term": "environmental protection",
  "langs": ["en"],
  "pattern": 5,
  "size": 100
}
```

---

## Troubleshooting

### No Results?

1. **Pattern 1** - Try Pattern 2 (order might be wrong)
2. **Pattern 2** - Lower `minimum_should_match` (edit Pattern 6 in server.js)
3. **All patterns** - Check `existsLangs` matches actual document fields
4. **Pattern 5** - Verify index access permissions

### Too Many Results?

1. **Pattern 2/6** - Increase `minimum_should_match` to 90%
2. **Pattern 1/4** - Decrease `slop` value
3. **All patterns** - Reduce `size` parameter
4. **Pattern 3** - Increase phrase boost from 3.0 to 5.0

### Wrong Language Results?

Check `existsLangs` parameter matches desired languages:
```json
"existsLangs": ["en", "sk"]  // Only return docs with EN and SK text
```

---

**Last Updated:** January 24, 2026  
**Server Version:** server.js with Pattern 6 support  
**OpenSearch Version:** 2.x compatible
