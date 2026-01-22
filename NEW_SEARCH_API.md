# New Search API Documentation

## Overview

The new `/search` endpoint provides a simplified, parameter-based API where queries are built server-side. This improves security and simplifies client code.

## Endpoint

```
POST https://search.pts-translation.sk/search
```

## Request Format

### Headers
```dart
{
  'Content-Type': 'application/json',
  'x-api-key': 'your-api-key',      // Required
  'x-email': 'your@email.com',       // Required for trial
  'x-device-id': 'device-uuid',      // Optional
}
```

### Body Parameters

```json
{
  "index": "eu_7239_eulaw",          // Index name, "*" for all, or specific index
  "term": "banking supervision",     // Search term (required)
  "langs": ["en", "sk", "de"],       // Array of language codes (required)
  "pattern": 1,                      // Query pattern 1-5 (optional, default: 1)
  "size": 50,                        // Max results (optional, default: 50, max: 100)
  "existsLangs": ["en", "sk"]        // Languages that must exist (optional, defaults to langs)
}
```

## Query Patterns

### Pattern 1: Phrase Search (Source Language Only)
**Use case:** Precise phrase matching in first language
**Maps to:** `_startSearch()` - "Phrase" button

```dart
final response = await http.post(
  Uri.parse('https://$osServer/search'),
  headers: {
    'Content-Type': 'application/json',
    'x-api-key': jsonSettings['access_key'],
    'x-email': jsonSettings['user_email'],
  },
  body: jsonEncode({
    'index': activeIndex,
    'term': _searchController.text,
    'langs': [lang1, lang2, lang3],
    'pattern': 1,
    'size': 50,
    'existsLangs': [lang1, lang2, lang3],
  }),
);
```

**Server-side query:**
```json
{
  "query": {
    "bool": {
      "must": [
        { "exists": { "field": "en_text" } },
        { "match_phrase": { "en_text": { "query": "term", "slop": 2, "boost": 1.5 } } }
      ]
    }
  },
  "size": 50
}
```

### Pattern 2: Multi-Match with Fuzziness
**Use case:** Fuzzy matching across all languages
**Maps to:** `_startSearch2()` - "Multi" button

```dart
final response = await http.post(
  Uri.parse('https://$osServer/search'),
  headers: {
    'Content-Type': 'application/json',
    'x-api-key': jsonSettings['access_key'],
    'x-email': jsonSettings['user_email'],
  },
  body: jsonEncode({
    'index': activeIndex,
    'term': _searchController.text,
    'langs': [lang1, lang2, lang3],
    'pattern': 2,
    'size': 50,
  }),
);
```

**Server-side query:**
```json
{
  "query": {
    "bool": {
      "must": [
        { "exists": { "field": "en_text" } },
        {
          "multi_match": {
            "query": "term",
            "fields": ["en_text", "sk_text", "de_text"],
            "fuzziness": "AUTO",
            "minimum_should_match": "80%"
          }
        },
        { "term": { "paragraphsNotMatched": false } }
      ]
    }
  },
  "size": 50,
  "highlight": { "fields": { "en_text": {}, "sk_text": {}, "de_text": {} } }
}
```

### Pattern 3: Combined Phrase + Fuzzy
**Use case:** Best of both phrase and fuzzy matching
**Maps to:** `_startSearch3()` - "Multi+" button

```dart
final response = await http.post(
  Uri.parse('https://$osServer/search'),
  headers: {
    'Content-Type': 'application/json',
    'x-api-key': jsonSettings['access_key'],
    'x-email': jsonSettings['user_email'],
  },
  body: jsonEncode({
    'index': activeIndex,
    'term': _searchController.text,
    'langs': [lang1, lang2, lang3],
    'pattern': 3,
    'size': 25,
  }),
);
```

**Server-side query:**
```json
{
  "query": {
    "bool": {
      "must": [{ "exists": { "field": "en_text" } }],
      "should": [
        { "match_phrase": { "en_text": { "query": "term", "slop": 2, "boost": 3.0 } } },
        { "match": { "en_text": { "query": "term", "fuzziness": "AUTO", "operator": "and", "boost": 1.0 } } },
        { "match_phrase": { "sk_text": { "query": "term", "slop": 2, "boost": 3.0 } } },
        { "match": { "sk_text": { "query": "term", "fuzziness": "AUTO", "operator": "and", "boost": 1.0 } } }
      ],
      "minimum_should_match": 1
    }
  },
  "size": 25
}
```

### Pattern 4: Intervals Query (Ordered Tokens)
**Use case:** Find tokens in specific order with gaps
**Maps to:** `_startIntervalsTest()` - "A/B" button

```dart
final response = await http.post(
  Uri.parse('https://$osServer/search'),
  headers: {
    'Content-Type': 'application/json',
    'x-api-key': jsonSettings['access_key'],
    'x-email': jsonSettings['user_email'],
  },
  body: jsonEncode({
    'index': activeIndex,
    'term': _searchController.text,
    'langs': [lang1, lang2, lang3],
    'pattern': 4,
    'size': 50,
  }),
);
```

