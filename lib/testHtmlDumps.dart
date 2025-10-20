// ...existing code...
import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:eurolex/processDOM.dart';
import 'package:eurolex/preparehtml.dart';
import 'package:eurolex/file_handling.dart';
import 'package:eurolex/sparql.dart'
    show fetchSector5CelexTitles2024, fetchSectorXCelexTitles;
// ...existing code...

void testDumps() async {
  var htmlContent = await loadHtmtFromCelex(
    "02016R1036-20200811",
    "EN",
  ); //load html file from disk

  demoDomAndLines(htmlContent);
}

void testDumpsMultiple() async {
  for (var lang in langsEU) {
    var htmlContent = await loadHtmtFromCelex(
      "52024AA0001",
      lang,
    ); //load html file from disk
    var lines = extractPlainTextLines(htmlContent);
    print('Lang: $lang, Lines: ${lines.length}');
    writeLinesToFile(lines, 'test_output_52024AA0001_$lang.txt');
  }
}

void testDumpsMultipleLangsCelex(var celex) async {
  for (var lang in langsEU) {
    var htmlContent = await loadHtmtFromCelex(
      celex,
      lang,
    ); //load html file from disk
    var lines = extractPlainTextLines(htmlContent);
    print('$celex fetchedang: $lang, Lines: ${lines.length}');
    if (lines.isNotEmpty) {
      writeLinesToFile(lines, 'test_output_${celex}_$lang-${lines.length}.txt');
    }
  }
}

const String kClassDelimiter = '#@#';

// Convert ["some text#@#class-a", "other text#@#class-b"] -> [["some text","class-a"], ["other text","class-b"]]
List<List<String>> splitTextAndClass(List<String> taggedLines) {
  final out = <List<String>>[];
  for (final line in taggedLines) {
    final idx = line.lastIndexOf(kClassDelimiter);
    if (idx >= 0) {
      final text = line.substring(0, idx).trim();
      final cls = line.substring(idx + kClassDelimiter.length).trim();
      if (text.isNotEmpty) out.add([text, cls.isEmpty ? 'unknown' : cls]);
    } else {
      final t = line.trim();
      if (t.isNotEmpty)
        out.add([t, 'unknown']); // fallback if delimiter missing
    }
  }
  return out;
}

Future<List<List<String>>> retrieveCelexForLang(var celex, var lang) async {
  final doc = await loadHtmtFromCelex(celex, lang);
  final lines = extractPlainTextLines(doc); // lines with "...#@#class"
  final pairs = splitTextAndClass(lines);
  print("Lang: $lang, Pairs: ${pairs.length}");
  return pairs;
}

Future<Map<String, List<List<String>>>> createUploadArrayFromCelex(
  String celex,
  dynamic langs,
) async {
  try {
    final Iterable<String> languages =
        (langs is String) ? [langs] : (langs as Iterable).cast<String>();

    final entries = await Future.wait(
      languages.map((lang) async {
        final pairs = await retrieveCelexForLang(celex, lang);
        return MapEntry(lang, pairs); // lang -> [[text, class], ...]
      }),
    );

    return Map<String, List<List<String>>>.fromEntries(entries);
  } catch (e, st) {
    debugPrint('createUploadArrayFromCelex error: $e');
    debugPrintStack(stackTrace: st);
    rethrow;
  }
}

Future<void> testCreateUploadArray() async {
  final result = await createUploadArrayFromCelex('52024AA0001', [
    'EN',
    'SK',
    'ES',
  ]);
  debugPrint(
    result.entries.map((e) => '${e.key}:${e.value.length}').join(', '),
  );
}

// Debug: print a compact DOM tree (tags and short text nodes)
void dumpDom(dom.Node node, {int depth = 0, int maxText = 30}) {
  final indent = '  ' * depth;
  if (node is dom.Element) {
    final cls = node.classes.isNotEmpty ? ' .${node.classes.join('.')}' : '';
    print('$indent<${node.localName}$cls>');
    for (final c in node.nodes) {
      dumpDom(c, depth: depth + 1, maxText: maxText);
    }
  } else if (node is dom.Text) {
    final t = node.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.isNotEmpty) {
      print(
        '$indent"text: ${t.length > maxText ? t.substring(0, maxText) + '…' : t}"',
      );
    }
  }
}

// Extract plain-text lines in DOM order:
// - No tags in output
// - No double-counting (we only read text nodes)
// - Lines split at common block elements and <br>
/*List<String> extractPlainTextLines(String html) {
  final doc = html_parser.parse(html);

  // Treat these as block boundaries (start/end a line). Include all div to be universal.
  const blockTags = {
    'p',
    'li',
    'td',
    'th',
    'tr',
    'thead',
    'tbody',
    'tfoot',
    'table',
    'section',
    'article',
    'aside',
    'nav',
    'header',
    'footer',
    'main',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'blockquote',
    'pre',
    'address',
    'figure',
    'figcaption',
    'div',
  };

  final lines = <String>[];
  final buf = StringBuffer();

  void flush() {
    final s = buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.isNotEmpty) lines.add(s);
    buf.clear();
  }

  void walk(dom.Node n, {bool inPre = false}) {
    if (n is dom.Text) {
      // Append text; normalize later on flush (keeps order, no duplicates).
      buf.write(n.text);
      return;
    }
    if (n is! dom.Element) return;

    final tag = n.localName;
    if (tag == 'script' || tag == 'style' || tag == 'template') return;

    if (tag == 'br') {
      flush();
      return;
    }

    final isBlock = blockTags.contains(tag);
    if (isBlock) flush(); // end previous line before a block

    final nextInPre = inPre || tag == 'pre';
    for (final c in n.nodes) {
      walk(c, inPre: nextInPre);
    }

    if (isBlock) flush(); // end the block as its own line
  }

  final body = doc.body ?? doc.documentElement;
  if (body != null) walk(body);
  return lines;
}
*/
// Example usage (e.g., inside a test/debug method)
void demoDomAndLines(String sampleHtml) {
  final doc = html_parser.parse(sampleHtml);
  print('--- DOM dump ---');
  final root = doc.body ?? doc.documentElement;
  if (root != null) {
    dumpDom(root);
  } else {
    print('No document root to dump.');
  }
  print('--- Plain text lines ---');
  final lines = extractPlainTextLines(sampleHtml);
  for (var i = 0; i < lines.length; i++) {
    print('[$i] ${lines[i]}');
  }
  writeLinesToFile(lines, 'test_output.txt');
}
// ...existing code...

void fetchsparql() async {
  final lines = await fetchSectorXCelexTitles(6, 2024);
  for (final line in lines) {
    print("Celex fetched: ${line.split('\t')[0]}");
    testDumpsMultipleLangsCelex(line.split('\t')[0]);
  }
  print('Total lines fetched: ${lines.length}');
}
