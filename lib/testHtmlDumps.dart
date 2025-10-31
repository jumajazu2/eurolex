// ...existing code...
import 'dart:ffi';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:eurolex/processDOM.dart';
import 'package:eurolex/preparehtml.dart';
import 'package:eurolex/file_handling.dart';
import 'package:eurolex/logger.dart';
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

Duration _backoffWithJitter(
  int attempt, {
  Duration base = const Duration(seconds: 5),
  Duration cap = const Duration(minutes: 2),
}) {
  final r = Random();
  final ms = min(cap.inMilliseconds, base.inMilliseconds * (1 << attempt));
  return Duration(milliseconds: r.nextInt(ms + 1)); // 0..ms
}

Future<List<List<String>>> retrieveCelexForLang(var celex, var lang) async {
  var attempt = 0;
  while (true) {
    try {
      final doc = await loadHtmtFromCelex(celex, lang);
      final lines = extractPlainTextLines(doc);
      final pairs = splitTextAndClass(lines);
      print("Lang: $lang, Pairs: ${pairs.length}");
      return pairs;
    } catch (e) {
      final msg = e.toString();
      final isThrottle =
          msg.contains('403') ||
          msg.contains('429') ||
          msg.contains('CloudFront');
      if (!isThrottle || attempt >= 6) rethrow;
      final wait = _backoffWithJitter(attempt);
      print(
        'harvest Throttle for $celex/$lang (${msg.split("\n").first}). Retry in ${wait.inSeconds}s',
      );
      await Future.delayed(wait);
      attempt++;
    }
  }
}

Future<Map<String, List<List<String>>>> createUploadArrayFromCelex(
  String celex,
  dynamic langs,
  bool throttle,
) async {
  final Iterable<String> languages =
      (langs is String) ? [langs] : (langs as Iterable).cast<String>();

  const maxConcurrent = 3; // Tune this (2–4 is usually safe)
  final list = languages.toList();
  final out = <String, List<List<String>>>{};
  var idx = 0;

  print('Harvest worker languages: $list...');

  Future<void> worker() async {
    while (true) {
      final i = idx++;
      if (i >= list.length) break;
      final lang = list[i];
      try {
        final pairs = await retrieveCelexForLang(celex, lang);
        out[lang] = pairs;
        print("Lang: $lang, Pairs: ${pairs.length}");
      } catch (e) {
        print('Error fetching $celex/$lang: $e');
      }
    }
  }

  await Future.wait(List.generate(maxConcurrent, (_) => worker()));
  return out;
}

Future<void> testCreateUploadArray() async {
  final result = await createUploadArrayFromCelex('52024AA0001', [
    'EN',
    'SK',
    'ES',
  ], false);
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
  final lines = await fetchSectorXCelexTitles(6, 2020);
  for (final line in lines) {
    print("Celex fetched: ${line.split('\t')[0]}");
    testDumpsMultipleLangsCelex(line.split('\t')[0]);
  }
  print('Total lines fetched: ${lines.length}, lines: $lines');
}

//test to upload a certain celex sector from a certain year
void uploadTestSparqlSectorYear(int sector, int year) async {
  final lines = await fetchSectorXCelexTitles(sector, year);
  var pointer = 0;
  final logger = LogManager(fileName: '${fileSafeStamp}_sparql.log');
  logger.log(
    'Upload test for sector $sector, year $year, total celexes: ${lines.length}\n$lines',
  );
  print(
    'Starting Harvest for sector $sector, year $year, total celexes: ${lines.length}\n$lines',
  );
  for (final line in lines) {
    final celex = line.split('\t')[0];
    final actName = line.split('\t')[1];
    print(
      'Harvesting ${++pointer}/${lines.length} — $celex, ${actName.substring(0, actName.length > 50 ? 50 : actName.length)}',
    );

    final uploadData = await createUploadArrayFromCelex(
      celex,
      langsEU,
      false, //  throttle
    );
    processMultilingualMap(
      uploadData,
      "eurolex_sparql8",
      celex,
      "N/A",
      false,
      true,
      false,
      false,
    );

    // Cooldown every 100 items (match message with actual wait)
    if (pointer % 100 == 0) {
      print('Waiting 2 seconds to avoid throttling...');
      await Future.delayed(const Duration(seconds: 2));
    }

    // Light pacing between CELEXes too
    // await Future.delayed(Duration(milliseconds: 800 + Random().nextInt(600)));
  }
}

void numberSparql(sector, year) async {
  final lines = await fetchSectorXCelexTitles(sector, year);
  print('Total lines fetched: ${lines.length}');
}

void checkYearsSparql(sector, startYear, endYear) async {
  for (var year = startYear; year <= endYear; year++) {
    final lines = await fetchSectorXCelexTitles(sector, year);
    print('Year: $year, sector: $sector, Total lines fetched: ${lines.length}');

    LogManager(
      fileName:
          '${fileSafeStamp}_sparql_years_Sector$sector-$startYear-$endYear.log',
    ).log('Year: $year, sector: $sector, Total lines fetched: ${lines.length}');
  }
}

void sectorsSparql() async {
  for (var sector = 0; sector <= 10; sector++) {
    checkYearsSparql(sector, 1990, 2025);
  }
}
