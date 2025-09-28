import 'dart:convert';
import 'dart:math';

import 'package:eurolex/main.dart';
import 'package:flutter/material.dart';
import 'package:eurolex/processDOM.dart';
import 'package:eurolex/display.dart';
import 'package:eurolex/preparehtml.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:io';
import 'package:eurolex/file_handling.dart';

import 'package:path_provider/path_provider.dart';

var resultsOS = [];
var decodedResults = [];
var skResults = [];
var enResults = ["N/A"];
var czResults = [];
var metaCelex = [];
var metaCellar = [];
var sequenceNo;
var parNotMatched = ["N/A"];
var className;
var docDate;
var pointerPar;
var contextEnSkCz;
var queryText;
var queryPattern;
List enHighlightedResults = [];
var activeIndex = 'eurolex4';
var containsFilter = "";
var celexFilter = "";
var classFilter;
Key _searchKey = UniqueKey();
bool _isContentExpanded = false;
bool _autoAnalyse = false;
bool _matchedOnly = false;

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
  final List<bool> _quickSettings = List.generate(6, (_) => true);
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
        if (_fileContent != lastFileContent &&
            jsonSettings["auto_lookup"] == true) {
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

      _results.clear();

      enHighlightedResults.clear();
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
                "fields": ["en_text", "sk_text", "cz_text"],
                "fuzziness": "AUTO",
                "minimum_should_match": "70%",
              },
            },
          ],
        },
      },
      "size": 50,
    };

    processQuery(queryAnalyser, lastFileContent);

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

  void processQuery(query, searchTerm) async {
    queryPattern = query;

    var resultsOS = await sendToOpenSearch(
      'https://$osServer/$activeIndex/_search',
      [jsonEncode(query)],
    );
    var decodedResults = jsonDecode(resultsOS);

    //if query returns error, stop processing, display error
    if (decodedResults['error'] != null) {
      print("Error in OpenSearch response: ${decodedResults['error']}");

      setState(() {
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
        ];
      });

      return;
    }

    var hits = decodedResults['hits']['hits'] as List;

    setState(() {
      skResults =
          hits.map((hit) => hit['_source']['sk_text'].toString()).toList();
      enResults =
          hits.map((hit) => hit['_source']['en_text'].toString()).toList();
      czResults =
          hits.map((hit) => hit['_source']['cz_text'].toString()).toList();

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

    print("Query: $query, Results SK = $skResults");

    queryText = searchTerm; //_searchController.text;
    //converting the results to TextSpans for highlighting
    var queryWords =
        queryText
            .replaceAll(RegExp(r'[^\w\s]'), '') // remove punctuation
            .split(RegExp(r'\s+')) // split by whitespace
            .where((String word) => word.isNotEmpty) // remove empty entries
            .toList();

    print("Query Words: $queryWords");

    for (var hit in enResults) {
      var enHighlight = highlightFoundWords2(hit, queryWords);

      // You can store these highlights in a list or map if needed
      print("EN Highlight: $enHighlight");
      enHighlightedResults.add(enHighlight);
      print("EN Highlight: $enHighlight, $enHighlightedResults");
    }
    print(
      "EN Highlight all: ${enHighlightedResults.length}, $enHighlightedResults",
    );

    setState(() {});
  }

  void _startSearch() async {
    // TODO: Implement your search logic here
    setState(() {
      _results.clear();

      enHighlightedResults.clear();
    });
    var query = {
      "query": {
        "match_phrase": {
          "en_text": {
            "query": _searchController.text,
            "slop": 2, // Allow some flexibility in word order
            "boost": 1.5, // Boost the phrase match
          },
        },
      },
      "size": 50,
    };
    //var queryText = _searchController.text;

    processQuery(query, _searchController.text);
  }

  void _startSearch2() async {
    // TODO: Implement your search logic here
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
            "cz_text",
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
                "fields": ["en_text", "sk_text", "cz_text"],
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
        "fields": {"en_text": {}, "sk_text": {}, "cz_text": {}},
      },
    };

    processQuery(query2, _searchController.text);
  }

  void _startSearch3() async {
    // TODO: Implement your search logic here
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
                "en_text": {
                  "query": _searchController.text,
                  "slop": 2,
                  "boost": 3.0,
                },
              },
            },
            {
              "match": {
                "en_text": {
                  "query": _searchController.text,
                  "fuzziness": "AUTO",
                  "operator": "and",
                  "boost": 1.0,
                },
              },
            },
            {
              "match_phrase": {
                "sk_text": {
                  "query": _searchController.text,
                  "slop": 2,
                  "boost": 3.0,
                },
              },
            },
            {
              "match": {
                "sk_text": {
                  "query": _searchController.text,
                  "fuzziness": "AUTO",
                  "operator": "and",
                  "boost": 1.0,
                },
              },
            },
            {
              "match_phrase": {
                "cz_text": {
                  "query": _searchController.text,
                  "slop": 2,
                  "boost": 3.0,
                },
              },
            },
            {
              "match": {
                "cz_text": {
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

    processQuery(query, _searchController.text);
  }

  Color backgroundColor = Colors.white12;

  void updateDropdown() async {
    await getListIndices(server);
    setState(() {
      print(
        "Dropdown tapped and indices updated from server, indices: $indices.",
      );
    });
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
                        'Search Index ($osServer)', // Label embedded in the frame
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
                          indices.contains(activeIndex)
                              ? activeIndex
                              : null, // Default selected value
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: _startSearch,
                child: Text('Search (match_phrase)'),
              ),
              ElevatedButton(
                onPressed: _startSearch2,
                child: Text('Search (multi_match)'),
              ),
              ElevatedButton(
                onPressed: _startSearch3,
                child: Text('Search (match+matchphrase)'),
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

              Row(
                children: [
                  Checkbox(
                    tristate: true,
                    value: jsonSettings['display_lang1'],
                    onChanged: (bool? newValue) {
                      setState(() {
                        jsonSettings['display_lang1'] = newValue ?? false;
                        writeSettingsToFile(jsonSettings);
                        print(
                          "checkbox" + jsonSettings['display_lang1'].toString(),
                        );
                      });
                    },
                  ),
                  Text(
                    jsonSettings['lang1'] ?? "N/A",
                    style: TextStyle(
                      fontSize: 16,
                    ), // Optional: Adjust the font size
                  ),

                  Checkbox(
                    tristate: true,
                    value: jsonSettings['display_lang2'],
                    onChanged: (bool? newValue) {
                      setState(() {
                        jsonSettings['display_lang2'] = newValue ?? false;
                        writeSettingsToFile(jsonSettings);
                        print(
                          "checkbox" + jsonSettings['display_lang2'].toString(),
                        );
                      });
                    },
                  ),
                  Text(
                    jsonSettings['lang2'] ?? "N/A",
                    style: TextStyle(
                      fontSize: 16,
                    ), // Optional: Adjust the font size
                  ),

                  Checkbox(
                    tristate: true,
                    value: jsonSettings['display_lang3'],
                    onChanged: (bool? newValue) {
                      setState(() {
                        jsonSettings['display_lang3'] = newValue ?? false;
                        writeSettingsToFile(jsonSettings);
                        print(
                          "checkbox" + jsonSettings['display_lang3'].toString(),
                        );
                      });
                    },
                  ),
                  Text(
                    jsonSettings['lang3'] ?? "N/A",
                    style: TextStyle(
                      fontSize: 16,
                    ), // Optional: Adjust the font size
                  ),
                  Checkbox(
                    tristate: true,
                    value: _matchedOnly,
                    onChanged: (bool? newValue) {
                      setState(() {
                        _matchedOnly = newValue ?? false;

                        print("checkbox " + _matchedOnly.toString());
                      });
                    },
                  ),
                  Text(
                    'Aligned',
                    style: TextStyle(
                      fontSize: 16,
                    ), // Optional: Adjust the font size
                  ),
                  Checkbox(
                    tristate: true,
                    value: jsonSettings['display_meta'],
                    onChanged: (bool? newValue) {
                      setState(() {
                        jsonSettings['display_meta'] = newValue ?? false;
                        writeSettingsToFile(jsonSettings);
                        print(
                          "checkbox " + jsonSettings['display_meta'].toString(),
                        );
                      });
                    },
                  ),
                  Text(
                    'Meta',
                    style: TextStyle(
                      fontSize: 16,
                    ), // Optional: Adjust the font size
                  ),

                  Checkbox(
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

        // Quick settings checkboxes
        Container(
          color: const Color.fromARGB(200, 210, 238, 241),
          child: ExpansionTile(
            title:
                (celexFilter.isNotEmpty || containsFilter.isNotEmpty)
                    ? Row(
                      children: [
                        Icon(Icons.filter_alt, color: Colors.orange),
                        SizedBox(width: 8),
                        Text("Query Details: ${enResults.length} result(s)"),
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
                    : Text("Query Details: ${enResults.length} result(s)"),
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Query Text: $queryPattern',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Query Result: $decodedResults',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
        ),

        SizedBox(height: 10),
        Divider(color: Colors.grey[300], thickness: 5),
        // Results list
        Expanded(
          child: ListView.builder(
            itemCount: enHighlightedResults.length,
            itemBuilder: (context, index) {
              return ((enResults.isNotEmpty &&
                              index < enResults.length &&
                              enResults[index].toLowerCase().contains(
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
                          !_quickSettings[4]))
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
                                    child: SelectableText.rich(
                                      style: TextStyle(fontSize: 18.0),
                                      enHighlightedResults.length > index
                                          ? enHighlightedResults[index]
                                          : TextSpan(),
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
                                    child: SelectableText(
                                      style: TextStyle(fontSize: 18.0),
                                      skResults.length > index
                                          ? skResults[index]
                                          : '',
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
                                    child: SelectableText(
                                      style: TextStyle(fontSize: 18.0),
                                      czResults.length > index
                                          ? czResults[index]
                                          : '',
                                    ),
                                  ),
                                )
                                : SizedBox.shrink(),
                            jsonSettings['display_meta']
                                ? Expanded(
                                  flex: 2, // Metadata column is narrower
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
                                            Flexible(
                                              child: SelectableText(
                                                metaCelex.length > index
                                                    ? metaCelex[index]
                                                    : '',
                                                // overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        // If you want to show czResults here as well, add another widget:
                                        Row(
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

                                        Row(
                                          children: [
                                            Text("Date: "),
                                            Flexible(
                                              child: SelectableText(
                                                docDate.length > index
                                                    ? docDate[index]
                                                    : '',
                                                //  overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),

                                        Row(
                                          children: [
                                            Text("Class: "),
                                            Flexible(
                                              child: SelectableText(
                                                className.length > index
                                                    ? className[index]
                                                    : '',
                                                // overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            Text("Unmatched paragraphs: "),
                                            Flexible(
                                              child: SelectableText(
                                                parNotMatched.length > index
                                                    ? parNotMatched[index]
                                                    : '',
                                                // overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),

                                        Row(
                                          children: [
                                            Text("Open URL: "),
                                            GestureDetector(
                                              onTap: () {
                                                // Handle the tap event here, e.g. open the link in a browser
                                                launchUrl(
                                                  Uri.parse(
                                                    'http://eur-lex.europa.eu/legal-content/EN-SK/TXT/?uri=CELEX:${metaCelex[index]}',
                                                  ),
                                                );
                                              },
                                              child: Text(
                                                'EN-SK',
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
                                                    'http://eur-lex.europa.eu/legal-content/EN-CS/TXT/?uri=CELEX:${metaCelex[index]}',
                                                  ),
                                                );
                                              },
                                              child: Text(
                                                'EN-CZ',
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
                                                          ? contextEnSkCz[0][index]
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
                                                          ? contextEnSkCz[1][index]
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
                                                          ? contextEnSkCz[2][index]
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
