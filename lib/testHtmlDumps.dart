// ...existing code...

import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:LegisTracerEU/processDOM.dart';
import 'package:LegisTracerEU/preparehtml.dart';
import 'package:LegisTracerEU/file_handling.dart';
import 'package:LegisTracerEU/logger.dart';
import 'package:LegisTracerEU/sparql.dart';
import 'package:LegisTracerEU/harvest_progress.dart';
import 'package:LegisTracerEU/opensearch.dart';
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
  Duration base = const Duration(seconds: 1),
  Duration cap = const Duration(seconds: 4),
}) {
  final r = Random();
  final ms = min(cap.inMilliseconds, base.inMilliseconds * (1 << attempt));
  return Duration(milliseconds: r.nextInt(ms + 1)); // 0..ms
}

Future<List<List<String>>> retrieveCelexForLang(
  var link,
  var lang,
  String celex,
  int pointer,
) async {
  var attempt = 0;
  while (true) {
    try {
      if (attempt > 0) {
        print(
          'CELLAR DEBUG [$pointer]: 🔄 RETRY #$attempt: Attempting to download $celex/$lang',
        );
      }

      final doc = await loadHtmtFromCellar(link, lang);
      final lines = extractPlainTextLines(doc);
      final pairs = splitTextAndClass(lines);

      if (attempt > 0) {
        print(
          'CELLAR DEBUG [$pointer]: ✅ RETRY SUCCESS: $celex/$lang downloaded after $attempt retries, Pairs: ${pairs.length}',
        );
      } else {
        print(
          "CELLAR DEBUG [$pointer]: ✅ SUCCESS: $celex/$lang, Pairs: ${pairs.length}",
        );
      }

      if (extractedCelex.isNotEmpty) {
        extractedCelex[extractedCelex.length - 1] += " $lang ${pairs.length}";
      } else {
        extractedCelex.add("$lang: ${pairs.length}");
      }

      if (pairs.length < 5) {
        print(
          'CELLAR DEBUG [$pointer]: ⚠️  Warning: Very few lines (${pairs.length}) for $celex/$lang - may need HTML format instead of XHTML',
        );
        if (!failedCelex.contains(celex)) {
          failedCelex.add(celex);
        }
      }

      return pairs;
    } catch (e) {
      final msg = e.toString();

      if (extractedCelex.isNotEmpty) {
        extractedCelex[extractedCelex.length - 1] += "  $lang: ERR";
      }

      final isThrottle =
          msg.contains('403') ||
          msg.contains('429') ||
          msg.contains('202') ||
          msg.contains('500') ||
          msg.contains('504') ||
          msg.contains('Connection pool shut down') ||
          msg.contains('x-amzn-waf-action') ||
          msg.contains('CloudFront');

      if (!isThrottle || attempt >= 4) {
        print(
          'CELLAR DEBUG [$pointer]: ❌ FAILED PERMANENTLY: $celex/$lang after $attempt attempts',
        );
        print(
          'CELLAR DEBUG [$pointer]:    Error: ${msg.length > 200 ? msg.substring(0, 200) + "..." : msg}',
        );
        rethrow;
      }

      attempt++;
      final wait = _backoffWithJitter(attempt);
      print(
        'CELLAR DEBUG [$pointer]: ⏳ RETRY SCHEDULED: $celex/$lang - Attempt $attempt of 3 will start in ${wait.inSeconds}s (Server error detected)',
      );
      await Future.delayed(wait);
    }
  }
}

List failedCelex = [];

