//import 'dart:ffi';
import 'package:LegisTracerEU/main.dart'; // ensu re showSubscrip tionDialog is visible
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:LegisTracerEU/main.dart' show deviceId;
import 'package:html/parser.dart' as html_parser;
import 'dart:convert';
import 'package:LegisTracerEU/logger.dart';

import 'package:html/dom.dart' as dom;
import 'package:LegisTracerEU/preparehtml.dart';
import 'dart:async'; // for TimeoutException
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

var dirPointer = 0; // Pointer for directory processing
List<String> langsEU = [
  "BG",
  "CS",
  "DA",
  "DE",
  "EL",
  "EN",
  "ES",
  "ET",
  "FI",
  "FR",
  "HR",
  "HU",
  "IT",
  "LT",
  "LV",
  "MT",
  "NL",
  "PL",
  "PT",
  "RO",
  "SK",
  "SL",
  "SV",
  "GA",
];

class DomProcessor {
  // Function to parse HTML content and extract text
  static String parseHtmlString(String htmlString) {
    var document = html_parser.parse(htmlString);
    return document.body?.text ?? '';
  }

  // Add more DOM processing methods here as needed
}

final logger = LogManager();

List<Map<String, dynamic>> extractParagraphs(
  String htmlEN,
  String htmlSK,
  String htmlCZ,
  String metadata,
  String dirID,
  String indexName, // Directory ID for logging purposes
) {
  //check if files names match expect lang

  if (htmlEN.isEmpty || htmlSK.isEmpty || htmlCZ.isEmpty) {
    print('One or more input strings are empty.');
    final logger = LogManager();
    logger.log(
      "$dirPointer, $dirID, NotProcessed, One or more input strings are empty",
    );
    return [];
  }

  if (metadata.isNotEmpty) {
    String metadataRDF = metadata;
    // print('Metadata RDF: ${metadataRDF.substring(0, 50)} ...');

    //getmetadata()
  }

  String htmlENFileName = htmlEN.split('@@@')[0].trim();
  String htmlSKFileName = htmlSK.split('@@@')[0].trim();
  String htmlCZFileName = htmlCZ.split('@@@')[0].trim();
  String metadataFileName = metadata.split('@@@')[0].trim();

  bool namesNotMatched = false;
  bool paragraphsNotMatched = false;

  print(
    'EN File Name: $htmlENFileName SK File Name: $htmlSKFileName CZ File Name: $htmlCZFileName Metadata File Name: $metadataFileName',
  );

  /* logger.log(
    "$DateTime()  Process started for files: $htmlENFileName, $htmlSKFileName, $htmlCZFileName",
  );
*/
  String htmlSKFileNameMod =
      htmlSKFileName.substring(0, 8) + htmlSKFileName.split('.')[1].trim();
  String htmlENFileNameMod =
      htmlENFileName.substring(0, 8) + htmlENFileName.split('.')[1].trim();
  String htmlCZFileNameMod =
      htmlCZFileName.substring(0, 8) + htmlCZFileName.split('.')[1].trim();

  String celex = getmetadata(metadata);
  if (celex.contains(".")) {
    celex = celex.split(".").first;
  }
  print('$dirPointer, $dirID, $htmlENFileName, decoded CELEX: $celex');

  if (htmlSKFileNameMod != htmlENFileNameMod ||
      htmlSKFileNameMod != htmlCZFileNameMod ||
      htmlENFileNameMod != htmlCZFileNameMod) {
    print('File names do not match!');
    final logger = LogManager();
    logger.log(
      "$dirPointer, $dirID, Processed, Celex: $celex, File names do not match-set warning flag namesNotMatched",
    );
    namesNotMatched = true;
  }

  print(
    "filenames after lang removed, matched>>> $htmlENFileNameMod, $htmlSKFileNameMod, $htmlCZFileNameMod",
  );
  /*
  var documentEN = html_parser.parse(htmlEN);
  var documentSK = html_parser.parse(htmlSK);
  var documentCZ = html_parser.parse(htmlCZ);
*/
  var documentEN = extractPlainTextLines(htmlEN);
  var documentSK = extractPlainTextLines(htmlSK);
  var documentCZ = extractPlainTextLines(htmlCZ);
  var paragraphsEN =
      documentEN; //this extracts all <p> elements, but we also need to extract bulleted lists which have a different tag
  var paragraphsSK = documentSK;
  var paragraphsCZ = documentCZ;
  print(
    'LENGTHS EN: ${paragraphsEN.length}, SK: ${paragraphsSK.length}, CZ: ${paragraphsCZ.length}',
  );
  /*
  var dateElements = documentEN.getElementsByClassName('oj-hd-date');



  String date =
      dateElements.isNotEmpty
          ? (dateElements.first.nodes.isNotEmpty &&
                  dateElements.first.nodes.first.nodeType == 3
              ? dateElements.first.nodes.first.text?.trim() ?? ''
              : dateElements.first.text.trim())
          : 'unknown';

  print('date: $date');
*/
  //check if paragraps in SK and EN are the same length
  String date =
      'N/A'; //date temporarily not extracted// Placeholder for date extraction logic
  if (paragraphsEN.length != paragraphsSK.length) {
    print(
      'Paragraphs in EN and SK do not match in length, files not identical! $dirPointer, $dirID',
    );

    paragraphsNotMatched = true;
  }

  int sequenceID = 0;

  List<Map<String, dynamic>> jsonData = [];

  for (
    var i = 0;
    i < paragraphsEN.length &&
        i < paragraphsSK.length &&
        i < paragraphsCZ.length;
    i++
  ) {
    var enText = paragraphsEN[i].trim().split('#@#')[0];
    var skText = paragraphsSK[i].trim().split('#@#')[0];
    var czText = paragraphsCZ[i].trim().split('#@#')[0];
    print(
      'EN: ${safePrefix(enText, 35)}, SK: ${safePrefix(skText, 35)}, CZ: ${safePrefix(czText, 35)}',
    );

    if (enText.isNotEmpty && skText.isNotEmpty && czText.isNotEmpty) {
      Map<String, dynamic> jsonEntry = {
        "sequence_id": sequenceID++,
        // "date": date,
        "en_text": enText,
        "sk_text": skText,
        "cz_text": czText,
        //"language": {"en": "English", "sk": "Slovak", "cz": "Czech"},
        "celex": celex,
        "dir_id": dirID, // Directory ID for logging purposes
        "filename": htmlENFileName,
        "paragraphsNotMatched": paragraphsNotMatched,
        "namesNotMatched": namesNotMatched,
        "class":
            paragraphsEN[i].split('#@#').length > 1
                ? paragraphsEN[i].split('#@#')[1]
                : 'unknown',
      };
      jsonData.add(jsonEntry);
    }
  }
  jsonOutput = jsonEncode(jsonData);
  openSearchUpload(jsonData, indexName);

  final logger = LogManager(fileName: '${fileSafeStamp}_$indexName.log');
  final status = paragraphsNotMatched ? 'parNotMatched' : 'status_ok';
  final msg =
      '$indexName, $dirPointer, $dirID, Processed, Celex: $celex, '
      '$status, EN $htmlENFileNameMod ${paragraphsEN.length} '
      'SK $htmlSKFileNameMod ${paragraphsSK.length}';

  logger.log(msg);
  //JSOn ready, now turning in into NDJSON + action part
  print("Extract paragraphs uploaded to Open Search>COMPLETED");
  return jsonData;
}

