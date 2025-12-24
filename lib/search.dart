import 'dart:convert';
import 'dart:math';
//import 'dart:nativewrappers/_internal/vm/lib/internal_patch.dart';

import 'package:LegisTracerEU/main.dart';
import 'package:LegisTracerEU/setup.dart';
import 'package:LegisTracerEU/sparql.dart';
import 'package:flutter/material.dart';
import 'package:LegisTracerEU/processDOM.dart';
import 'package:LegisTracerEU/display.dart';
import 'package:LegisTracerEU/preparehtml.dart';
import 'package:LegisTracerEU/analyser.dart';
import 'package:LegisTracerEU/http.dart';
import 'package:LegisTracerEU/ui_notices.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

import 'dart:isolate';
import 'dart:io';
import 'package:LegisTracerEU/file_handling.dart';
import 'package:LegisTracerEU/testHtmlDumps.dart';
import 'package:xml/xml.dart' as xml;

import 'package:path_provider/path_provider.dart';

StreamSubscription<Map<String, dynamic>>? _sub;
var resultsOS = [];
var decodedResults = [];
var lang2Results = [];
var lang1Results = ["N/A"];
var lang3Results = [];
List<String> metaCelex = [];
var metaCellar = [];
var sequenceNo;
var parNotMatched = ["N/A"];
var className = ["N/A"];
var docDate = ["N/A"];
var pointerPar;
var contextEnSkCz;
var queryText;
var queryPattern;
List<HighlightResult> enHighlightedResults = [];
List<HighlightResult> lang1HighlightedResults = [];
List<HighlightResult> lang2HighlightedResults = [];
List<HighlightResult> lang3HighlightedResults = [];
var activeIndex = '*';
var containsFilter = "";
var celexFilter = "";
var classFilter;
Key _searchKey = UniqueKey();
bool _isContentExpanded = false;
bool _autoAnalyse = false;
bool _matchedOnly = false;

