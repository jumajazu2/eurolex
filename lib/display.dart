import 'package:LegisTracerEU/search.dart';
import 'package:flutter/material.dart';

import 'package:LegisTracerEU/main.dart';

import 'package:LegisTracerEU/processDOM.dart';
import 'dart:convert';

/*
TextSpan highlightFoundWords(returnedResult, foundWords) {
  List<TextSpan> spans = [];

  // Using RegExp to split text while keeping punctuation
  RegExp exp = RegExp(r"(\b\w+\b|[^\s])");

  for (var match in exp.allMatches(returnedResult)) {
    String word = match.group(0)!; // Extract word or punctuation

    // Check case-insensitive match
    bool isBold = foundWords
        .map((e) => e.toLowerCase())
        .contains(word.toLowerCase());

    spans.add(
      TextSpan(
        text: "$word ", // Preserve spacing
        style: TextStyle(
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  print("TextSpan created for: \"$returnedResult\" highlighting: $foundWords");
  print(spans);
  return TextSpan(children: spans);
}
*/
TextSpan highlightFoundWords2(String returnedResult, List<String> foundWords) {
  List<TextSpan> spans = [];

  RegExp exp = RegExp(r"\b\w+[-.,!?;:/()`]*\s*");
  var matches = exp.allMatches(returnedResult);

  for (final match in matches) {
    String wordWithPunctuation = match.group(0)!;

    // Extract just the word part (for comparison)
    String wordOnly = wordWithPunctuation.trim().replaceAll(
      RegExp(r'[-.,!?;:/()`]+$'),
      '',
    );

    bool isBold = foundWords
        .map((e) => e.toLowerCase())
        .contains(wordOnly.toLowerCase());

    spans.add(
      TextSpan(
        text: wordWithPunctuation,
        style: TextStyle(
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  return TextSpan(children: spans);
}

//as documents often do not match when parsing, these offsets are used to align the texts,
//alternatively some smart approach could analyse and store offsets in the DB
int offsetlang1 = 0;
int offsetlang2 = 0;
int offsetlang3 = 0;

Future getContext(celex, pointer, String index, int window) async {
  // Simulate fetching context from a database or API
  final center = int.tryParse(pointer) ?? 0;
  int gte = center - window;
  if (gte < 0) gte = 0;
  int lte = center + window;

  var query = {
    "query": {
      "bool": {
        "must": [
          {
            "bool": {
              "should": [
                {
                  "term": {"celex": celex},
                },
                {
                  "term": {"celex.keyword": celex},
                },
              ],
              "minimum_should_match": 1, // At least one condition must match
            },
          },
          {
            "range": {
              "sequence_id": {"gte": gte, "lte": lte},
            },
          },
        ],
      },
    },
    "sort": [
      {
        "sequence_id": {"order": "asc"},
      },
    ],
    "size": 50,
  };

  var resultsContext = await sendToOpenSearch(
    'https://$osServer/$index/_search',
    [jsonEncode(query)],
  ); //BUG: when searching in all indices, which is appropriate, the sequence_id data does not match, now specific index is used, but it will not work for global search
  print(
    "Active index: $activeIndex, getting context for Celex: $celex, pointer: $pointer, gte: $gte, lte: $lte, query: $query",
  );
  Map<String, dynamic> decodedResults;
  try {
    decodedResults = jsonDecode(resultsContext) as Map<String, dynamic>;
  } on FormatException catch (_) {
    // Likely offline or invalid response; return empty context safely
    print('Context fetch failed: offline or invalid response.');
    return [<String>[], <String>[], <String>[], <String>[]];
  } catch (e) {
    print('Context fetch unexpected parse error: $e');
    return [<String>[], <String>[], <String>[], <String>[]];
  }

  var hits = decodedResults['hits']['hits'] as List;

  {
    var contextLang1 =
        hits
            .map(
              (hit) =>
                  hit['_source']['${lang1?.toLowerCase()}_text'].toString(),
            )
            .toList();
    var contextLang2 =
        hits
            .map(
              (hit) =>
                  hit['_source']['${lang2?.toLowerCase()}_text'].toString(),
            )
            .toList();
    var contextLang3 =
        hits
            .map(
              (hit) =>
                  hit['_source']['${lang3?.toLowerCase()}_text'].toString(),
            )
            .toList();

    var sequenceID =
        hits.map((hit) => hit['_source']['sequence_id'].toString()).toList();
    print("Get context: $contextLang1, $contextLang2, $contextLang3");

    return [contextLang1, contextLang2, contextLang3, sequenceID];
  }
}

class HighlightResult {
  final TextSpan span;
  final int? start; // char offset from start of segment
  final int? length; // length of the matched phrase
  HighlightResult({required this.span, this.start, this.length});
}

const Set<String> _standaloneStopWords = {
  'a',
  'an',
  'the',
  'and',
  'or',
  'to',
  'of',
  'in',
  'on',
  'at',
  'for',
};

//const Set<String> _standaloneStopWords = {" "};

/*
//
Replace calls to highlightFoundWords2(...) with:
final res = highlightPhrasePreservingLayout(returnedResult, foundWords);
Use res.span to render; use res.start and res.length for eye-guides across lang2/lang3.

*/

HighlightResult highlightPhrasePreservingLayout(
  String segment,
  List<String> foundPhrases, {
  TextStyle normalStyle = const TextStyle(fontWeight: FontWeight.normal),
  TextStyle highlightStyle = const TextStyle(fontWeight: FontWeight.bold),
}) {
  if (segment.isEmpty || foundPhrases.isEmpty) {
    return HighlightResult(
      span: TextSpan(text: segment, style: normalStyle),
      start: null,
      length: null,
    );
  }

  final lower = segment.toLowerCase();

  // Normalize phrases
  final normalized =
      foundPhrases.map((p) => p.trim()).where((p) => p.isNotEmpty).toList();

  final multiWord =
      normalized
          .where((p) => p.contains(RegExp(r'\s+')))
          .map((p) => p.toLowerCase())
          .toList();

  final singleWord =
      normalized
          .where((p) => !p.contains(RegExp(r'\s+')))
          .map((p) => p.toLowerCase())
          .toList();

  // Exclude single-word stopwords when they are alone;
  // they will still be covered inside multi-word phrases.

  final sw = stopwordsForLangs(lang1: lang1, lang2: lang2, lang3: lang3);
  print("Stopwords for highlighting: $sw");
  final singleWordFiltered = singleWord.where((w) => !sw.contains(w)).toList();

  // Collect matches as named records
  final matches = <({int start, int end})>[];

  // 1) Multi-word phrases: simple case-insensitive indexOf for all occurrences
  for (final p in multiWord) {
    // Build a whitespace-flexible, case-insensitive regex for the phrase
    final pattern = p.split(RegExp(r'\s+')).map(RegExp.escape).join(r'\s+');
    final re = RegExp(pattern, caseSensitive: false);

    for (final m in re.allMatches(segment)) {
      matches.add((start: m.start, end: m.end));
    }
  }

  // 2) Single-word (non-stopword) phrases: word-boundary regex
  for (final w in singleWordFiltered) {
    final re = RegExp(r'\b' + RegExp.escape(w) + r'\b', caseSensitive: false);
    for (final m in re.allMatches(segment)) {
      matches.add((start: m.start, end: m.end));
    }
  }

  if (matches.isEmpty) {
    return HighlightResult(
      span: TextSpan(text: segment, style: normalStyle),
      start: null,
      length: null,
    );
  }

  // Sort by start; at same start prefer longer
  matches.sort((a, b) {
    final byStart = a.start.compareTo(b.start);
    return byStart != 0 ? byStart : (b.end - b.start) - (a.end - a.start);
  });

  // Resolve overlaps: keep non-overlapping, prefer longer when overlapping
  final chosen = <({int start, int end})>[];
  for (final m in matches) {
    if (chosen.isEmpty || m.start >= chosen.last.end) {
      chosen.add(m);
    } else if ((m.end - m.start) > (chosen.last.end - chosen.last.start)) {
      chosen[chosen.length - 1] = m;
    }
  }

  // Build spans preserving exact text
  final children = <InlineSpan>[];
  var cursor = 0;
  for (final m in chosen) {
    if (cursor < m.start) {
      children.add(
        TextSpan(text: segment.substring(cursor, m.start), style: normalStyle),
      );
    }
    children.add(
      TextSpan(text: segment.substring(m.start, m.end), style: highlightStyle),
    );
    cursor = m.end;
  }
  if (cursor < segment.length) {
    children.add(TextSpan(text: segment.substring(cursor), style: normalStyle));
  }

  final first = chosen.first;
  return HighlightResult(
    span: TextSpan(children: children),
    start: first.start,
    length: first.end - first.start,
  );
}