Future<Map<String, List<List<String>>>> createUploadArrayFromMap(
  String celex,
  Map<String, String> langLinks, // lang -> URL
  LogManager logger,
  int pointer,
) async {
  final out = <String, List<List<String>>>{};
  final failed = <String>[];
  //TODO maximum concurrent langs for download from cellar
  const maxConcurrent = 25; // Reduced to 2 to prevent pool overload
  final langs = langLinks.keys.toList();
  var idx = 0;
  var hasError = false;

  Future<void> worker() async {
    while (true) {
      final i = idx++;
      if (i >= langs.length) break;

      final lang = langs[i];
      final url = langLinks[lang]!;

      // If previous request had error, wait to let connection pool recover
      if (hasError) {
        await Future.delayed(Duration(seconds: 3));
        hasError = false;
      }

      try {
        final pairs = await retrieveCelexForLang(url, lang, celex, pointer);
        out[lang] = pairs;
      } catch (e) {
        final msg = 'Harvest error for $celex/$lang from $url: $e';
        print(msg);
        logger.log(msg);
        failed.add(lang);
        if (!failedCelex.contains(celex)) {
          failedCelex.add(celex);
        }
        print('Harvest Added to failedCelex: $celex');
        hasError = true;
        // Give connection pool time to recover after error
        await Future.delayed(Duration(seconds: 5));
      }
    }
  }

  await Future.wait(List.generate(maxConcurrent, (_) => worker()));

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
  int pointer,
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
        final pairs = await retrieveCelexForLang(celex, lang, celex, pointer);
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
  int pointer,
) async {
  final Iterable<String> languages =
      (langs is String) ? [langs] : (langs as Iterable).cast<String>();

  final list = languages.toList();
  final out = <String, List<List<String>>>{};

  print('Harvest sequential languages: $list...');

  for (final lang in list) {
    try {
      final pairs = await retrieveCelexForLang(celex, lang, celex, pointer);
      //print("Harvest Fetched Lang: $lang, Pairs: $pairs");
      out[lang] = pairs;
      print("Harvest Lang: $lang, Pairs: ${pairs.length}");
      //  await Future.delayed(const Duration(milliseconds: 400)); //wait removed to check if needed
    } catch (e) {
      print('Error fetching $celex/$lang: $e');
      rethrow;
    }
  }

  return out;
}

