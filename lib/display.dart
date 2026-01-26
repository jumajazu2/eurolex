import 'package:LegisTracerEU/search.dart';
import 'package:flutter/material.dart';

import 'package:LegisTracerEU/main.dart';

import 'package:LegisTracerEU/processDOM.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';

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

Future getContext(
  celex,
  pointer,
  String index,
  int window, {
  String? filename,
  String? source,
}) async {
  print("=== getContext called ===");
  print("  celex: $celex");
  print("  pointer: $pointer");
  print("  index: $index");
  print("  window: $window");
  print("  filename: $filename");
  print("  source: $source");

  // Parse sequenceId
  final center = int.tryParse(pointer) ?? 0;

  // Prepare safe API parameters
  final List<String> langs = [
    if (lang1 != null && lang1!.isNotEmpty) lang1!,
    if (lang2 != null && lang2!.isNotEmpty) lang2!,
    if (lang3 != null && lang3!.isNotEmpty) lang3!,
  ];

  Map<String, dynamic> contextRequest = {
    "index": index,
    "sequenceId": center,
    "window": window,
    "langs": langs,
  };

  // Add celex or filename
  if (celex != null && celex.toString().isNotEmpty) {
    contextRequest["celex"] = celex.toString();
  } else if (filename != null && filename.isNotEmpty) {
    contextRequest["filename"] = filename;
  } else {
    print("ERROR: No celex or filename provided");
    return [<String>[], <String>[], <String>[], <String>[]];
  }

  // Call safe server endpoint
  try {
    final response = await http
        .post(
          Uri.parse('https://$osServer/context'),
          headers: addDeviceIdHeader({
            'Content-Type': 'application/json',
            'x-api-key': jsonSettings['access_key'] ?? DEFAULT_ACCESS_KEY,
            'x-email': '${jsonSettings['user_email']}',
          }),
          body: jsonEncode(contextRequest),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      print("Context fetch error: ${response.statusCode} - ${response.body}");
      return [<String>[], <String>[], <String>[], <String>[]];
    }

    Map<String, dynamic> decodedResults;
    try {
      decodedResults = jsonDecode(response.body) as Map<String, dynamic>;
      print("  OpenSearch response hits: ${decodedResults['hits']?['total']}");
      print(
        "  Number of hits returned: ${(decodedResults['hits']?['hits'] as List?)?.length ?? 0}",
      );
      if (decodedResults['error'] != null) {
        print("  ERROR in response: ${decodedResults['error']}");
        return [<String>[], <String>[], <String>[], <String>[]];
      }
    } on FormatException catch (_) {
      print('Context fetch failed: invalid response.');
      return [<String>[], <String>[], <String>[], <String>[]];
    }

    var hits = decodedResults['hits']['hits'] as List;
    print("  Processing ${hits.length} context hits");

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
  } on TimeoutException catch (e) {
    print("Context timeout: $e");
    return [<String>[], <String>[], <String>[], <String>[]];
  } catch (e) {
    print("Context fetch unexpected error: $e");
    return [<String>[], <String>[], <String>[], <String>[]];
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