String safePrefix(String s, int n) => s.length <= n ? s : s.substring(0, n);

/*
//Function to parse HTML content as String and return list<Element>
List<dom.Element> parseHtmlContent(String htmlContent) {
  var document = html_parser.parse(htmlContent);
  var paragraphs = document.getElementsByTagName('p');
  return paragraphs;
}
//final List<String> paragraphsText = paragraphs.map((e) => e.text.trim()).toList();

//********************************************************* */
*/
//This is the chosen method for extracting plain text lines from HTML DOM
// ...existing code...
Map<String, String> addDeviceIdHeader([Map<String, String>? headers]) {
  final h = <String, String>{};
  if (headers != null) h.addAll(headers);
  if (deviceId != null && deviceId!.isNotEmpty) h['x-device-id'] = deviceId!;
  return h;
}

List<String> extractPlainTextLines(String html) {
  final doc = html_parser.parse(html);

  // Treat these as block boundaries (start/end a line). Include all div to be universal.
  const blockTags = {
    'p',
    'li',
    'ul',
    'ol',
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
    'dl',
    'dt',
    'dd',
    'hr',
    'div',
  };

  const String delimiter = '#@#';

  final lines = <String>[];
  final buf = StringBuffer();
  final blockStack = <dom.Element>[]; // nearest enclosing block on top

  void flush() {
    final s = buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.isEmpty) {
      buf.clear();
      return;
    }
    // Use the nearest enclosing block's classes; fallback to 'unknown'
    String cls = 'unknown';
    if (blockStack.isNotEmpty) {
      final top = blockStack.last;
      if (top.classes.isNotEmpty) {
        cls = top.classes.join(' ');
      } else {
        final id = top.attributes['id'];
        if (id != null && id.trim().isNotEmpty) {
          cls = '#' + id.trim();
        } else {
          cls = top.localName ?? 'unknown';
        }
      }
    }
    lines.add('$s$delimiter$cls');
    buf.clear();
  }

  void walk(dom.Node n, {bool inPre = false}) {
    if (n is dom.Text) {
      buf.write(n.text);
      return;
    }
    if (n is! dom.Element) return;

    final tag = n.localName;
    if (tag == 'script' || tag == 'style' || tag == 'template') return;

    if (tag == 'br') {
      flush(); // same enclosing class (don’t push/pop)
      return;
    }

    final isBlock = blockTags.contains(tag);
    if (isBlock) flush(); // end previous block before starting a new one

    if (isBlock) blockStack.add(n);

    final nextInPre = inPre || tag == 'pre';
    for (final c in n.nodes) {
      walk(c, inPre: nextInPre);
    }

    if (isBlock) {
      flush(); // end this block line
      blockStack.removeLast();
    }
  }

  final body = doc.body ?? doc.documentElement;
  if (body != null) walk(body);
  return lines;
}
// ...existing code...