Future<void> testCreateUploadArray() async {
  final result = await createUploadArrayFromCelex(
    '52024AA0001',
    ['EN', 'SK', 'ES'],
    false,
    0,
  );
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

/// New harvest function with progress tracking
/// Returns the HarvestSession for UI integration
Future<HarvestSession> uploadTestSparqlSectorYearWithProgress(
  int sector,
  int year,
  String indexName, {
  int startPointer = 0,
  Function(HarvestSession)? onProgressUpdate,
  Function(String sessionId)? onSessionCreated,
  bool skipExisting = true,
}) async {
  // Create session ID
  final timestamp = DateTime.now().toIso8601String().replaceAll(
    RegExp(r'[:.\ ]'),
    '-',
  );
  final sessionId = 'sector${sector}_${year}_$timestamp';

  // Fetch download links
  final downloadLinks = await fetchSectorXCellarLinksNumber(sector, year);
  final celexIds = downloadLinks.keys.toList();

  // Create session
  final session = HarvestSession(
    sessionId: sessionId,
    indexName: indexName,
    sector: sector,
    year: year,
    celexOrder: celexIds,
    currentPointer: startPointer,
  );

  // Initialize progress for all documents
  for (final celex in celexIds) {
    final langMap = downloadLinks[celex]!;
    final langs = langMap.keys.toList();
    session.documents[celex] = CelexProgress(
      celex: celex,
      languages: {for (var lang in langs) lang: LangStatus.pending},
      downloadUrls: Map<String, String>.from(
        langMap,
      ), // Store the download URLs
    );
  }

  await session.save();

  // Notify that session has been created and saved
  onSessionCreated?.call(sessionId);

  // Logging setup
  final loggerUrl = LogManager(
    fileName: 'logs/${fileSafeStamp}_${indexName}_URLs.log',
  );
  loggerUrl.log(
    'Cellar Upload for sector $sector, year $year, total celexes: ${downloadLinks.length}, resumeFrom: $startPointer',
  );

  final logger = LogManager(fileName: 'logs/${fileSafeStamp}_$indexName.log');
  logger.log('Cellar Upload with progress tracking. SessionID: $sessionId');

  // Main harvest loop
  for (var i = startPointer; i < celexIds.length; i++) {
    final pointer = i + 1;
    final celex = celexIds[i];
    final langMapForCelex = downloadLinks[celex]!;
    final progress = session.documents[celex]!;

    // Skip if already completed in this session (resume scenario)
    if (progress.isCompleted) {
      print('⏭️ Skipping $celex (already processed in this session)');
      session.currentPointer = i;
      await session.save();
      onProgressUpdate?.call(session);
      continue;
    }

    progress.startedAt = DateTime.now();
    session.currentPointer = i;

    // Check if exists in index (deduplication across sessions)
    if (skipExisting) {
      final exists = await celexExistsInIndex(indexName, celex);
      if (exists) {
        print('⏭️ Skipping $celex (already exists in index)');
        for (final lang in progress.languages.keys) {
          progress.languages[lang] = LangStatus.skipped;
        }
        progress.completedAt = DateTime.now();
        await session.save();
        onProgressUpdate?.call(session);
        continue;
      }
    }

    print('Harvesting $pointer/${celexIds.length} — $celex');

    try {
      // Mark all languages as downloading
      for (final lang in langMapForCelex.keys) {
        progress.languages[lang] = LangStatus.downloading;
      }
      onProgressUpdate?.call(session);

      // Download all languages concurrently for speed
      final allUploadData = await createUploadArrayFromMap(
        celex,
        langMapForCelex, // Pass entire language map for concurrent download
        logger,
        pointer,
      );

      // Update unit counts and mark as parsing
      for (final lang in allUploadData.keys) {
        final units = allUploadData[lang]?.length ?? 0;
        progress.unitCounts[lang] = units;
        progress.languages[lang] = LangStatus.parsing;
      }

      // Mark failed languages
      for (final lang in langMapForCelex.keys) {
        if (!allUploadData.containsKey(lang)) {
          progress.languages[lang] = LangStatus.failed;
          progress.errors[lang] = 'Download failed';
        }
      }
      onProgressUpdate?.call(session);

      // Step 4: Upload all languages to server
      if (allUploadData.isNotEmpty) {
        // Mark all successful downloads as uploading
        for (final lang in allUploadData.keys) {
          progress.languages[lang] = LangStatus.uploading;
        }
        onProgressUpdate?.call(session);

        final statusCode = await processMultilingualMap(
          allUploadData,
          indexName,
          celex,
          pointer.toString(),
          false, // simulate
          false, // debug
          false,
          i,
          logger,
        );

        // Store HTTP status once for the entire document
        progress.httpStatus = statusCode;

        // Mark languages based on HTTP status code
        for (final lang in allUploadData.keys) {
          if (statusCode == 200) {
            progress.languages[lang] = LangStatus.completed;
          } else {
            progress.languages[lang] = LangStatus.failed;
            progress.errors[lang] = 'Upload failed with HTTP $statusCode';
          }
        }
      }

      progress.completedAt = DateTime.now();
    } catch (e) {
      print('❌ Failed to harvest $celex: $e');
      for (final lang in langMapForCelex.keys) {
        if (progress.languages[lang] != LangStatus.failed) {
          progress.languages[lang] = LangStatus.failed;
          progress.errors[lang] = e.toString();
        }
      }
      progress.completedAt = DateTime.now();
      logger.log('Failed to harvest $celex at index $i: $e');
    }

    await session.save();
    onProgressUpdate?.call(session);
  }

  session.completedAt = DateTime.now();
  await session.save();
  onProgressUpdate?.call(session);

  return session;
}

//TODO upload a certain celex sector from a certain year
//TODO tie with the table under Data Process
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
        logger,
        pointer,
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

    // Light pacing between CELEXes REMOVED
    //  await Future.delayed(Duration(milliseconds: 800 + Random().nextInt(600)));
    // print('Harvest pointer: $pointer, Waiting a bit to avoid throttling...');
  }
}

