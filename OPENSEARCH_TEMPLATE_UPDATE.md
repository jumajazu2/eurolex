# OpenSearch Template Update for TMX Compatibility

## Problem
The current `eurolex-template` index template doesn't have a `source` field mapping. TMX documents use `source: "TMX"` to distinguish them from CELEX documents, but without proper mapping, the `.keyword` subfield isn't available for exact matching in context queries.

## Solution
Add the `source` field to the template's properties section.

## Required Template Update

In your OpenSearch cluster, update the `eurolex-template` by adding this field to the `properties` section:

```json
"source": {
    "type": "keyword"
}
```

### Complete Updated Properties Section

```json
"properties": {
    "date": {
        "type": "date"
    },
    "paragraphsNotMatched": {
        "type": "boolean"
    },
    "namesNotMatched": {
        "type": "boolean"
    },
    "filename": {
        "type": "keyword"
    },
    "source": {
        "type": "keyword"
    },
    "sequence_id": {
        "type": "integer"
    },
    "dir_id": {
        "normalizer": "fold_lower",
        "type": "keyword"
    },
    "class": {
        "type": "keyword"
    },
    "celex": {
        "normalizer": "fold_lower",
        "type": "keyword"
    }
}
```

## How to Apply

### Option 1: Update via OpenSearch Dashboards (Dev Tools)
```
PUT _index_template/eurolex-template
{
  "index_patterns": ["eurolex*", "eu-*", "eu_*"],
  "priority": 200,
  "template": {
    "settings": {
      ... (keep existing settings) ...
    },
    "mappings": {
      ... (keep existing mappings) ...
      "properties": {
        ... (add source field here) ...
      }
    }
  }
}
```

### Option 2: Update via API
```bash
curl -X PUT "https://your-opensearch-server/_index_template/eurolex-template" \
  -H 'Content-Type: application/json' \
  -d '{
    ... (updated template JSON) ...
  }'
```

## Affected Indices

- **Existing indices**: Will NOT be affected. Already created indices keep their current mappings.
- **New indices**: Will automatically use the updated template with the `source` field properly mapped.

## For Existing TMX Indices

If you have TMX data in existing indices (e.g., `eu_7239_0193b`), you have two options:

1. **Keep using them**: The flexible query in `display.dart` handles both keyword and non-keyword fields
2. **Reindex**: Delete and re-upload after updating the template for optimal performance

## Field Usage in TMX Documents

| Field | Usage | Value |
|-------|-------|-------|
| `sequence_id` | Document order/context | 0, 1, 2, ... |
| `filename` | TMX file name | "0193tm.tmx" |
| `source` | Document type | "TMX" |
| `paragraphsNotMatched` | Search filter | `false` |
| `namesNotMatched` | Search filter | `false` |
| `*_text` | Language content | Dynamic (en_text, sk_text, etc.) |

## Field Usage in CELEX Documents

| Field | Usage | Value |
|-------|-------|-------|
| `sequence_id` | Document order/context | 0, 1, 2, ... |
| `filename` | Document identifier | "32016L0097" |
| `celex` | CELEX number | "32016L0097" |
| `dir_id` | Directory ID | "1" |
| `class` | CSS class | "oj-hd-lg" |
| `date` | Document date | ISO date |
| `paragraphsNotMatched` | Search filter | `true` or `false` |
| `*_text` | Language content | 23 EU languages |

## Verification

After updating the template and creating a new index, verify the mapping:

```
GET /eu_7239_your_new_index/_mapping
```

You should see `source` as a `keyword` type field.