/*

List<dom.Element> collectSimple(dom.Document doc) =>
    doc.querySelectorAll('p, td, span, div');

// De-duplicated blocks (skips descendants after capturing p/td/div.list; spans only if not inside those)
List<dom.Element> collectBlocks(dom.Document doc) {
  final out = <dom.Element>[];
  void walk(dom.Element el, {bool inBlock = false}) {
    final name = el.localName;
    final isList = name == 'div';
    final isP = name == 'p';
    final isTd = name == 'td';
    final isSpan = name == 'span';
    final capture = (isList || isP || isTd || (!inBlock && isSpan));
    if (capture) {
      out.add(el);
      if (isList || isP || isTd) {
        for (final c in el.children) {
          walk(c, inBlock: true);
        }
        return;
      }
    }
    for (final c in el.children) {
      walk(c, inBlock: inBlock);
    }
  }

  final body = doc.body;
  if (body != null) walk(body);
  return out;
}

// Text extractor (special handling for div.list)
String elementText(dom.Element e) {
  if (e.localName == 'div' && e.classes.contains('list')) {
    final items =
        e
            .querySelectorAll('li')
            .map((li) => li.text.trim())
            .where((t) => t.isNotEmpty)
            .toList();
    return items.isEmpty ? e.text.trim() : items.join(' • ');
  }
  return e.text.trim();
}

// Quick comparison printout
void compareExtraction(String label, dom.Document doc, {int sample = 10000}) {
  final simple = collectSimple(doc);
  final blocks = collectBlocks(doc);
  print('[$label] simple=${simple.length}, blocks=${blocks.length}');
  print('[$label] simple sample:');
  for (var i = 0; i < simple.length && i < sample; i++) {
    print('  S[$i] ${elementText(simple[i])}');
  }
  print('[$label] blocks sample:');
  for (var i = 0; i < blocks.length && i < sample; i++) {
    print('  B[$i] ${elementText(blocks[i])}');
  }
}

void testExtractionMethods() async {
  var htmlContent = await loadHtmtFromCelex(
    "02016R1036-20200811",
    "EN",
  ); //load html file from disk
  final doc = html_parser.parse(htmlContent);
  compareExtraction('Test', doc);
}

//************************************************************ */
*/
void openSearchUpload(json, indexName) {
  // Your regular JSON data (similar to the data you uploaded)
  var bilingualData = json;

  // OpenSearch URL (adjust to your OpenSearch server)
  String opensearchUrl = 'https://$osServer/opensearch/_bulk';

  // Prepare the NDJSON data
  List<String> bulkData = [];

  for (var sentence in bilingualData) {
    var action = {
      "index": {
        "_index": indexName, // Your OpenSearch index name
        // Let OpenSearch generate a unique _id
        // _id is omitted, so OpenSearch generates it automatically
      },
    };

    // Convert the action and data into JSON and add them to the bulk data
    bulkData.add(jsonEncode(action)); // Add the action line
    bulkData.add(jsonEncode(sentence)); // Add the data line
  }

  // Send the NDJSON data to OpenSearch

  final bulkPreview = bulkData.sublist(
    0,
    bulkData.length < 2 ? bulkData.length : 2,
  );
  final bytesLength = (bulkData.join("\n") + "\n").length;
  print("Sending data to OpenSearch at $opensearchUrl");
  print("******************************************************************");
  print(bulkPreview);
  print("******************************************************************");

  try {
    final lgr = LogManager(fileName: '${fileSafeStamp}_${indexName}.log');
    lgr.log(
      'bulk start url=$opensearchUrl lines=${bulkData.length} bytes=$bytesLength osServer=$osServer',
    );
  } catch (_) {}

  sendToOpenSearch(opensearchUrl, bulkData);
}

