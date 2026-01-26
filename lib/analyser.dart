import 'dart:async';
import 'package:LegisTracerEU/main.dart';
import 'package:LegisTracerEU/search.dart';
import 'package:flutter/material.dart';

import 'package:LegisTracerEU/processDOM.dart';
import 'package:LegisTracerEU/preparehtml.dart';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:LegisTracerEU/ui_notices.dart';
import 'package:url_launcher/url_launcher.dart';

StreamSubscription<Map<String, dynamic>>? _sub1;
var nGrams = [];
Map nGramsResults = {"N/A": "N/A"};
var nGramResultList = [];
String httpPassAnalyzer = "";

Future<List> searchQuery(query, queryString) async {
  queryPattern = query;
  print("In ANALYSER searchQuery, query: $query, queryString: $queryString");
  var resultsOS = await sendToOpenSearch(
    'https://$osServer/$activeIndex/_search',
    [jsonEncode(query)],
  );
  Map<String, dynamic> decodedResults;
  try {
    decodedResults = jsonDecode(resultsOS) as Map<String, dynamic>;
  } on FormatException catch (_) {
    showInfo(
      navigatorKey.currentContext!,
      'You appear to be offline or the server response was invalid. Please check your connection and try again.',
    );
    return ["error"];
  } catch (e) {
    showInfo(
      navigatorKey.currentContext!,
      'Unexpected error parsing server response. Please try again.',
    );
    return ["error"];
  }
  print(
    "In ANALYSER searchQuery, query: $query, queryString: $queryString, Results: $resultsOS",
  );
  //if query returns error, stop processing, display error
  if (decodedResults['error'] != null) {
    print("Error in OpenSearch response: ${decodedResults['error']}");
    showInfo(
      navigatorKey.currentContext!,
      'Error in OpenSearch response: ${decodedResults['error']}',
    );

    /*
    enHighlightedResults = [
      TextSpan(
        children:
            ([decodedResults['error'].toString()]).map((text) {
              return TextSpan(
                text: text,
                style: TextStyle(color: Colors.black),
              );
            }).toList(),
      ),
    ];*/

    return ["error"];
  }

  var hits = decodedResults['hits']['hits'] as List;

  lang2Results =
      hits.map((hit) => hit['_source']['sk_text'].toString()).toList();
  lang1Results =
      hits.map((hit) => hit['_source']['en_text'].toString()).toList();
  lang3Results =
      hits.map((hit) => hit['_source']['cz_text'].toString()).toList();

  metaCelex = hits.map((hit) => hit['_source']['celex'].toString()).toList();
  metaCellar = hits.map((hit) => hit['_source']['dir_id'].toString()).toList();
  sequenceNo =
      hits.map((hit) => hit['_source']['sequence_id'].toString()).toList();
  parNotMatched =
      hits
          .map((hit) => hit['_source']['paragraphsNotMatched'].toString())
          .toList();
  pointerPar =
      hits.map((hit) => hit['_source']['sequence_id'].toString()).toList();

  className = hits.map((hit) => hit['_source']['class'].toString()).toList();

  docDate = hits.map((hit) => hit['_source']['date'].toString()).toList();

  print(
    "Query?: $query, Results SK = $lang2Results, Results EN = $lang1Results",
  );

  return [lang1Results, lang2Results];
}

/// Batch search n-grams in OpenSearch using the _msearch API.
/// Returns a map: ngram -> best match (or '<no match>')
/// Batch search n-grams in OpenSearch using the _msearch API, only returning results where all working language fields exist.
/// workingLangs: e.g. ['en', 'sk', 'cz']
Future<Map<String, String>> searchNGrams(
  List ngrams, [
  List<String>? workingLangs,
]) async {
  // If not provided, fallback to all _text fields
  final langs = workingLangs ?? ['en', 'sk', 'cz'];

  // SECURE: Use /search endpoint with Pattern 7 for IATE terminology
  // Note: Making individual requests instead of batch _msearch for security
  final results = <String, String>{};

  for (final ngram in ngrams) {
    final url = Uri.parse('$server/search');
    final body = jsonEncode({
      "index": "iate_7239_iate_terminology",
      "term": ngram,
      "langs": langs,
      "pattern": 7,
      "size": 1,
    });

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          'x-api-key': '${jsonSettings['access_key']}',
          'x-email': '${jsonSettings['user_email']}',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final hits = jsonResponse['hits']?['hits'] as List?;
        if (hits != null && hits.isNotEmpty) {
          final doc = hits[0]['_source'];
          final fields = langs.map((l) => l.toLowerCase() + '_text').toList();
          final textFields = fields
              .map((f) => doc[f])
              .where((v) => v != null)
              .join(' | ');
          results[ngram] = textFields.isNotEmpty ? textFields : '<no match>';
        } else {
          results[ngram] = '<no match>';
        }
      } else {
        results[ngram] = '<no match>';
      }
    } catch (e) {
      print('Error searching ngram "$ngram": $e');
      results[ngram] = '<no match>';
    }
  }

  return results;
}

