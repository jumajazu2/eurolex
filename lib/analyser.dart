import 'dart:async';
import 'dart:io';
import 'package:eurolex/preparehtml.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:eurolex/search.dart';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;

var nGrams = [];
Map nGramsResults = {"N/A": "N/A"};
var nGramResultList = [];

class AnalyserWidget extends StatefulWidget {
  @override
  _FileDisplayWidgetState createState() => _FileDisplayWidgetState();
}

class _FileDisplayWidgetState extends State<AnalyserWidget>
    with WidgetsBindingObserver {
  String _fileContent = "Loading...";
  Timer? _pollingTimer;
  bool _isVisible = true;
  var lastFileContent = "";
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() async {
    _pollingTimer = Timer.periodic(Duration(milliseconds: 500), (timer) {
      if (_isVisible || !_isVisible) {
        print("Timer triggered");
        _readFile();
        if (_fileContent != lastFileContent) {
          print("File content changed, updating state");
          _updateState();
        } else {
          print("No change in file content");
        }
      }
    });
  }

  void _updateState() async {
    setState(() {
      lastFileContent = _fileContent;
      //   List subsegments = subsegmentFile(_fileContent);

      nGrams = generateNGrams(_fileContent, 5);
      nGrams.addAll(generateNGrams(_fileContent, 4));
      if (_fileContent.split(RegExp(r'[^\w\s]')).length <= 3)
        nGrams.addAll(generateNGrams(_fileContent, 3));
      if (_fileContent.split(RegExp(r'[^\w\s]')).length <= 2)
        nGrams.addAll(generateNGrams(_fileContent, 2));
      if (_fileContent.split(RegExp(r'[^\w\s]')).length <= 2)
        nGrams.addAll(_fileContent.split(RegExp(r'[^\w\s]')));

      print("NGrams: ${nGrams.length}");
    });

    nGramsResults = await searchNGrams(nGrams);
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16),
          color: Colors.blue[50],
          width: double.infinity,
          child: SelectableText(_fileContent, style: TextStyle(fontSize: 16)),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            /*
            Expanded(
              child: Container(
                height: 500,
                color: Colors.green[100],
                child: Center(
                  child: ListView.builder(
                    padding: EdgeInsets.all(8),
                    shrinkWrap: true,
                    itemCount: nGrams.length,
                    itemBuilder: (BuildContext context, int index) {
                      return ListTile(
                        title: SelectableText(nGrams[index]),
                        onTap: () {
                          // Handle tap on nGram
                          print("Tapped on nGram: ${nGrams[index]}");
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
            SizedBox(width: 8),
            */
            Expanded(
              child: Container(
                height: 500,
                color: Colors.orange[100],
                child: Center(
                  child: ListView.builder(
                    padding: EdgeInsets.all(8),
                    shrinkWrap: true,
                    itemCount: nGramResultList.length,
                    itemBuilder: (BuildContext context, int index) {
                      return !(nGramResultList[index].toString().contains(
                            "no match",
                          ))
                          ? ListTile(
                            title: SelectableText(nGramResultList[index]),
                            onTap: () {
                              // Handle tap on nGram
                              print(
                                "Tapped on nGram: ${nGramResultList[index]}",
                              );
                            },
                          )
                          : SizedBox.shrink();
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

Future<Map> searchNGrams(List<dynamic> ngrams) async {
  final opensearchUrl = Uri.parse("http://localhost:9200/eurolex4/_msearch");
  final headers = {"Content-Type": "application/x-ndjson"};

  // Step 1: Build NDJSON request body
  final buffer = StringBuffer();
  for (final ngram in ngrams) {
    buffer.writeln('{}'); // metadata line
    buffer.writeln(
      jsonEncode({
        "query": {
          "bool": {
            "must": [
              {
                "match_phrase": {
                  "en_text": {
                    "query": ngram,
                    // Allow some flexibility in word order
                    // Boost the phrase match
                  },
                },
              },
              {
                "term": {"paragraphsNotMatched": false},
              },
            ],
          },
        },
        "highlight": {
          "fields": {
            "en_text": {"type": "plain"},
          },
        },
        "size": 1, // Only top result
      }),
    );
  }
  print("Buffer content: ${buffer.toString()}");
  // Step 2: Send request

  if (buffer.isEmpty) {
    print("No ngrams to search, returning empty results.");
    return {};
  }
  final response = await http.post(
    opensearchUrl,
    headers: headers,
    body: buffer.toString(),
  );

  if (response.statusCode != 200) {
    print('Error from OpenSearch: ${response.statusCode}');
    print(response.body);
    return {"error": "Error: ${response.statusCode}"};
  }

  final jsonResponse = jsonDecode(response.body);
  print("JSON Response: $jsonResponse");
  // Step 3: Map responses to original ngrams
  final results = <String, String>{};

  final responses = jsonResponse['responses'] as List;
  for (int i = 0; i < responses.length; i++) {
    final ngram = ngrams[i] + " ";
    final hits = responses[i]['hits']['hits'] as List;
    if (hits.isNotEmpty) {
      var bestMatch = hits[0]['_source']['sk_text'];
      var bestMatchEN = hits[0]['_source']['en_text'];
      var highlightedString = hits[0]['highlight']['en_text']?.first ?? '';

      print("Highlighted string: $highlightedString, best match: $bestMatch");
      var highlightedStartOffset =
          (highlightedString.split('<em>')[0].length) - 30;
      if (highlightedStartOffset < 0) {
        highlightedStartOffset = 0;
      }
      var highlightedEndOffset = (highlightedString.lastIndexOf('</em>')) + 50;
      while (bestMatch[highlightedStartOffset] != " " &&
          highlightedStartOffset > 1) {
        print("Highlighted start offset: $highlightedStartOffset");
        highlightedStartOffset -= 1;
      }

      while (highlightedEndOffset < bestMatch.length &&
          bestMatch[highlightedEndOffset] != " ") {
        highlightedEndOffset += 1;
      }

      var bestMatchSub = bestMatch.substring(
        max(highlightedStartOffset, 0),
        min(highlightedEndOffset, (bestMatch.length)),
      );

      var bestMatchEnSub = bestMatchEN.substring(
        max(highlightedStartOffset, 0),
        min(highlightedEndOffset, (bestMatchEN.length)),
      );

      results[ngram] = bestMatchEnSub + " /// " + bestMatchSub;
    } else {
      results[ngram] = "<no match>";
    }
  }

  // Step 4: Output
  results.forEach((ngram, match) {
    print('N-gram: "$ngram" => Match: "$match"');
  });
  return results;
}