const Map<String, Set<String>> stopwordsEU = {
  'bg': {
    'и',
    'в',
    'във',
    'на',
    'по',
    'с',
    'за',
    'от',
    'до',
    'защо',
    'как',
    'че',
    'които',
    'който',
    'която',
    'което',
    'тази',
    'тези',
    'това',
    'онзи',
    'онези',
    'не',
    'да',
    'ще',
    'беше',
    'са',
    'съм',
    'бях',
    'биха',
  },
  'cs': {
    'a',
    'ale',
    'anebo',
    'aby',
    'co',
    'jak',
    'že',
    'který',
    'která',
    'které',
    'ti',
    'ty',
    'tento',
    'tato',
    'tyto',
    'je',
    'jsou',
    'byl',
    'byla',
    'byli',
    'být',
    'bez',
    'do',
    'k',
    'ke',
    'na',
    'nad',
    'o',
    'od',
    'po',
    'pod',
    'pro',
    'při',
    's',
    'se',
    'u',
    'v',
    've',
    'z',
    'ze',
  },
  'da': {
    'og',
    'eller',
    'at',
    'af',
    'i',
    'på',
    'for',
    'til',
    'fra',
    'med',
    'om',
    'under',
    'over',
    'mellem',
    'den',
    'det',
    'de',
    'en',
    'et',
    'som',
    'der',
    'hvad',
    'hvem',
    'ikke',
    'er',
    'var',
    'bliver',
    'blev',
  },
  'de': {
    'und',
    'oder',
    'zu',
    'aus',
    'in',
    'im',
    'ins',
    'am',
    'an',
    'auf',
    'für',
    'von',
    'mit',
    'nach',
    'bei',
    'über',
    'unter',
    'der',
    'die',
    'das',
    'dem',
    'den',
    'des',
    'ein',
    'eine',
    'eines',
    'einem',
    'einen',
    'wie',
    'wer',
    'nicht',
    'ist',
    'sind',
    'war',
    'waren',
    'wird',
    'wurden',
  },
  'el': {
    'και',
    'ή',
    'να',
    'σε',
    'από',
    'με',
    'για',
    'ως',
    'χωρίς',
    'κατά',
    'προς',
    'υπό',
    'άνω',
    'κάτω',
    'ο',
    'η',
    'το',
    'οι',
    'τι',
    'ποιος',
    'δεν',
    'είναι',
    'ήταν',
    'είμαστε',
  },
  'en': {
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
    'by',
    'with',
    'from',
    'as',
    'that',
    'this',
    'these',
    'those',
    'is',
    'are',
    'was',
    'were',
    'be',
    'been',
    'being',
    'do',
    'does',
    'did',
    'not',
    'but',
    'if',
    'than',
    'then',
    'so',
    'such',
    'which',
    'who',
    'whom',
  },
  'es': {
    'y',
    'o',
    'a',
    'de',
    'del',
    'la',
    'el',
    'los',
    'las',
    'en',
    'por',
    'para',
    'con',
    'sin',
    'sobre',
    'entre',
    'hasta',
    'desde',
    'que',
    'como',
    'quién',
    'cuál',
    'no',
    'sí',
    'es',
    'son',
    'era',
    'eran',
    'ser',
    'estar',
    'fue',
    'fueron',
  },
  'et': {
    'ja',
    'või',
    'et',
    'koos',
    'ilma',
    'kuni',
    'alates',
    'sees',
    'peal',
    'juures',
    'pool',
    'alla',
    'üle',
    'vahel',
    'see',
    'seal',
    'tema',
    'kes',
    'mis',
    'ei',
    'on',
    'oli',
    'olema',
  },
  'fi': {
    'ja',
    'tai',
    'että',
    'kun',
    'jos',
    'mutta',
    'sekä',
    'ilman',
    'kanssa',
    'asti',
    'lähtien',
    'sisällä',
    'päällä',
    'se',
    'joka',
    'mitä',
    'kuka',
    'ei',
    'on',
    'oli',
    'ovat',
    'olla',
  },
  'fr': {
    'et',
    'ou',
    'à',
    'de',
    'des',
    'du',
    'la',
    'le',
    'les',
    'en',
    'par',
    'pour',
    'avec',
    'sans',
    'sur',
    'entre',
    'jusqu’',
    'depuis',
    'que',
    'qui',
    'comme',
    'ne',
    'pas',
    'est',
    'sont',
    'était',
    'étaient',
    'être',
    'ayant',
  },
  'hr': {
    'i',
    'ili',
    'da',
    'do',
    'od',
    'za',
    'u',
    'na',
    'po',
    'pod',
    'prema',
    's',
    'sa',
    'među',
    'između',
    'koji',
    'koja',
    'koje',
    'što',
    'tko',
    'nije',
    'je',
    'su',
    'bio',
    'bila',
    'bili',
    'biti',
  },
  'hu': {
    'és',
    'vagy',
    'hogy',
    'mint',
    'aki',
    'ami',
    'amely',
    'nem',
    'van',
    'volt',
    'vannak',
    'lenni',
    'a',
    'az',
    'egy',
    'egyik',
    'ba',
    'be',
    'ban',
    'ben',
    'ra',
    're',
    'nak',
    'nek',
    'hoz',
    'hez',
    'höz',
    'tól',
    'től',
    'ról',
    'ről',
    'között',
    'alatt',
    'felett',
  },
  'it': {
    'e',
    'o',
    'a',
    'di',
    'del',
    'della',
    'dei',
    'degli',
    'delle',
    'in',
    'su',
    'per',
    'con',
    'senza',
    'tra',
    'fra',
    'da',
    'al',
    'alla',
    'che',
    'come',
    'chi',
    'non',
    'è',
    'sono',
    'era',
    'erano',
    'essere',
    'stato',
  },
  'lt': {
    'ir',
    'ar',
    'kad',
    'kaip',
    'kuris',
    'kuri',
    'kurie',
    'ne',
    'yra',
    'buvo',
    'būti',
    'į',
    'iš',
    'su',
    'be',
    'nuo',
    'iki',
    'prie',
    'ant',
    'po',
    'per',
    'tarp',
  },
  'lv': {
    'un',
    'vai',
    'ka',
    'kā',
    'kurš',
    'kura',
    'kuri',
    'ne',
    'ir',
    'bija',
    'būt',
    'uz',
    'no',
    'ar',
    'bez',
    'līdz',
    'kopš',
    'pie',
    'virs',
    'zem',
    'pa',
    'starp',
  },
  'mt': {
    'u',
    'jew',
    'li',
    'min',
    'ta',
    'għal',
    'ma',
    'biex',
    'fuq',
    'fuqha',
    'f’',
    'bejn',
    'bla',
    'sa',
    'mill',
    'sal',
    'mal',
    'ma’',
    'dak',
    'dik',
    'dawk',
    'liema',
    'mhux',
    'hu',
    'huma',
    'kien',
    'kienu',
    'ikun',
  },
  'nl': {
    'en',
    'of',
    'te',
    'van',
    'de',
    'het',
    'een',
    'in',
    'op',
    'aan',
    'voor',
    'door',
    'met',
    'zonder',
    'over',
    'tussen',
    'tot',
    'vanaf',
    'naar',
    'bij',
    'onder',
    'boven',
    'dat',
    'die',
    'wie',
    'wat',
    'niet',
    'is',
    'zijn',
    'was',
    'waren',
    'wordt',
    'werden',
  },
  'pl': {
    'i',
    'lub',
    'że',
    'jak',
    'który',
    'która',
    'które',
    'to',
    'ten',
    'ta',
    'ci',
    'nie',
    'jest',
    'są',
    'był',
    'była',
    'byli',
    'być',
    'w',
    'we',
    'na',
    'nad',
    'pod',
    'za',
    'do',
    'od',
    'po',
    'przez',
    'bez',
    'z',
    'ze',
    'między',
  },
  'pt': {
    'e',
    'ou',
    'a',
    'o',
    'os',
    'as',
    'de',
    'do',
    'da',
    'dos',
    'das',
    'em',
    'por',
    'para',
    'com',
    'sem',
    'sobre',
    'entre',
    'até',
    'desde',
    'que',
    'como',
    'quem',
    'não',
    'sim',
    'é',
    'são',
    'era',
    'eram',
    'ser',
    'estar',
    'foi',
    'foram',
  },
  'ro': {
    'și',
    'sau',
    'la',
    'de',
    'din',
    'în',
    'pe',
    'pentru',
    'cu',
    'fără',
    'despre',
    'între',
    'până',
    'de la',
    'către',
    'care',
    'ce',
    'cine',
    'nu',
    'este',
    'sunt',
    'era',
    'erau',
    'a fi',
  },
  'sk': {
    'a',
    'aj',
    'alebo',
    'aby',
    'ako',
    'že',
    'ktorý',
    'ktorá',
    'ktoré',
    'tento',
    'táto',
    'tieto',
    'nie',
    'je',
    'sú',
    'bol',
    'bola',
    'boli',
    'byť',
    'bez',
    'do',
    'k',
    'ku',
    'na',
    'nad',
    'o',
    'od',
    'po',
    'pod',
    'pre',
    'pri',
    's',
    'so',
    'u',
    'v',
    'vo',
    'z',
    'zo',
  },
  'sl': {
    'in',
    'ali',
    'da',
    'kot',
    'kateri',
    'katera',
    'katere',
    'ne',
    'je',
    'so',
    'bil',
    'bila',
    'bili',
    'biti',
    'brez',
    'do',
    'k',
    'h',
    'na',
    'nad',
    'o',
    'od',
    'po',
    'pod',
    'za',
    'pri',
    's',
    'z',
    'u',
    'v',
    'med',
  },
  'sv': {
    'och',
    'eller',
    'att',
    'som',
    'inte',
    'är',
    'var',
    'bli',
    'blir',
    'vara',
    'i',
    'på',
    'av',
    'för',
    'med',
    'utan',
    'om',
    'mellan',
    'till',
    'från',
    'över',
    'under',
    'hos',
    'den',
    'det',
    'de',
    'en',
    'ett',
    'vilken',
    'vem',
    'vad',
  },
  'ga': {
    'agus',
    'nó',
    'go',
    'le',
    'gan',
    'i',
    'ar',
    'de',
    'do',
    'faoi',
    'idir',
    'ó',
    'chuig',
    'trí',
    'an',
    'na',
    'seo',
    'sin',
    'ní',
    'is',
    'bhí',
    'atá',
    'a bheith',
    'a bhí',
    'cé',
    'cad',
  },
};

Set<String> stopwordsForLangs({String? lang1, String? lang2, String? lang3}) {
  final acc = <String>{};
  void add(String? code) {
    final c = code?.toLowerCase();
    if (c != null) {
      final sw = stopwordsEU[c];
      if (sw != null) acc.addAll(sw);
    }
  }

  add(lang1);
  add(lang2);
  add(lang3);
  return acc;
}

class SearchTabWidget extends StatefulWidget {
  final String queryText;
  final String queryName;