class AnalyserWidget extends StatefulWidget {
  @override
  _FileDisplayWidgetState createState() => _FileDisplayWidgetState();
}

class _FileDisplayWidgetState extends State<AnalyserWidget>
    with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _searching = false;

  Future<void> _searchIateIndex() async {
    setState(() => _searching = true);
    final queryText = _searchController.text.trim();
    if (queryText.isEmpty) {
      setState(() {
        _searchResults = [];
        _searching = false;
      });
      return;
    }
    // Get working langs from settings or UI
    List<String> workingLangs =
        [
          if (lang1 != null) lang1,
          if (lang2 != null) lang2,
          if (lang3 != null) lang3,
        ].where((l) => l != null && l != '').cast<String>().toList();
    if (workingLangs.isEmpty) workingLangs = ['en', 'sk', 'cz'];

    // SECURE: Use /search endpoint with Pattern 7 for IATE
    final url = Uri.parse('$server/search');
    final body = jsonEncode({
      "index": "iate_7239_iate_terminology",
      "term": queryText,
      "langs": workingLangs,
      "pattern": 7,
      "size": 20,
    });

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          'x-api-key': '${jsonSettings['access_key']}',
          'x-email': '${jsonSettings['user_email']}',
        },
        body: body,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final hits = data['hits']?['hits'] as List?;
        final fields =
            workingLangs.map((l) => l.toLowerCase() + '_text').toList();
        setState(() {
          _searchResults =
              (hits ?? [])
                  .map((e) => Map<String, dynamic>.from(e['_source'] ?? {}))
                  .map(
                    (doc) => Map.fromEntries(
                      doc.entries.where(
                        (entry) =>
                            fields.contains(entry.key) ||
                            [
                              'concept_id',
                              'subject_field',
                              'term_types',
                              'reliability_codes',
                            ].contains(entry.key),
                      ),
                    ),
                  )
                  .toList();
        });
      } else {
        setState(() {
          _searchResults = [];
        });
      }
    } catch (e) {
      setState(() {
        _searchResults = [];
      });
    }
    setState(() => _searching = false);
  }

  String _fileContent = "Loading...";
  Timer? _pollingTimer;
  bool _isVisible = true;
  var lastFileContent = "";
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (jsonSettings["auto_lookup"] == true) {
      _sub1 = ingestServer.stream.listen((payload) {
        // Replace with your custom code
        print('HTTP Incoming: $payload');
        if (!mounted) return;
        print('HTTP Incoming: passed mounted test');
        _startPolling(payload);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling(payload) async {
    if (_isVisible || !_isVisible) {
      print("Timer triggered");

      httpPassAnalyzer = payload['source'] ?? '';

      _updateState(httpPassAnalyzer);
    }
  }

  void _updateState(content) async {
    setState(() {
      lastFileContent = httpPassAnalyzer;

      _fileContent = lastFileContent;
      //   List subsegments = subsegmentFile(_fileContent);

      nGrams = generateNGrams(httpPassAnalyzer, 5);
      nGrams.addAll(generateNGrams(_fileContent, 4));
      if (_fileContent.split(RegExp(r'[^\w\s]')).length <= 3)
        nGrams.addAll(generateNGrams(_fileContent, 3));
      if (_fileContent.split(RegExp(r'[^\w\s]')).length <= 2)
        nGrams.addAll(generateNGrams(_fileContent, 2));
      if (_fileContent.split(RegExp(r'[^\w\s]')).length <= 2)
        nGrams.addAll(_fileContent.split(RegExp(r'[^\w\s]')));

      print("NGrams: ${nGrams.length}");
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
                "fuzziness": "AUTO",
                "minimum_should_match": "65%",
              },
            },
            {
              "term": {"paragraphsNotMatched": false},
            },
          ],
        },
      },
      "size": 50,
    };
    //
    // await searchQuery(queryAnalyser, lastFileContent); //
    //await SearchTabWidget(queryName: "a",  queryText: "").processQuery(queryAnalyser);//
    //
    //
    //
    // var wholeSegment = search
    nGrams.insert(0, lastFileContent);
    // Use working langs from settings or UI, fallback to en/sk/cz
    List<String> workingLangs =
        [
          if (lang1 != null) lang1,
          if (lang2 != null) lang2,
          if (lang3 != null) lang3,
        ].where((l) => l != null && l != '').cast<String>().toList();
    nGramsResults = await searchNGrams(
      nGrams,
      workingLangs.isNotEmpty ? workingLangs : null,
    );
    nGramResultList =
        nGramsResults.entries.map((e) => "${e.key} => ${e.value}").toList();
    setState(() {}); // You may need to call setState again to update the UI
  }

  /// Splits the input string `content` into subsegments based on commas.
  ///
  /// Each non-empty segment found between commas in the input string
  /// is added to the list of subsegments. The resulting list of subsegments
  /// is returned.
  ///
  /// The function also prints the list of subsegments to the console.
  ///
  /// [content]: A string containing segments separated by commas.
  /// Returns: A list of non-empty subsegments extracted from the input string.

  List subsegmentFile(String content) {
    List<String> segments = content.split(','); //split at commas
    List<String> subsegments = [];
    for (String segment in segments) {
      if (segment.isNotEmpty) {
        subsegments.add(segment);
      }
    }
    print("Subsegments: $subsegments");
    return subsegments;
  }

  /// Generates a list of n-grams from a given text.
  ///
  /// An n-gram is a sequence of n consecutive words from the input text.
  /// The function splits the input text into words, then iterates over the
  /// list of words to generate sequences of n words. The resulting list of
  /// n-grams is returned.
  ///
  /// [text]: The input text from which n-grams are generated.
  /// [n]: The size of the n-grams to generate.
  /// Returns: A list of n-grams extracted from the input string.
  List<String> generateNGrams(String text, int n) {
    final words = text.split(' ');
    List<String> ngrams = [];
    for (int i = 0; i <= words.length - n; i++) {
      ngrams.add(words.sublist(i, i + n).join(' '));
    }
    return ngrams;
  }

  /* Future<String> _readFile() async {
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
*/
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isVisible = state == AppLifecycleState.resumed;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        /* Container(
          padding: EdgeInsets.all(16),
          color: Colors.blue[50],
          width: double.infinity,
          child: SelectableText(_fileContent, style: TextStyle(fontSize: 16)),
        ),
        SizedBox(height: 16),
       Text(activeIndex),*/
        SizedBox(height: 26),

        // --- IATE SEARCH FIELD ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search IATE Terminology',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _searchIateIndex(),
                ),
              ),
              SizedBox(width: 8),
              ElevatedButton(
                onPressed: _searching ? null : _searchIateIndex,
                child:
                    _searching
                        ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : Text('Search'),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        if (_searchResults.isNotEmpty)
          Expanded(
            child: ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, idx) {
                final doc = _searchResults[idx];
                // Use the same logic as _getDisplayedLangs from search.dart
                List<String> displayedLangs = [];
                void addIf(bool? display, String? lang) {
                  if ((display ?? false) && (lang != null) && lang.isNotEmpty) {
                    displayedLangs.add(lang);
                  }
                }

                addIf(jsonSettings['display_lang1'] as bool?, lang1);
                addIf(jsonSettings['display_lang2'] as bool?, lang2);
                addIf(jsonSettings['display_lang3'] as bool?, lang3);
                final langFields =
                    displayedLangs
                        .map((l) => l.toLowerCase() + '_text')
                        .toSet();
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Table(
                          columnWidths: const {0: IntrinsicColumnWidth()},
                          defaultVerticalAlignment:
                              TableCellVerticalAlignment.middle,
                          children: [
                            TableRow(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (doc['concept_id'] != null)
                                      Tooltip(
                                        message:
                                            'Open the term in IATE for full details and definitions',
                                        child: InkWell(
                                          onTap: () {
                                            final langPart =
                                                (displayedLangs.join(
                                                  '-',
                                                )).toLowerCase();
                                            final url =
                                                'https://iate.europa.eu/entry/result/${doc['concept_id']}/$langPart';
                                            launchUrl(Uri.parse(url));
                                          },
                                          child: SelectableText(
                                            'ID: ${doc['concept_id']}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (doc['subject_field'] != null)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 4.0,
                                        ),
                                        child: SelectableText(
                                          'Subject: ${doc['subject_field']}',
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            TableRow(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (
                                      var i = 0;
                                      i < displayedLangs.length;
                                      i++
                                    )
                                      if (doc[displayedLangs[i].toLowerCase() +
                                              '_text'] !=
                                          null)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 8.0,
                                            bottom: 2.0,
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${displayedLangs[i].toUpperCase()}: ',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              Expanded(
                                                child: SelectableText(
                                                  doc[displayedLangs[i]
                                                          .toLowerCase() +
                                                      '_text'],
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                  ],
                                ),
                              ],
                            ),
                            TableRow(
                              children: [
                                Row(
                                  children: [
                                    if (doc['term_types'] != null)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8.0,
                                          top: 4.0,
                                        ),
                                        child: SelectableText(
                                          'Types: ${doc['term_types']}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ),
                                    if (doc['reliability_codes'] != null)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 4.0,
                                        ),
                                        child: SelectableText(
                                          'Reliability: ${doc['reliability_codes']}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        SizedBox(height: 16),
        // (rest of your UI, e.g. nGram results)
      ],
    );
  }
}