// Function to send the NDJSON data to OpenSearch
Future<String> sendToOpenSearch(String url, List<String> bulkData) async {
  try {
    final ndjsonBody = bulkData.join("\n") + "\n";
    final response = await http
        .post(
          Uri.parse(url),
          headers: addDeviceIdHeader({
            "Content-Type": "application/x-ndjson; charset=utf-8",
            'x-api-key': '${jsonSettings['access_key']}',
            'x-email': '${jsonSettings['user_email']}',
            
          }),
          body: utf8.encode(ndjsonBody),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      print(
        "Data successfully processed in opensearch! ${response.body.substring(0, 100)}",
      );
      try {
        final lgr = LogManager(fileName: '${fileSafeStamp}_bulk_ok.log');
        lgr.log('200 OK at $url');
      } catch (_) {}
      return response.body;
    } else {
      print("Error: ${response.statusCode} - ${response.headers}");
      if (response.statusCode == 401 || response.statusCode == 429) {
        print("Showing subscription dialog for status ${response.statusCode}");
        showSubscriptionDialog(response.statusCode);
      }
      try {
        final lgr = LogManager(fileName: '${fileSafeStamp}_bulk_err.log');
        final bodyPrefix =
            response.body.length > 512
                ? response.body.substring(0, 512)
                : response.body;
        lgr.log('HTTP ${response.statusCode} at $url body: ' + bodyPrefix);
      } catch (_) {}
      return response.body;
    }
  } on TimeoutException catch (e) {
    print("Timeout sending data to OpenSearch: $e");
    try {
      final lgr = LogManager(fileName: '${fileSafeStamp}_bulk_err.log');
      lgr.log('Timeout at $url: $e');
    } catch (_) {}
    return "Timeout: $e";
  } on SocketException catch (e) {
    print("SocketException sending data to OpenSearch: $e");
    try {
      final lgr = LogManager(fileName: '${fileSafeStamp}_bulk_err.log');
      lgr.log('SocketException at $url: $e');
    } catch (_) {}
    return "SocketException: $e";
  } on http.ClientException catch (e) {
    print("ClientException sending data to OpenSearch: $e");
    try {
      final lgr = LogManager(fileName: '${fileSafeStamp}_bulk_err.log');
      lgr.log('ClientException at $url: $e');
    } catch (_) {}
    return "ClientException: $e";
  } catch (e) {
    print("Error sending data to OpenSearch: $e");
    try {
      final lgr = LogManager(fileName: '${fileSafeStamp}_bulk_err.log');
      lgr.log('Unexpected error at $url: $e');
    } catch (_) {}
    return "Error with OpenSearch: $e";
  }
}

String getmetadata(metadataRDF) //get celex and cellar info from RDF metadata
// find rdf:resource="http://publications.europa.eu/resource/celex/  data follows
{
  if (metadataRDF.contains('%%%#')) {
    metadataRDF = metadataRDF.split('%%%#')[1];
    print('Celex Overide for Reference Upload: $metadataRDF');
    return metadataRDF;
  }

  final regex = RegExp(
    r'owl:sameAs rdf:resource="http://publications\.europa\.eu/resource/celex/([^"/]+)',
  );
  final match = regex.firstMatch(metadataRDF);
  if (match != null && match.groupCount >= 1) {
    return match.group(1)!; // This is the CELEX number
  }
  return 'not found';
}