  const SearchTabWidget({
    Key? key,
    required this.queryText,
    required this.queryName,
  }) : super(key: key);

  @override
  _SearchTabWidgetState createState() => _SearchTabWidgetState();
}

class _SearchTabWidgetState extends State<SearchTabWidget>
    with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _controller2 = TextEditingController();
  final TextEditingController _controller3 = TextEditingController();
  //final List<bool> _quickSettings = List.generate(6, (_) => true);
  final List<String> _results = [];

  Color _fillColor = Colors.white30;
  Color _fillColor2 = Colors.white30;

  //the following code is to periodically check if a file has changed and reload its content if it has, for auto lookup of new Studio segments on Search tab
  String _fileContent = "Loading...";
  Timer? _pollingTimer;
  bool _isVisible = true;
  var lastFileContent = "";
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Load settings before using jsonSettings
    loadSettingsFromFile().then((_) {
      // Load indices with proper filtering after settings are loaded
      getCustomIndices(
        server,
        isAdmin,
        jsonSettings['access_key'] ?? DEFAULT_ACCESS_KEY,
      ).then((_) {
        if (mounted) {
          setState(() {
            print(
              "SearchTab initialized - Indices loaded: $indices for isAdmin: $isAdmin",
            );
          });
        }
      });
    });

    // Remove the stream listener for Trados integration (Option A)
    // if (jsonSettings["auto_lookup"] == true) {
    //   _sub = ingestServer.stream.listen((payload) {
    //     _httpUpdate(payload);
    //   });
    // }

    // Set up the onRequest handler for Trados
    ingestServer.onRequest = (payload) async {
      // Run the same logic as auto_lookup

      print("onRequest Received Trados payload: $payload");
      await _httpUpdate(payload);

      // Wait for processQuery to finish (if _httpUpdate is async, use await)
      // If _httpUpdate is not async, you may need to refactor it to be async and await processQuery inside it.

      // Package results for Trados
      final count = min(
        lang1Results.length,
        min(lang2Results.length, metaCelex.length),
      );
      final results = List<Map<String, String>>.generate(count, (i) {
        return {
          'lang1_result': lang1Results[i],
          'lang2_result': "<b>${lang2Results[i]}</b>",
          'celex': metaCelex[i],
        };
      });
      print("HTTP response Returning results to Trados: $results");

      // Check for serialization issues
      try {
        final testJson = jsonEncode({
          'status': 'success',
          'lang1': lang1,
          'lang2': lang2,
          'count': results.length,
          'results': results,
        });
        print("Test JSON serialization succeeded: $testJson");
      } catch (e) {
        print("JSON serialization error: $e");
      }

      // return {'results': results};
      return {
        'status': 'success',
        'lang1': lang1,
        'lang2': lang2,
        'count': results.length,
        'results': results,
      };
    };
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() async {
    return;
    /*
    _pollingTimer = Timer.periodic(Duration(milliseconds: 500), (timer) {
      if (_isVisible || !_isVisible) {
        print("Timer triggered");
        _readFile();
        if (_fileContent != lastFileContent &&
            jsonSettings["auto_lookup"] == true) {
          print("File content changed, updating state");
          _updateState();
        } else {
          print("No change in file content");
        }
      }
    });
  */
  }

  Future _httpUpdate(payload) async {
    if (jsonSettings["auto_lookup"] == false) return;

    _results.clear();

    enHighlightedResults.clear();
    lang1HighlightedResults.clear();
    lang2HighlightedResults.clear();
    lang3HighlightedResults.clear();
    //   List subsegments = subsegmentFile(_fileContent);

    String _httpSource = payload['source'] ?? '';
    String _httpTarget = payload['target'] ?? '';
    String _httpSegmentID = payload['segmentId'] ?? '';
    String _httpTimestamp = payload['timestamp'] ?? '';

    httpPassAnalyzer = _httpSource;

    print(
      "Http testing, source: $_httpSource, target: $_httpTarget, segmentID: $_httpSegmentID, timestamp: $_httpTimestamp",
    );
    setState(() {
      _progressColor =
          Colors
              .redAccent; //when auto lookup from Studio, the progress bar color is redAccent
    });

    //
    var queryAnalyser = {
      "query": {
        "bool": {
          "must": [
            {
              "multi_match": {
                "query": _httpSource,
                "type": "phrase",
                "fields": [
                  "${lang1?.toLowerCase()}_text",
                  "${lang2?.toLowerCase()}_text",
                  "${lang3?.toLowerCase()}_text",
                ],

                "minimum_should_match": "60%",
              },
            },
          ],
        },
      },
      "size": 3,
    };

    await processQuery(queryAnalyser, _httpSource, activeIndex);
    if (!mounted) return;
    setState(() {
      queryText = "Auto-analyse: $_httpSource";
    }); // You may need to call setState again to update the UI
  }

  void _updateState() async {
    if (!mounted) return;
    setState(() {
      lastFileContent = _fileContent;

      _results.clear();

      enHighlightedResults.clear();
      lang1HighlightedResults.clear();
      lang2HighlightedResults.clear();
      lang3HighlightedResults.clear();
      //   List subsegments = subsegmentFile(_fileContent);
    });

    //
    var queryAnalyser = {
      "query": {
        "bool": {
          "must": [
            {
              "multi_match": {
                "query": lastFileContent,
                "fields": [
                  "${lang1?.toLowerCase()}_text",
                  "${lang2?.toLowerCase()}_text",
                  "${lang3?.toLowerCase()}_text",
                ],
                "fuzziness": "0",
                "minimum_should_match": "60%",
              },
            },
          ],
        },
      },
      "size": 50,
    };

    processQuery(queryAnalyser, lastFileContent, activeIndex);

    setState(() {
      queryText = "Auto-analyse: $lastFileContent";
    }); // You may need to call setState again to update the UI
  }

  Future<String> _readFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('C:/Temp/segment_output.txt');
      final content = await file.readAsString();
      if (mounted) {
        setState(() {
          _fileContent = content;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _fileContent = "Error reading file.";
        });
      }
    }
    return _fileContent;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isVisible = state == AppLifecycleState.resumed;
  }

  //the end of periodi polling code

  Future processQuery(query, searchTerm, index) async {
    queryPattern = query;

    lang1Results.clear;
    lang2Results.clear;
    lang3Results.clear;
    lang1HighlightedResults.clear();
    lang2HighlightedResults.clear();
    lang3HighlightedResults.clear();
    enHighlightedResults.clear();
    if (mounted) setState(() => _isLoading = true);

    final resultsOS = await sendToOpenSearch(
      'https://$osServer/$index/_search',
      [jsonEncode(query)],
    );
    if (!mounted) return;
    // Guard: if offline or invalid response, fail gracefully
    Map<String, dynamic> decodedResults;
    try {
      decodedResults = jsonDecode(resultsOS) as Map<String, dynamic>;
    } on FormatException catch (_) {
      showInfo(
        context,
        'You appear to be offline or the server response was invalid. Please check your connection and try again.',
      );
      setState(() {
        _progressColor = Colors.redAccent;
        _isLoading = false;
      });
      return;
    } catch (_) {
      showInfo(
        context,
        'Unexpected error parsing server response. Please try again.',
      );
      setState(() {
        _progressColor = Colors.redAccent;
        _isLoading = false;
      });
      return;
    }

    //if query returns error, stop processing, display error
    if (decodedResults['error'] != null) {
      print("Error in OpenSearch response: ${decodedResults['error']}");

      showInfo(
        context,
        'Error in OpenSearch response: ${decodedResults['error']}',
      );

      setState(() {
        _progressColor = Colors.redAccent; // indicate error via color
      });

      if (mounted) setState(() => _isLoading = false);
      return;
    }

    var hits = decodedResults['hits']['hits'] as List;

    setState(() {
      lang2Results =
          hits
              .map(
                (hit) =>
                    (hit['_source']?['${lang2?.toLowerCase()}_text'] as String?)
                        ?.trim(),
              )
              .map((s) => (s == null || s.isEmpty) ? 'N/A' : s)
              .toList();
      lang1Results =
          hits
              .map(
                (hit) =>
                    (hit['_source']?['${lang1?.toLowerCase()}_text'] as String?)
                        ?.trim(),
              )
              .map((s) => (s == null || s.isEmpty) ? 'N/A' : s)
              .toList();
      lang3Results =
          hits
              .map(
                (hit) =>
                    (hit['_source']?['${lang3?.toLowerCase()}_text'] as String?)
                        ?.trim(),
              )
              .map((s) => (s == null || s.isEmpty) ? 'N/A' : s)
              .toList();

      metaCelex =
          hits.map((hit) => hit['_source']['celex'].toString()).toList();
      metaCellar =
          hits.map((hit) => hit['_source']['dir_id'].toString()).toList();
      sequenceNo =
          hits.map((hit) => hit['_source']['sequence_id'].toString()).toList();
      parNotMatched =
          hits
              .map((hit) => hit['_source']['paragraphsNotMatched'].toString())
              .toList();
      pointerPar =
          hits.map((hit) => hit['_source']['sequence_id'].toString()).toList();

      className =
          hits.map((hit) => hit['_source']['class'].toString()).toList();

      docDate = hits.map((hit) => hit['_source']['date'].toString()).toList();
    });

    // Prefetch titles for the current result set (async, non-blocking)
    //await _prefetchTitles(metaCelex.toSet());

    print("Query: $query, Results SK = $lang2Results");

    queryText = searchTerm; //_searchController.text;
    //converting the results to TextSpans for highlighting
    final queryWords =
        queryText
            .replaceAll(RegExp(r"[^\p{L}\p{M}\p{N}\s'’\-‑]", unicode: true), '')
            .split(RegExp(r"\s+", unicode: true))
            .where((String w) => w.isNotEmpty)
            .toList();
    queryWords.add(
      queryText,
    ); //the whole phrase added to facilitate highlighting

    print("Query Words: $queryWords");

    for (var hit in lang1Results) {
      final res = highlightPhrasePreservingLayout(hit, queryWords);
      enHighlightedResults.add(res);
      lang1HighlightedResults.add(res);
      // You can store these highlights in a list or map if needed
    }

    for (var hit in lang2Results) {
      final res = highlightPhrasePreservingLayout(hit, queryWords);

      lang2HighlightedResults.add(res);
      // You can store these highlights in a list or map if needed
    }

    for (var hit in lang3Results) {
      final res = highlightPhrasePreservingLayout(hit, queryWords);

      lang3HighlightedResults.add(res);
      // You can store these highlights in a list or map if needed
    }
    print(
      "EN Highlight all: ${enHighlightedResults.length}, $enHighlightedResults",
    );

    if (!mounted) return;
    setState(() {});
    if (mounted) setState(() => _isLoading = false);

    //BUG too power hungry to get titles with titlesForCelex();
  }

  void _startSearch() async {
    setState(() {
      _results.clear();

      enHighlightedResults.clear();
    });
    var query = {
      "query": {
        "match_phrase": {
          "${lang1?.toLowerCase()}_text": {
            "query": _searchController.text,
            "slop": 2, // Allow some flexibility in word order
            "boost": 1.5, // Boost the phrase match
          },
        },
      },
      "size": 50,
    };
    //var queryText = _searchController.text;

    processQuery(query, _searchController.text, activeIndex);
  }

  void _startSearch2() async {
    // : Implement your search logic here
    setState(() {
      _results.clear();
      enHighlightedResults.clear();
    });

    var query = {
      "query": {
        "multi_match": {
          "query": _searchController.text, // Search term with a typo
          "fields": [
            "en_text",
            "sk_text",
            "cs_text",
          ], // Search across all language fields
          "fuzziness": "0",
          "minimum_should_match": "75%", // Allow fuzzy matching
        },
      },
      "size": 50,
      "highlight": {
        "fields": {"en_text": {}, "sk_text": {}, "cz_text": {}},
      },
    }; // Increase the number of results to 50

    var query2 = {
      "query": {
        "bool": {
          "must": [
            {
              "multi_match": {
                "query": _searchController.text,
                "fields": [
                  "${lang1?.toLowerCase()}_text",
                  "${lang2?.toLowerCase()}_text",
                  "${lang3?.toLowerCase()}_text",
                ],
                "fuzziness": "AUTO",
                "minimum_should_match": "80%",
              },
            },
            {
              "term": {"paragraphsNotMatched": false},
            },
          ],
        },
      },
      "size": 50,
      "highlight": {
        "fields": {
          "${lang1?.toLowerCase()}_text": {},
          "${lang2?.toLowerCase()}_text": {},
          "${lang3?.toLowerCase()}_text": {},
        },
      },
    };

    processQuery(query2, _searchController.text, activeIndex);
  }

  void _startSearch3() async {
    // : Implement your search logic here
    setState(() {
      _results.clear();

      enHighlightedResults.clear();
    });
    var query = {
      "query": {
        "bool": {
          "should": [
            {
              "match_phrase": {
                "${lang1?.toLowerCase()}_text": {
                  "query": _searchController.text,
                  "slop": 2,
                  "boost": 3.0,
                },
              },
            },
            {
              "match": {
                "${lang1?.toLowerCase()}_text": {
                  "query": _searchController.text,
                  "fuzziness": "AUTO",
                  "operator": "and",
                  "boost": 1.0,
                },
              },
            },
            {
              "match_phrase": {
                "${lang2?.toLowerCase()}_text": {
                  "query": _searchController.text,
                  "slop": 2,
                  "boost": 3.0,
                },
              },
            },
            {
              "match": {
                "${lang2?.toLowerCase()}_text": {
                  "query": _searchController.text,
                  "fuzziness": "AUTO",
                  "operator": "and",
                  "boost": 1.0,
                },
              },
            },
            {
              "match_phrase": {
                "${lang3?.toLowerCase()}_text": {
                  "query": _searchController.text,
                  "slop": 2,
                  "boost": 3.0,
                },
              },
            },
            {
              "match": {
                "${lang3?.toLowerCase()}_text": {
                  "query": _searchController.text,
                  "fuzziness": "AUTO",
                  "operator": "and",
                  "boost": 1.0,
                },
              },
            },
          ],
          "minimum_should_match": 1,
        },
      },
      "size": 25,
    };
    //var queryText = _searchController.text;

    processQuery(query, _searchController.text, activeIndex);
  }

  void _startSearchPhraseAll() async {
    setState(() {
      _results.clear();
      enHighlightedResults.clear();
    });

    final query = {
      "query": {
        "multi_match": {
          "type": "phrase",
          "query": _searchController.text,
          "slop": 10,
          "fields": ["*_text"], // all lang fields ending with _text
          "auto_generate_synonyms_phrase_query": false,
          "lenient": true,
        },
      },
      "size": 50,
      "highlight": {
        "require_field_match": false,
        "fields": {"*_text": {}},
      },
    };

    processQuery(query, _searchController.text, "*");
  }

  Color backgroundColor = Colors.white12;
  bool _isLoading = false;
  Color _progressColor = Colors.blue; // default loading color

  void updateDropdown() async {
    await getCustomIndices(
      server,
      isAdmin,
      jsonSettings['access_key'] ?? DEFAULT_ACCESS_KEY,
    );
    setState(() {
      print(
        "Dropdown tapped and indices updated from server $server, Admin user: $isAdmin, jsonSettings['access_key']: ${jsonSettings['access_key']}, indices: $indices.",
      );
    });
  }

  final Map<String, String> _titleCache = {};

  Future<String?> _fetchTitleForCelex(
    String celex, {
    String lang = 'en',
  }) async {
    final uri = Uri.parse(
      'http://publications.europa.eu/resource/celex/$celex',
    );
    try {
      final resp = await http
          .get(uri, headers: {'Accept': 'application/rdf+xml;notice=tree'})
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return null;

      final doc = xml.XmlDocument.parse(utf8.decode(resp.bodyBytes));
      //print('title prefetch response: ${doc.length} for $uri');
      // Prefer title with xml:lang == lang
      for (final e in doc.descendants.whereType<xml.XmlElement>()) {
        if (e.name.local == 'title') {
          final langAttr = e.getAttribute(
            'lang',
            namespace: 'http://www.w3.org/XML/1998/namespace',
          );
          if ((langAttr ?? '').toLowerCase() == lang.toLowerCase()) {
            final t = e.innerText.trim();
            if (t.isNotEmpty) return t;
          }
        }
      }
      // Fallback: any title text
      for (final e in doc.descendants.whereType<xml.XmlElement>()) {
        if (e.name.local == 'title') {
          final t = e.innerText.trim();
          if (t.isNotEmpty) return t;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future titlesForCelex() async {
    for (final c in metaCelex) {
      final t = _titleCache[c];
      if (t != null) {
        if (!mounted) return;
        setState(() {
          _titleCache[c] = t;
        });
      } else {
        final t = await fetchTitlesForCelex(c);
        if (t != null) {
          if (!mounted) return;
          setState(() {});
        }
      }
    }

    print("Titles fetched for all celexes in results $_titleCache");
  }

  Future<void> _prefetchTitles(Iterable<String> celexes) async {
    print("title celex to prefetch: ${celexes.join(', ')}  ");
    for (final c in celexes) {
      if (c.isEmpty || _titleCache.containsKey(c)) continue;
      final x = await fetchTitlesForCelex(c);
      String t = x['en'] ?? x.values.firstOrNull ?? '';

      if (!mounted) return;
      setState(() {
        _titleCache[c] = t ?? '';
        print("Prefetched title for $c: ${_titleCache[c]}");
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search field with Enter key trigger
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              // TextField taking most of the space
              Expanded(
                flex: 9, // 9/10 of the row
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    prefixIcon: Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey[200],
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 20,
                      horizontal: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (value) => _startSearch2(),
                ),
              ),
              SizedBox(
                width: 30,
              ), // Add some spacing between the TextField and the dropdown
              // Dropdown taking about 1/10 of the space
              Flexible(
                flex: 2, // 1/10 of the row
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText:
                        'Search Index ($activeIndex)', // Label embedded in the frame
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value:
                          indices.contains(
                                activeIndex,
                              ) //TODO active index is inited with "*", which indices does contain, so nothing is shown, save last index
                              ? activeIndex
                              : indices.isNotEmpty
                              ? indices[0]
                              : "*", // Default selected value
                      items:
                          indices.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),

                      onTap:
                          () => setState(() {
                            updateDropdown();
                          }),

                      onChanged: (String? newValue) {
                        setState(() {
                          activeIndex = newValue!;
                        });
                        // Handle dropdown selection
                        print('Selected: $newValue');
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Start Search button
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Tooltip(
                message:
                    'Phrase search in English with tight matching in your custom index',
                waitDuration: Duration(seconds: 1),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    foregroundColor:
                        Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  onPressed: () {
                    setState(() => _progressColor = Colors.blue);
                    _startSearch();
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search),
                      SizedBox(width: 6),
                      Text('Phrase $lang1'),
                    ],
                  ),
                ),
              ),
              Tooltip(
                message:
                    'Search across languages with flexible matching in your custom index',
                waitDuration: Duration(seconds: 1),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    foregroundColor:
                        Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  onPressed: () {
                    setState(() => _progressColor = Colors.green);
                    _startSearch2();
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search),
                      SizedBox(width: 6),
                      Text('Multi $lang1, $lang2, $lang3'),
                    ],
                  ),
                ),
              ),
              Tooltip(
                message:
                    'Combine match and phrase search for better recall in your custom index',
                waitDuration: Duration(seconds: 1),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    foregroundColor:
                        Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  onPressed: () {
                    setState(() => _progressColor = Colors.purple);
                    _startSearch3();
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search),
                      SizedBox(width: 6),
                      Text('Combined $lang1, $lang2, $lang3'),
                    ],
                  ),
                ),
              ),
              Tooltip(
                message:
                    'Phrase search across all language fields in Global Index (All EU law available)',
                waitDuration: Duration(seconds: 1),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).colorScheme.tertiaryContainer,
                    foregroundColor:
                        Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                  onPressed: () {
                    setState(() => _progressColor = Colors.orange);
                    _startSearchPhraseAll();
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search),
                      SizedBox(width: 6),
                      Text('All'),
                    ],
                  ),
                ),
              ),

              SizedBox(
                width: 150,
                child: TextFormField(
                  controller: _controller2,
                  //key: ValueKey(_searchController.text),
                  decoration: InputDecoration(
                    labelText: 'Filter by Celex',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: _fillColor2,
                    suffixIcon: Tooltip(
                      message:
                          'Enter CELEX ID (e.g., 32015R0459) or any part of it to filter results.  Press Enter to activate the filter (the field will turn orange).',
                      child: Icon(Icons.info_outline, size: 13),
                    ),
                  ),
                  onFieldSubmitted: (value) {
                    _controller2.text = value;
                    setState(() {
                      celexFilter = value;
                      _fillColor2 =
                          value.isNotEmpty
                              ? Colors.orangeAccent
                              : Theme.of(context).canvasColor;
                    });

                    print(" Celex Filter: $celexFilter");
                  },
                ),
              ),
              SizedBox(
                width: 150,
                child: TextFormField(
                  controller: _controller3,
                  //key: ValueKey(_searchController.text),
                  decoration: InputDecoration(
                    labelText: 'Contains',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: _fillColor,
                    suffixIcon: Tooltip(
                      message:
                          'Enter any text to filter results. Press Enter to activate the filter (the field will turn orange).',
                      child: Icon(Icons.info_outline, size: 13),
                    ),
                  ),
                  onFieldSubmitted: (value) {
                    _controller3.text = value;
                    setState(() {
                      containsFilter = value;

                      _fillColor =
                          value.isNotEmpty
                              ? Colors.orangeAccent
                              : Theme.of(context).canvasColor;
                    });

                    print(" Contains Filter: $containsFilter");
                  },
                ),
              ),

              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Tooltip(
                    message:
                        'Select to display the first language based on your selection in Setup',
                    waitDuration: Duration(seconds: 1),
                    child: Checkbox(
                      tristate: true,
                      value: jsonSettings['display_lang1'],
                      onChanged: (bool? newValue) {
                        setState(() {
                          jsonSettings['display_lang1'] = newValue ?? false;
                          writeSettingsToFile(jsonSettings);
                          print(
                            "checkbox" +
                                jsonSettings['display_lang1'].toString(),
                          );
                        });
                      },
                    ),
                  ),
                  Text(
                    jsonSettings['lang1'] ?? "N/A",
                    style: TextStyle(
                      fontSize: 16,
                    ), // Optional: Adjust the font size
                  ),

                  Tooltip(
                    message:
                        'Select to display the second language based on your selection in Setup',
                    waitDuration: Duration(seconds: 1),
                    child: Checkbox(
                      tristate: true,
                      value: jsonSettings['display_lang2'],
                      onChanged: (bool? newValue) {
                        setState(() {
                          jsonSettings['display_lang2'] = newValue ?? false;
                          writeSettingsToFile(jsonSettings);
                          print(
                            "checkbox" +
                                jsonSettings['display_lang2'].toString(),
                          );
                        });
                      },
                    ),
                  ),
                  Text(
                    jsonSettings['lang2'] ?? "N/A",
                    style: TextStyle(
                      fontSize: 16,
                    ), // Optional: Adjust the font size
                  ),

                  Tooltip(
                    message:
                        'Select to display the third language based on your selection in Setup',
                    waitDuration: Duration(seconds: 1),
                    child: Checkbox(
                      tristate: true,
                      value: jsonSettings['display_lang3'],
                      onChanged: (bool? newValue) {
                        setState(() {
                          jsonSettings['display_lang3'] = newValue ?? false;
                          writeSettingsToFile(jsonSettings);
                          print(
                            "checkbox" +
                                jsonSettings['display_lang3'].toString(),
                          );
                        });
                      },
                    ),
                  ),
                  Text(
                    jsonSettings['lang3'] ?? "N/A",
                    style: TextStyle(
                      fontSize: 16,
                    ), // Optional: Adjust the font size
                  ),
                  Tooltip(
                    message:
                        'Only show paragraphs from documents with text blocks aligned across languages. Due to source inconsistencies, if documents are misaligned (the content in one language does not match the content of another working language), click Expand/Collapse Context to see the relevant text block (may be shifted a few positions up or down). ',
                    waitDuration: Duration(seconds: 1),
                    triggerMode:
                        TooltipTriggerMode
                            .longPress, // tap/longPress for mobile
                    child: Checkbox(
                      tristate: true,
                      value: _matchedOnly,
                      onChanged: (bool? newValue) {
                        setState(() {
                          _matchedOnly = newValue ?? false;
                        });
                      },
                    ),
                  ),
                  Text(
                    'Aligned',
                    style: TextStyle(
                      fontSize: 16,
                    ), // Optional: Adjust the font size
                  ),
                  Tooltip(
                    message: 'Show metadata column (CELEX, date, class...)',
                    waitDuration: Duration(seconds: 1),
                    child: Checkbox(
                      tristate: true,
                      value: jsonSettings['display_meta'],
                      onChanged: (bool? newValue) {
                        setState(() {
                          jsonSettings['display_meta'] = newValue ?? false;
                          writeSettingsToFile(jsonSettings);
                        });
                      },
                    ),
                  ),
                  Text(
                    'Meta',
                    style: TextStyle(
                      fontSize: 16,
                    ), // Optional: Adjust the font size
                  ),

                  Tooltip(
                    message:
                        'Select to enable automatic lookup when a segment is selected in Trados Studio (the LegisTracerEU plugin must be installed and running in Trados Studio)',
                    waitDuration: Duration(seconds: 1),
                    child: Checkbox(
                      tristate: true,
                      value: jsonSettings['auto_lookup'],
                      onChanged: (bool? newValue) {
                        setState(() {
                          jsonSettings['auto_lookup'] = newValue ?? false;
                          writeSettingsToFile(jsonSettings);
                          print(
                            "checkbox" + jsonSettings['auto_lookup'].toString(),
                          );
                        });
                      },
                    ),
                  ),
                  Text(
                    "Auto",
                    style: TextStyle(
                      fontSize: 16,
                    ), // Optional: Adjust the font size
                  ),
                ],
              ),

              /*    SizedBox(
                width: 150,
                child: TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Filter by Class',
                    border: OutlineInputBorder(),
                  ),
                  onFieldSubmitted: (value) {
                    _searchController.text = value;
                    _startSearch();
                  },
                ),
              ),*/
            ],
          ),
        ),
        if (_isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: LinearProgressIndicator(
              minHeight: 4,
              valueColor: AlwaysStoppedAnimation<Color>(_progressColor),
              //  backgroundColor: _progressColor.withOpacity(0.2),
            ),
          ),

        // Quick settings checkboxes
        isAdmin
            ? Container(
              color: const Color.fromARGB(200, 210, 238, 241),
              child: ExpansionTile(
                title:
                    (celexFilter.isNotEmpty || containsFilter.isNotEmpty)
                        ? Row(
                          children: [
                            Icon(Icons.filter_alt, color: Colors.orange),
                            SizedBox(width: 8),
                            isAdmin
                                ? Text(
                                  "Query Details: ${lang1Results.length} result(s)",
                                )
                                : SizedBox.shrink(),
                            SizedBox(width: 8),

                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  celexFilter = "";
                                  containsFilter = "";
                                  _fillColor = Theme.of(context).canvasColor;
                                  _fillColor2 = Theme.of(context).canvasColor;
                                  _controller2.clear();
                                  _controller3.clear();
                                  //  _searchController.text =
                                  ""; // <--- Set the text to an empty string
                                  //  _searchKey = UniqueKey();
                                });

                                setState(() {}); // handle click event here
                              },
                              child: Text(
                                "Filtered Results Displayed, Click Here to Clear Filters",
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        )
                        : isAdmin
                        ? Text(
                          "Query Details: ${lang1Results.length} result(s)",
                        )
                        : SizedBox.shrink(),
                onExpansionChanged: (bool expanded) {
                  if (expanded) {
                    // Wrap the async call in an anonymous async function
                    () {
                      setState(() {});
                      print('Tile -query details- was expanded');
                    }(); // Immediately invoke the async function
                  } else {
                    print('Tile -query details- was collapsed');
                  }
                },

                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Query at $activeIndex: $queryText',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SelectableText(
                      'Query Text: $queryPattern',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Query Result: $lang1Results',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  /*   Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Results Count: ${enResults.length}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),*/
                ],
              ),
            )
            : SizedBox.shrink(),

        SizedBox(height: 10),
        Divider(color: Colors.grey[300], thickness: 3),
        // Results list
        Expanded(
          child: ListView.builder(
            itemCount: enHighlightedResults.length,
            itemBuilder: (context, index) {
              final TextSpan span =
                  (enHighlightedResults.length > index)
                      ? enHighlightedResults[index].span
                      : const TextSpan();

              final TextSpan spanLang1 =
                  (lang1HighlightedResults.length > index)
                      ? lang1HighlightedResults[index].span
                      : const TextSpan();

              final TextSpan spanLang2 =
                  (lang2HighlightedResults.length > index)
                      ? lang2HighlightedResults[index].span
                      : const TextSpan();

              final TextSpan spanLang3 =
                  (lang3HighlightedResults.length > index)
                      ? lang3HighlightedResults[index].span
                      : const TextSpan();

              return ((lang1Results.isNotEmpty &&
                              index < lang1Results.length &&
                              lang1Results[index].toLowerCase().contains(
                                containsFilter.toLowerCase(),
                              ) ||
                          containsFilter == '') &&
                      (metaCelex.isNotEmpty &&
                              index < metaCelex.length &&
                              metaCelex[index].toLowerCase().contains(
                                celexFilter.toLowerCase(),
                              ) ||
                          celexFilter == '') &&
                      (parNotMatched.isNotEmpty &&
                              index < parNotMatched.length &&
                              parNotMatched[index] == 'false' ||
                          !_matchedOnly))
                  ? Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10.0,
                      vertical: 5.0,
                    ),

                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            jsonSettings['display_lang1']
                                ? Expanded(
                                  flex: 4, // Language columns are wider
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0,
                                    ),
                                    child: ValueListenableBuilder<double>(
                                      valueListenable:
                                          searchResultsFontScaleNotifier,
                                      builder: (context, scale, __) {
                                        return SelectableText.rich(
                                          style: TextStyle(
                                            fontSize: 18.0 * scale,
                                          ),
                                          spanLang1,
                                        );
                                      },
                                    ),
                                  ),
                                )
                                : SizedBox.shrink(),

                            jsonSettings['display_lang2']
                                ? Expanded(
                                  flex: 4, // Language columns are wider
                                  child: Container(
                                    // color:
                                    //     Colors
                                    //        .grey[100], // Subtle shading for differentiation
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0,
                                    ),
                                    child: ValueListenableBuilder<double>(
                                      valueListenable:
                                          searchResultsFontScaleNotifier,
                                      builder: (context, scale, __) {
                                        return SelectableText.rich(
                                          style: TextStyle(
                                            fontSize: 18.0 * scale,
                                          ),
                                          spanLang2,
                                        );
                                      },
                                    ),
                                  ),
                                )
                                : SizedBox.shrink(),
                            jsonSettings['display_lang3']
                                ? Expanded(
                                  flex: 4, // Language columns are wider
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0,
                                    ),
                                    child: ValueListenableBuilder<double>(
                                      valueListenable:
                                          searchResultsFontScaleNotifier,
                                      builder: (context, scale, __) {
                                        return SelectableText.rich(
                                          style: TextStyle(
                                            fontSize: 18.0 * scale,
                                          ),
                                          spanLang3,
                                        );
                                      },
                                    ),
                                  ),
                                )
                                : SizedBox.shrink(),
                            jsonSettings['display_meta']
                                ? SizedBox(
                                  width:
                                      240, // Constrain metadata width to prevent overflow
                                  child: Container(
                                    // Subtle shading for differentiation
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text("Celex: "),
                                            Expanded(
                                              child: SelectableText(
                                                metaCelex.length > index
                                                    ? metaCelex[index]
                                                    : '',
                                                // Consider: set maxLines for single-line truncation
                                                // maxLines: 1,
                                              ),
                                            ),
                                          ],
                                        ),
                                        // If you want to show czResults here as well, add another widget:
                                        /* Row(
                                          children: [
                                            Text("Cellar: "),
                                            Flexible(
                                              child: SelectableText(
                                                metaCellar.length > index
                                                    ? metaCellar[index]
                                                    : '',
                                                //  overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
*/
                                        Row(
                                          children: [
                                            Text("Date: "),
                                            Expanded(
                                              child: SelectableText(
                                                docDate.length > index
                                                    ? (() {
                                                      final raw =
                                                          docDate[index];
                                                      final dt =
                                                          DateTime.tryParse(
                                                            raw,
                                                          );
                                                      if (dt == null)
                                                        return raw;
                                                      return "${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}";
                                                    })()
                                                    : '',
                                                // maxLines: 1,
                                              ),
                                            ),
                                          ],
                                        ),

                                        Row(
                                          children: [
                                            Text("Class: "),
                                            Expanded(
                                              child: SelectableText(
                                                className.length > index
                                                    ? className[index]
                                                    : '',
                                                // maxLines: 1,
                                              ),
                                            ),
                                          ],
                                        ),

                                        Row(
                                          children: [
                                            Text("Sequence ID: "),
                                            Expanded(
                                              child: SelectableText(
                                                pointerPar.length > index
                                                    ? pointerPar[index]
                                                    : '',
                                                // maxLines: 1,
                                              ),
                                            ),
                                          ],
                                        ),
                                        (parNotMatched[index] == "true")
                                            ? Row(
                                              children: [
                                                Text(
                                                  "Texts may be misaligned!",
                                                ),
                                              ],
                                            )
                                            : SizedBox.shrink(),

                                        Row(
                                          children: [
                                            Text("Eur-Lex: "),
                                            GestureDetector(
                                              onTap: () {
                                                // Handle the tap event here, e.g. open the link in a browser
                                                launchUrl(
                                                  Uri.parse(
                                                    'http://eur-lex.europa.eu/legal-content/${lang1}-${lang2}/TXT/?uri=CELEX:${metaCelex[index]}',
                                                  ),
                                                );
                                              },
                                              child: Text(
                                                '${lang1}-${lang2}',
                                                style: TextStyle(
                                                  decoration:
                                                      TextDecoration.underline,
                                                  color: Colors.blue,
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 10),

                                            GestureDetector(
                                              onTap: () {
                                                // Handle the tap event here, e.g. open the link in a browser
                                                launchUrl(
                                                  Uri.parse(
                                                    'http://eur-lex.europa.eu/legal-content/${lang1}-${lang3}/TXT/?uri=CELEX:${metaCelex[index]}',
                                                  ),
                                                );
                                              },
                                              child: Text(
                                                '${lang1}-${lang3}',
                                                style: TextStyle(
                                                  decoration:
                                                      TextDecoration.underline,
                                                  color: Colors.blue,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                : SizedBox.shrink(),
                          ],
                        ),

                        Container(
                          color: const Color.fromARGB(200, 210, 238, 241),
                          child: ExpansionTile(
                            title: Text(
                              _isContentExpanded
                                  ? 'Collapse Context'
                                  : 'Expand Context',
                            ),
                            onExpansionChanged: (bool expanded) {
                              setState(() {
                                _isContentExpanded = expanded;
                              });

                              if (expanded) {
                                // Wrap the async call in an anonymous async function
                                () async {
                                  final result = await getContext(
                                    metaCelex[index],
                                    pointerPar[index],
                                  );
                                  setState(() {
                                    contextEnSkCz = result;
                                  });
                                  print('Tile was expanded');
                                }(); // Immediately invoke the async function
                              } else {
                                print('Tile was collapsed');
                              }
                            },

                            children: [
                              ListView.builder(
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
                                itemCount:
                                    (contextEnSkCz != null &&
                                            contextEnSkCz[0] != null)
                                        ? contextEnSkCz[0].length
                                        : 0,
                                itemBuilder: (context, index) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10.0,
                                      vertical: 5.0,
                                    ),
                                    child: Column(
                                      children: [
                                        Container(
                                          color:
                                              (index == 10)
                                                  ? Colors.grey[200]
                                                  : null,
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,

                                            children: [
                                              jsonSettings['display_lang1'] ==
                                                      true
                                                  ? Expanded(
                                                    child: SelectableText(
                                                      style: TextStyle(
                                                        fontSize: 18.0,
                                                      ),
                                                      (jsonSettings['display_lang1'] ==
                                                                  true &&
                                                              contextEnSkCz[0]
                                                                      .length >
                                                                  index)
                                                          ? contextEnSkCz[3][index] +
                                                              " : " +
                                                              contextEnSkCz[0][index]
                                                          : '',
                                                    ),
                                                  )
                                                  : SizedBox.shrink(),
                                              jsonSettings['display_lang2'] ==
                                                      true
                                                  ? Expanded(
                                                    child: SelectableText(
                                                      style: TextStyle(
                                                        fontSize: 18.0,
                                                      ),
                                                      (jsonSettings['display_lang2'] ==
                                                                  true &&
                                                              contextEnSkCz[1]
                                                                      .length >
                                                                  index)
                                                          ? contextEnSkCz[1][index +
                                                              offsetlang2]
                                                          : '',
                                                    ),
                                                  )
                                                  : SizedBox.shrink(),
                                              jsonSettings['display_lang3'] ==
                                                      true
                                                  ? Expanded(
                                                    child: SelectableText(
                                                      style: TextStyle(
                                                        fontSize: 18.0,
                                                      ),
                                                      (jsonSettings['display_lang3'] ==
                                                                  true &&
                                                              contextEnSkCz[2]
                                                                      .length >
                                                                  index)
                                                          ? contextEnSkCz[2][index +
                                                              offsetlang3]
                                                          : '',
                                                    ),
                                                  )
                                                  : SizedBox.shrink(),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        // Bottom buttons
                        /* Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(5, (index) {
                              return ElevatedButton(
                                onPressed: () {},
                                child: Text('B${index + 1}'),
                              );
                            }),
                          ),
                        ),*/
                      ],
                    ),
                  )
                  : SizedBox.shrink();
            },
          ),
        ),
      ],
    );
  }
}