Future uploadSparqlForCelex(
  String celex,

  String indexName,
  String format, [
  int startPointer = 0,
  bool debugMode = false,
  bool simulateUpload = false,
]) async {
  //final lines = await fetchSectorXCelexTitles(sector, year);

  final htmlDownloadLinks = await fetchLinksForCelex(celex, "html");

  final xhtmlDownloadLinks = await fetchLinksForCelex(celex, "xhtml");
  var downloadLinks = <String, Map<String, String>>{};

  final htmlCount = htmlDownloadLinks[celex]?.length ?? 0;
  final xhtmlCount = xhtmlDownloadLinks[celex]?.length ?? 0;
  print(
    'Using links for $celex, html count: $htmlCount, xhtml count: $xhtmlCount',
  );
  if (htmlCount >= xhtmlCount) {
    downloadLinks = htmlDownloadLinks;
  } else {
    downloadLinks = xhtmlDownloadLinks;
  }

  /* 
  final downloadLinks = await fetchLinksForCelex(
    celex,
    format,
  ); //this reads a map of celex->lang->links
*/

  if (downloadLinks.isEmpty || xhtmlCount == 0 && htmlCount == 0) {
    print('No download links found for $celex in either format.');
    return;
  }

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
        logger,
        pointer,
      );

      processMultilingualMap(
        uploadData,
        indexName,
        celex,
        pointer.toString(), //dirID = pointer
        simulateUpload, //simulate
        debugMode, // debug
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

    // Light pacing between CELEXes REMOVED
    //  await Future.delayed(Duration(milliseconds: 800 + Random().nextInt(600)));
    //   print('Harvest pointer: $pointer, Waiting a bit to avoid throttling...');
  }
}