//the function below will process a multilingual map with extracted plain text lines and create a list of json entries
List<Map<String, dynamic>> processMultilingualMap(
  Map<String, List<List<String>>> map,
  String indexName,
  String celex,
  String dirID,
  bool simulate,
  bool debug,
  bool paragraphsNotMatched,
  int pointer,
  LogManager runLogger,
) {
  List<Map<String, dynamic>> jsonData =
      []; //to store created json entry for file

  int sequenceID = 0;
  /*
  final int numParagraphs =
      map.values.isEmpty
          ? 0
          : map.values.map((v) => v.length).reduce((a, b) => a > b ? a : b);

*/

  final counts = map.map((k, v) => MapEntry(k, v.length));
  final lengths = counts.values;
  final int minLen =
      lengths.isEmpty ? 0 : lengths.reduce((a, b) => a < b ? a : b);
  final int maxLen =
      lengths.isEmpty ? 0 : lengths.reduce((a, b) => a > b ? a : b);
  final bool lengthMismatch = minLen != maxLen;
  if (lengthMismatch) {
    print('Harvest Line count mismatch for $celex: $counts');
  }

  // Choose max (union) or switch to minLen for strict alignment
  final int numParagraphs = maxLen;

  String classForIndex(int i) {
    for (final lang in langsEU) {
      final rows = map[lang];
      if (rows != null && i >= 0 && i < rows.length && rows[i].length > 1) {
        final cls = rows[i][1];
        if (cls.isNotEmpty) return cls;
      }
    }
    return 'unknown';
  }

  //here a part of json will be created dynamically based on the supplied map, including all languages in the map
  for (int i = 0; i < numParagraphs; i++) {
    Map<String, String> texts = {};
    for (String lang in langsEU) {
      if (map.containsKey(lang) && map[lang]!.length > i) {
        texts["${lang.toLowerCase()}_text"] =
            map[lang]![i][0]; //texts["lang.toLowerCase()] = map[lang]![i][0];
      }
    }

    // list of langs []

    if (texts.isNotEmpty) {
      final cls = classForIndex(i);
      Map<String, dynamic> jsonEntry = {
        "sequence_id": sequenceID++,
        "date": DateTime.now().toUtc().toIso8601String(),
        "celex": celex,
        "dir_id": dirID, // Directory ID for logging purposes
        "filename": celex,
        "paragraphsNotMatched": lengthMismatch,

        "class": cls,
      };

      jsonEntry.addAll(
        texts,
      ); //here programatically created part with langs and texts is added
      jsonData.add(jsonEntry);
    }
  }

  // Simple sync try/catch (note: this will NOT catch asynchronous errors
  // originating inside sendToOpenSearch because openSearchUpload is not awaited)
  try {
    if (!simulate) {
      openSearchUpload(jsonData, indexName);
    }
  } catch (e, st) {
    runLogger.log(
      'OpenSearch upload failed, pointer: $pointer, celex: $celex: $e\n$st',
    );
  }

  // Recommended (to catch async errors): make processMultilingualMap async,
  // change openSearchUpload to return Future<void> and then:
  // try {
  //   if (!simulate) await openSearchUpload(jsonData, indexName);
  // } catch (e, st) {
  //   final logger = LogManager(fileName: 'logs/${fileSafeStamp}_${indexName}_error.log');
  //   logger.log('OpenSearch upload failed: $e\n$st');
  // }

  if (debug) {
    final logger = LogManager(
      fileName: 'logs/${fileSafeStamp}_${indexName}_debug.log',
    );
    final pretty = const JsonEncoder.withIndent('  ').convert(jsonData);
    logger.log(pretty);
  }

  final logger = LogManager(fileName: 'logs/${fileSafeStamp}_$indexName.log');
  final status = lengthMismatch ? 'parNotMatched' : 'status_ok';
  final msg =
      '$pointer $indexName, $dirPointer, $dirID, Processed, Celex: $celex, $status, Simulated: $simulate, Paragraphs: $numParagraphs';

  logger.log(msg);

  //JSOn ready, now turning in into NDJSON + action part
  print(
    "$pointer Harvested paragraphs uploaded to Open Search $indexName>COMPLETED  $msg",
  );

  return jsonData;
}

void showSubscriptionDialog(int status) {
  final ctx = navigatorKey.currentContext;
  if (ctx == null) {
    // Defer until a frame exists
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lateCtx = navigatorKey.currentContext;
      if (lateCtx == null) return;
      _showSubDialogInternal(lateCtx, status);
    });
    return;
  }
  _showSubDialogInternal(ctx, status);
}

void _showSubDialogInternal(BuildContext ctx, int status) {
  final msg =
      status == 401
          ? 'Please purchase an annual subscription for unlimited access.'
          : 'Daily trial limit exceeded. Please purchase an annual subscription or wait till next day.';
  showDialog(
    context: ctx,
    barrierDismissible: true,
    builder:
        (_) => AlertDialog(
          title: const Text('Subscription Required'),
          content: Text(
            '$msg\n\nClick "Purchase" to visit the Subscription page and obtain the passkey.\nThen go to Setup tab -> Enter Your Passkey\n\nFor trial access (7 free searches per day), use access key "trial" and your email address.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () {
                launchUrl(
                  Uri.parse('https://www.pts-translation.sk/#pricing'),
                  mode: LaunchMode.externalApplication,
                );
              },
              child: const Text('Purchase'),
            ),
          ],
        ),
  );
}
