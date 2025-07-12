import 'package:flutter/material.dart';

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
