// ...existing code...

import 'dart:math';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:eurolex/processDOM.dart';
import 'package:eurolex/preparehtml.dart';
import 'package:eurolex/file_handling.dart';
import 'package:eurolex/logger.dart';
import 'package:eurolex/sparql.dart';
import 'package:http/http.dart' as http;
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

Future<List<List<String>>> retrieveCelexForLang(var link, var lang) async {
  var attempt = 0;
  while (true) {
    try {
      final doc = await loadHtmtFromCellar(link, lang);
      final lines = extractPlainTextLines(doc);
      final pairs = splitTextAndClass(lines);
      print("Harvest Lang: $lang, Pairs: ${pairs.length} from $link/n");
      return pairs;
    } catch (e) {
      final msg = e.toString();
      print('Catch triggered, Error harvesting $link/$lang: $msg');
      // Treat CloudFront WAF challenge (202) as throttle too
      final isThrottle =
          msg.contains('403') ||
          msg.contains('429') ||
          msg.contains('202') ||
          msg.contains('x-amzn-waf-action') ||
          msg.contains('CloudFront');
      if (!isThrottle || attempt >= 2) rethrow;
      final wait = _backoffWithJitter(attempt);
      print('harvest Throttle for $link/$lang  Retry in ${wait.inSeconds}s');
      await Future.delayed(wait);
      attempt++;
    }
  }
}

Future<Map<String, List<List<String>>>> createUploadArrayFromMap(
  String celex,
  Map<String, String> langLinks, // lang -> URL
  LogManager logger,
) async {
  final out = <String, List<List<String>>>{};
  final failed = <String>[];

  final futures = <Future<void>>[];
  for (final entry in langLinks.entries) {
    final lang = entry.key;
    final url = entry.value;

    futures.add(() async {
      try {
        final pairs = await retrieveCelexForLang(url, lang);
        out[lang] = pairs;
      } catch (e) {
        final msg = 'Harvest error for $celex/$lang from $url: $e';
        print(msg);
        logger.log(msg);
        // Optionally also log stack trace:
        // logger.log(st.toString());
        failed.add(lang);
      }
    }());
  }

  await Future.wait(futures);

  if (failed.isNotEmpty) {
    logger.log('Failed languages for $celex: ${failed.join(', ')}');
  }
  return out;
}

/*downloading docs one by one 
Future<Map<String, List<List<String>>>> createUploadArrayFromMap(
  Map langLinks,
) async {
  final out = <String, List<List<String>>>{};
  for (var lang in langLinks.keys) {
    final url = langLinks[lang]!;

    final pairs = await retrieveCelexForLang(url, lang);

    out[lang] = pairs;
  }

  return out;
}
*/

Future<Map<String, List<List<String>>>> createUploadArrayFromCelex(
  String celex,
  dynamic langs,
  bool throttle,
) async {
  final Iterable<String> languages =
      (langs is String) ? [langs] : (langs as Iterable).cast<String>();

  const maxConcurrent = 2; // Tune this (2–4 is usually safe)
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
        print("Harvest Worker Lang: $lang, Pairs: ${pairs.length}");
      } catch (e) {
        print('Error fetching $celex/$lang: $e');
        rethrow;
      }
    }
  }

  await Future.wait(List.generate(maxConcurrent, (_) => worker()));
  print('Harvest completed for $celex, total langs fetched: ${out.length}');
  return out;
}

