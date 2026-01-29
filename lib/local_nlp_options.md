# Why Standard OpenSearch Patterns Struggle with Long, Complex Queries

When searching for long passages or sentences, especially when only a part overlaps with the stored record, standard OpenSearch patterns like `multi_match` with fuzziness and `minimum_should_match` often fail to produce results. Here’s why:

- **multi_match with fuzziness** works best for short queries. With long queries, the number of required matches increases, and fuzziness can’t compensate for large differences in length or word order.
- **minimum_should_match** (even at 60%) still expects a large portion of the terms to match, which is hard with long queries and partial overlaps.
- **Phrase queries (match_phrase)** require the order and proximity to be similar, which is not the case when the query and the record are phrased differently or only partially overlap.

**How to improve:**
1. Split the search string into key phrases or sentences and search for them individually, combining results.
2. Use a bool query with multiple should clauses: Each clause matches a significant phrase or n-gram from the input. This way, a record is a hit if it matches any substantial part.
3. Lower minimum_should_match or remove it, and rely on scoring to rank better matches higher.
4. Use a combination of match and match_phrase: Use match for broad recall, match_phrase for precision.

For privacy-sensitive applications, you can extract key phrases or sentences from text using open-source Node.js libraries that run entirely locally. Here are some recommended options:
# Local Key Phrase and Sentence Extraction in Node.js

For privacy-sensitive applications, you can extract key phrases or sentences from text using open-source Node.js libraries that run entirely locally. Here are some recommended options:

## 1. compromise
- Lightweight, pure JavaScript NLP library.
- Can split text into sentences and extract nouns/phrases.
- Example:
  ```js
  const nlp = require('compromise');
  const doc = nlp(text);
  const sentences = doc.sentences().out('array');
  const nouns = doc.nouns().out('array');
  ```

## 2. natural
- Classic NLP toolkit for Node.js.
- Can tokenize sentences and words, and has basic keyword extraction.
- Example:
  ```js
  const natural = require('natural');
  const tokenizer = new natural.SentenceTokenizer();
  const sentences = tokenizer.tokenize(text);
  ```

## 3. wink-nlp
- Fast, modern NLP library.
- Can extract sentences, entities, and keywords.
- Example:
  ```js
  const winkNLP = require('wink-nlp');
  const model = require('wink-eng-lite-web-model');
  const nlp = winkNLP(model);
  const doc = nlp.readDoc(text);
  const sentences = doc.sentences().out();
  const entities = doc.entities().out();
  ```

## 4. keyword-extractor
- Simple library for extracting keywords from text.
- Example:
  ```js
  const keyword_extractor = require('keyword-extractor');
  const keywords = keyword_extractor.extract(text, { language: 'english', remove_digits: true, return_changed_case: true, remove_duplicates: true });
  ```

## 5. compromise-sentences
- For more advanced sentence splitting with compromise.

---

**All of these libraries run locally and do not send data externally, making them suitable for privacy-sensitive use cases.**

You can integrate any of these libraries into your Node.js application to extract key phrases or sentences for improved search and analysis.