**Server-side query:**
```json
{
  "query": {
    "bool": {
      "should": [
        {
          "intervals": {
            "en_text": {
              "all_of": {
                "ordered": true,
                "intervals": [
                  { "match": { "query": "word1" } },
                  { "match": { "query": "word2" } }
                ],
                "max_gaps": 3
              }
            }
          }
        }
      ],
      "minimum_should_match": 1
    }
  },
  "size": 50
}
```

### Pattern 5: Phrase Search ALL Indices
**Use case:** Search across all indices with wildcard fields
**Maps to:** `_startSearchPhraseAll()` - "All" button

```dart
final response = await http.post(
  Uri.parse('https://$osServer/search'),
  headers: {
    'Content-Type': 'application/json',
    'x-api-key': jsonSettings['access_key'],
    'x-email': jsonSettings['user_email'],
  },
  body: jsonEncode({
    'index': '*',  // Search all indices
    'term': _searchController.text,
    'langs': [lang1, lang2, lang3],
    'pattern': 5,
    'size': 50,
  }),
);
```

**Server-side query:**
```json
{
  "query": {
    "bool": {
      "must": [
        { "exists": { "field": "en_text" } },
        {
          "multi_match": {
            "type": "phrase",
            "query": "term",
            "slop": 10,
            "fields": ["*_text"],
            "auto_generate_synonyms_phrase_query": false,
            "lenient": true
          }
        }
      ]
    }
  },
  "size": 50,
  "highlight": {
    "require_field_match": false,
    "fields": { "*_text": {} }
  }
}
```

## Migration Guide

### Old Method (Legacy)
```dart
// Build full query client-side
var query = {
  "query": {
    "bool": {
      "must": [
        { "match_phrase": { "en_text": { "query": "term" } } }
      ]
    }
  },
  "size": 50,
};

// Send to index-specific endpoint
final response = await sendToOpenSearch(
  'https://$osServer/$activeIndex/_search',
  [jsonEncode(query)],
);
```

### New Method
```dart
// Send parameters only
final response = await http.post(
  Uri.parse('https://$osServer/search'),
  headers: {
    'Content-Type': 'application/json',
    'x-api-key': jsonSettings['access_key'],
    'x-email': jsonSettings['user_email'],
  },
  body: jsonEncode({
    'index': activeIndex,
    'term': 'search term',
    'langs': ['en', 'sk'],
    'pattern': 1,
    'size': 50,
  }),
);

final data = jsonDecode(response.body);
```

## Response Format

Both methods return the same OpenSearch response format:

```json
{
  "took": 5,
  "timed_out": false,
  "_shards": { "total": 1, "successful": 1, "skipped": 0, "failed": 0 },
  "hits": {
    "total": { "value": 42, "relation": "eq" },
    "max_score": 12.5,
    "hits": [
      {
        "_index": "eu_7239_eulaw",
        "_id": "abc123",
        "_score": 12.5,
        "_source": {
          "sequence_id": 0,
          "en_text": "Text in English...",
          "sk_text": "Text in Slovak...",
          "celex": "32016R0679",
          "dir_id": "123",
          "class": "Article",
          "date": "2023-01-01T00:00:00Z",
          "paragraphsNotMatched": false
        }
      }
    ]
  }
}
```

## Benefits of New Method

1. **Security**: Query logic server-side prevents injection attacks
2. **Simplicity**: Send parameters instead of complex query objects
3. **Consistency**: Server ensures uniform query structure
4. **Maintenance**: Update query logic server-side without app updates
5. **Validation**: Server validates and sanitizes all inputs
6. **Size limit**: Server enforces max result size (100)

## Error Handling

### 400 Bad Request
```json
{ "error": "Invalid `term`" }
{ "error": "Invalid `langs` array" }
{ "error": "Invalid `index` name" }
```

### 401 Unauthorized
```json
{ "error": "Unauthorized: invalid API key" }
```

### 429 Too Many Requests
```json
{ "error": "Too Many Requests: You have exceeded the daily query limit." }
```

### 500 Internal Server Error
```json
{ "error": "Internal Server Error" }
```

## Complete Example Function

```dart
Future<Map<String, dynamic>?> searchWithNewAPI({
  required String term,
  required List<String> langs,
  int pattern = 1,
  String? index,
  int size = 50,
}) async {
  try {
    final response = await http.post(
      Uri.parse('https://$osServer/search'),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': jsonSettings['access_key'] ?? 'trial',
        'x-email': jsonSettings['user_email'] ?? '',
      },
      body: jsonEncode({
        'index': index ?? activeIndex,
        'term': term,
        'langs': langs,
        'pattern': pattern,
        'size': size,
      }),
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 429) {
      showSubscriptionDialog(429);
      return null;
    } else {
      print('Search error: ${response.statusCode} - ${response.body}');
      return null;
    }
  } catch (e) {
    print('Search exception: $e');
    return null;
  }
}

// Usage
final results = await searchWithNewAPI(
  term: 'banking supervision',
  langs: ['en', 'sk', 'de'],
  pattern: 2,
  size: 50,
);
```

## Backward Compatibility

**The legacy method still works!** You can continue using:
```dart
final response = await sendToOpenSearch(
  'https://$osServer/$activeIndex/_search',
  [jsonEncode(fullQuery)],
);
```

This allows gradual migration without breaking existing functionality.