Future<Map<String, List<List<String>>>> createUploadArrayFromCelexSingle(
  String celex,
  dynamic langs,
  bool throttle,
) async {
  final Iterable<String> languages =
      (langs is String) ? [langs] : (langs as Iterable).cast<String>();

  final list = languages.toList();
  final out = <String, List<List<String>>>{};

  print('Harvest sequential languages: $list...');

  for (final lang in list) {
    try {
      final pairs = await retrieveCelexForLang(celex, lang);
      //print("Harvest Fetched Lang: $lang, Pairs: $pairs");
      out[lang] = pairs;
      print("Harvest Lang: $lang, Pairs: ${pairs.length}");
      await Future.delayed(const Duration(milliseconds: 400));
    } catch (e) {
      print('Error fetching $celex/$lang: $e');
      rethrow;
    }
  }

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
//this is main entry point for sparql harvesting and uploading
void uploadTestSparqlSectorYear(
  int sector,
  int year,
  String indexName, [
  int startPointer = 0,
]) async {
  //final lines = await fetchSectorXCelexTitles(sector, year);
  final downloadLinks = await fetchSectorXCellarLinksNumber(
    sector,
    year,
  ); //this reads a map of celex->lang->links

  if (startPointer < 0 ||
      startPointer >=
          downloadLinks.length) //this give number of celexes to process
  {
    print(
      'Invalid startPointer=$startPointer (Celexes: ${downloadLinks.length}). Starting from 0.',
    );
    startPointer = 0;
  }

  final loggerUrl = LogManager(
    fileName: 'logs/${fileSafeStamp}_${indexName}_URLs.log',
  );
  loggerUrl.log(
    'Cellar Upload for sector $sector, year $year, total celexes: ${downloadLinks.length}, resumeFrom: $startPointer, the following URLs will be processed: ${const JsonEncoder.withIndent('  ').convert(downloadLinks)}',
  );

  final logger = LogManager(fileName: 'logs/${fileSafeStamp}_$indexName.log');
  logger.log(
    'Cellar Upload for sector $sector, year $year, total celexes: ${downloadLinks.length}, resumeFrom: $startPointer',
  );
  print(
    'Starting Harvest for sector $sector, year $year, total celexes: ${downloadLinks.length}, resumeFrom: $startPointer',
  );

  final celexIds =
      downloadLinks.keys
          .toList(); //create list of celex ids to access map by index

  for (var i = startPointer; i < downloadLinks.length; i++) {
    final pointer = i + 1; // human-friendly (1-based) progress
    final celex = celexIds[i];
    final langMapForCelex =
        downloadLinks[celex]!; //get lang->links map for this celex

    print(
      'Harvesting $pointer/${downloadLinks.length} — $celex, langmap: ${langMapForCelex.keys.toList()}',
    );

    try {
      final uploadData = await createUploadArrayFromMap(
        celex,
        langMapForCelex,
        logger, // throttle
      );

      processMultilingualMap(
        uploadData,
        indexName,
        celex,
        pointer.toString(), //dirID = pointer
        false, //simulate
        false, // debug
        false,
        i,
        logger, //index
      );
      /*
      if (pointer % 10 == 0) {
        print(
          'Harvest pointer: $pointer, Waiting 5 seconds after 10 items to avoid throttling...',
        );
        await Future.delayed(const Duration(seconds: 5));
      }

      if (pointer % 30 == 0) {
        print(
          'Harvest pointer: $pointer, Waiting 30 seconds after 30 items to avoid throttling...',
        );
        await Future.delayed(const Duration(seconds: 30));
      }

      */
    } on Exception catch (e) {
      print(
        'Failed to harvest $celex: $e at pointer: $pointer (index $i) (exception $e)',
      );
      logger.log('Failed to harvest $celex: (resume at index $i)\n$e');
      return;
      // Optionally stop here to resume later from this pointer:
      // return;
    }

    // Light pacing between CELEXes
    await Future.delayed(Duration(milliseconds: 800 + Random().nextInt(600)));
    print('Harvest pointer: $pointer, Waiting a bit to avoid throttling...');
  }
}

Future uploadSparqlForCelex(
  String celex,

  String indexName, [
  int startPointer = 0,
]) async {
  //final lines = await fetchSectorXCelexTitles(sector, year);
  final downloadLinks = await fetchLinksForCelex(
    celex,
  ); //this reads a map of celex->lang->links

  if (startPointer < 0 ||
      startPointer >=
          downloadLinks.length) //this give number of celexes to process
  {
    print(
      'Invalid startPointer=$startPointer (Celexes: ${downloadLinks.length}). Starting from 0.',
    );
    startPointer = 0;
  }

  final loggerUrl = LogManager(
    fileName: 'logs/${fileSafeStamp}_${indexName}_URLs.log',
  );
  loggerUrl.log(
    'Cellar Upload for celex $celex,  ${downloadLinks.length}, resumeFrom: $startPointer, the following URLs will be processed: ${const JsonEncoder.withIndent('  ').convert(downloadLinks)}',
  );

  final logger = LogManager(fileName: 'logs/${fileSafeStamp}_$indexName.log');
  logger.log(
    'Cellar Upload for celex $celex, total links: ${downloadLinks.length}, resumeFrom: $startPointer',
  );
  print(
    'Starting Harvest for celex $celex, total links: ${downloadLinks.length}, resumeFrom: $startPointer',
  );

  final celexIds =
      downloadLinks.keys
          .toList(); //create list of celex ids to access map by index

  for (var i = startPointer; i < downloadLinks.length; i++) {
    final pointer = i + 1; // human-friendly (1-based) progress
    final celex = celexIds[i];
    final langMapForCelex =
        downloadLinks[celex]!; //get lang->links map for this celex

    print(
      'Harvesting $pointer/${downloadLinks.length} — $celex, langmap: ${langMapForCelex.keys.toList()}',
    );

    try {
      final uploadData = await createUploadArrayFromMap(
        celex,
        langMapForCelex,
        logger, // throttle
      );

      processMultilingualMap(
        uploadData,
        indexName,
        celex,
        pointer.toString(), //dirID = pointer
        false, //simulate
        false, // debug
        false,
        i,
        logger, //index
      );
      /*
      if (pointer % 10 == 0) {
        print(
          'Harvest pointer: $pointer, Waiting 5 seconds after 10 items to avoid throttling...',
        );
        await Future.delayed(const Duration(seconds: 5));
      }

      if (pointer % 30 == 0) {
        print(
          'Harvest pointer: $pointer, Waiting 30 seconds after 30 items to avoid throttling...',
        );
        await Future.delayed(const Duration(seconds: 30));
      }

      */
    } on Exception catch (e) {
      print(
        'Failed to harvest $celex: $e at pointer: $pointer (index $i) (exception $e)',
      );
      logger.log('Failed to harvest $celex: (resume at index $i)\n$e');
      return;
      // Optionally stop here to resume later from this pointer:
      // return;
    }

    // Light pacing between CELEXes
    await Future.delayed(Duration(milliseconds: 800 + Random().nextInt(600)));
    print('Harvest pointer: $pointer, Waiting a bit to avoid throttling...');
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

Future deleteOpenSearchIndex(index) async {
  // String indicesBefore = await getListIndices(server);
  // print('Remaining indices before delete: $indicesBefore');
  final resp = await http.delete(
    Uri.parse('https://search.pts-translation.sk/$index'),
    headers: {'x-api-key': '1234'},
  );

  print('DELETE: ${resp.statusCode}');
  if (resp.statusCode != 200) {
    print('Delete failed ${resp.statusCode}: ${resp.body}');
  }
  // String indicesAfter = await getListIndices(server);
  // print('Remaining indices after delete: $indicesAfter');
}