/// Enhanced version with language-level progress callback
Future<Map<String, int>> uploadSparqlForCelexWithProgress(
  String celex,
  String indexName,
  String format,
  void Function(String lang, LangStatus status, int unitCount)? onLangProgress,
  void Function(int httpStatus)? onHttpStatus, [
  int startPointer = 0,
  bool debugMode = false,
  bool simulateUpload = false,
  List<String>? filterLanguages, // null = all languages, or list of language codes
]) async {
  final langUnitCounts = <String, int>{};
  final langHttpStatus = <String, int>{}; // Track HTTP status per language

  final htmlDownloadLinks = await fetchLinksForCelex(celex, "html");
  final xhtmlDownloadLinks = await fetchLinksForCelex(celex, "xhtml");
  var downloadLinks = <String, Map<String, String>>{};

  final htmlCount = htmlDownloadLinks[celex]?.length ?? 0;
  final xhtmlCount = xhtmlDownloadLinks[celex]?.length ?? 0;

  if (htmlCount >= xhtmlCount) {
    downloadLinks = htmlDownloadLinks;
  } else {
    downloadLinks = xhtmlDownloadLinks;
  }

  if (downloadLinks.isEmpty || (xhtmlCount == 0 && htmlCount == 0)) {
    print('No download links found for $celex in either format.');
    return langUnitCounts;
  }

  final logger = LogManager(fileName: 'logs/${fileSafeStamp}_$indexName.log');
  final celexIds = downloadLinks.keys.toList();

  for (var i = startPointer; i < downloadLinks.length; i++) {
    final pointer = i + 1;
    final currentCelex = celexIds[i];
    final langMapForCelex = downloadLinks[currentCelex]!;

    print('Harvesting $pointer/${downloadLinks.length} — $currentCelex');

    try {
      // Process each language individually for real-time progress
      final allUploadData = <String, List<List<String>>>{};

      // Filter languages if requested
      final langsToProcess = filterLanguages != null
          ? langMapForCelex.keys.where(
              (lang) => filterLanguages.any(
                (filter) => filter.toUpperCase() == lang.toUpperCase(),
              ),
            ).toList()
          : langMapForCelex.keys.toList();

      if (filterLanguages != null && langsToProcess.isEmpty) {
        print('⚠️ No matching languages found for $currentCelex. Filter: $filterLanguages, Available: ${langMapForCelex.keys}');
      }

      for (final lang in langsToProcess) {
        try {
          // Step 1: Notify downloading
          onLangProgress?.call(lang, LangStatus.downloading, 0);

          // Step 2: Download this language's content
          final singleLangMap = {lang: langMapForCelex[lang]!};
          final langUploadData = await createUploadArrayFromMap(
            currentCelex,
            singleLangMap,
            logger,
            pointer,
          );

          // Step 3: Notify parsing/ready (use uploading status with unit count)
          final units = langUploadData[lang]?.length ?? 0;
          langUnitCounts[lang] = units;
          onLangProgress?.call(lang, LangStatus.parsing, units);

          // Store for batch upload
          allUploadData.addAll(langUploadData);
        } catch (e) {
          print('Failed to download $lang for $currentCelex: $e');
          onLangProgress?.call(lang, LangStatus.failed, 0);
        }
      }

      // Step 4: Upload all languages to server
      if (allUploadData.isNotEmpty) {
        // Mark all as uploading
        for (final lang in allUploadData.keys) {
          final units = langUnitCounts[lang] ?? 0;
          onLangProgress?.call(lang, LangStatus.uploading, units);
        }

        final httpStatusCode = await processMultilingualMap(
          allUploadData,
          indexName,
          currentCelex,
          pointer.toString(),
          simulateUpload,
          debugMode,
          false,
          i,
          logger,
        );

        // Report HTTP status once for the entire document
        onHttpStatus?.call(httpStatusCode);

        // Mark all as completed or failed based on HTTP status
        for (final lang in allUploadData.keys) {
          final units = langUnitCounts[lang] ?? 0;
          langHttpStatus[lang] = httpStatusCode;
          if (httpStatusCode == 200) {
            onLangProgress?.call(lang, LangStatus.completed, units);
          } else {
            onLangProgress?.call(lang, LangStatus.failed, units);
          }
        }
      }
    } on Exception catch (e) {
      print('Failed to harvest $currentCelex: $e');
      logger.log('Failed to harvest $currentCelex: (resume at index $i)\n$e');

      // Mark languages as failed
      for (final lang in langMapForCelex.keys) {
        onLangProgress?.call(lang, LangStatus.failed, 0);
      }
      rethrow;
    }
  }

  return langUnitCounts;
}

//TODO this is a manual URL upload
Future uploadURLs(String indexName, [int startPointer = 0]) async {
  //final lines = await fetchSectorXCelexTitles(sector, year);
  final downloadLinks = <String, Map<String, String>>{
    "FISMA01301": {
      "EN":
          "https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=PI_COM:C(2025)6800",
      "SK":
          "https://eur-lex.europa.eu/legal-content/SK/TXT/HTML/?uri=PI_COM:C(2025)6800",
    },
  };
  //this reads a map of celex->lang->links

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
    'manual Upload for url $downloadLinks,  ${downloadLinks.length}, resumeFrom: $startPointer, the following URLs will be processed: ${const JsonEncoder.withIndent('  ').convert(downloadLinks)}',
  );

  final logger = LogManager(fileName: 'logs/${fileSafeStamp}_$indexName.log');
  logger.log(
    'manual Upload for url $downloadLinks, total links: ${downloadLinks.length}, resumeFrom: $startPointer',
  );
  print(
    'Starting Harvest  for url $downloadLinks, total links: ${downloadLinks.length}, resumeFrom: $startPointer',
  );
  //
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
        logger,
        pointer,
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
    //    await Future.delayed(Duration(milliseconds: 800 + Random().nextInt(600)));
    //   print('Harvest pointer: $pointer, Waiting a bit to avoid throttling...');
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
