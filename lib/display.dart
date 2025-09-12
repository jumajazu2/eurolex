import 'package:eurolex/search.dart';
import 'package:flutter/material.dart';

import 'package:eurolex/main.dart';

import 'package:eurolex/processDOM.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'dart:convert';

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

Future getContext(celex, pointer) async {
  // Simulate fetching context from a database or API

  int gte = int.tryParse(pointer) != null ? int.parse(pointer) - 10 : 0;
  int lte = int.tryParse(pointer) != null ? int.parse(pointer) + 10 : 0;

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
    "size": 50,
  };
  print(
    "Active index: $activeIndex, getting context for Celex: $celex, pointer: $pointer, gte: $gte, lte: $lte, query: $query",
  );
  var resultsContext = await sendToOpenSearch(
    'http://$osServer/$activeIndex/_search',
    [jsonEncode(query)],
  );
  var decodedResults = jsonDecode(resultsContext);

  var hits = decodedResults['hits']['hits'] as List;

  {
    var contextEN =
        hits.map((hit) => hit['_source']['en_text'].toString()).toList();
    var contextSK =
        hits.map((hit) => hit['_source']['sk_text'].toString()).toList();
    var contextCZ =
        hits.map((hit) => hit['_source']['cz_text'].toString()).toList();

    print("Get context: $contextEN, $contextSK, $contextCZ");

    return [contextEN, contextSK, contextCZ];
  }
}
