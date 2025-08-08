import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:eurolex/processDOM.dart';
import 'package:eurolex/display.dart';

var resultsOS = [];
var decodedResults = [];
var skResults = [];
var enResults = [];
var czResults = [];
var metaCelex = [];
var metaCellar = [];
var sequenceNo;
var parNotMatched;
var className;
var docDate;
var pointerPar;
var contextEnSkCz;
var queryText;
var queryPattern;
List enHighlightedResults = [];
var activeIndex = 'imported';

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

class _SearchTabWidgetState extends State<SearchTabWidget> {
  final TextEditingController _searchController = TextEditingController();
  final List<bool> _quickSettings = List.generate(5, (_) => true);
  final List<String> _results = [];

  void processQuery(query, searchTerm) async {
    queryPattern = query;

    var resultsOS = await sendToOpenSearch(
      'http://localhost:9200/$activeIndex/_search',
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

    print("Query: $query, Results = $skResults");

    queryText = _searchController.text;
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

    /*
    var resultsOS = await sendToOpenSearch(
      'http://localhost:9200/eurolex4/_search',
      [jsonEncode(query)],
    );
    var decodedResults = jsonDecode(resultsOS);

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

    print("Query: $query, Results = $skResults");

    queryText = _searchController.text;
    //converting the results to TextSpans for highlighting
    var queryWords =
        queryText
            .replaceAll(RegExp(r'[^\w\s]'), '') // remove punctuation
            .split(RegExp(r'\s+')) // split by whitespace
            .where((word) => word.isNotEmpty) // remove empty entries
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
*/
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

    /*
    var resultsOS = await sendToOpenSearch(
      'http://localhost:9200/eurolex4/_search',
      [jsonEncode(query)],
    );
    var decodedResults = jsonDecode(resultsOS);

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

    print("Query: $query, Results = ${skResults.length}");

    var queryText = _searchController.text;
    //converting the results to TextSpans for highlighting
    var queryWords =
        queryText
            .replaceAll(RegExp(r'[^\w\s]'), '') // remove punctuation
            .split(RegExp(r'\s+')) // split by whitespace
            .where((word) => word.isNotEmpty) // remove empty entries
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


    */
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
                  onSubmitted: (value) => _startSearch(),
                ),
              ),
              SizedBox(
                width: 30,
              ), // Add some spacing between the TextField and the dropdown
              // Dropdown taking about 1/10 of the space
              Flexible(
                flex: 1, // 1/10 of the row
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Search Index', // Label embedded in the frame
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
                      value: activeIndex, // Default selected value
                      items:
                          <String>['eurolex4', 'imported'].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
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
                child: Text('Start Search (match_phrase)'),
              ),
              ElevatedButton(
                onPressed: _startSearch2,
                child: Text('Start Search (multi_match)'),
              ),
              ElevatedButton(
                onPressed: _startSearch3,
                child: Text('Start Search (match+matchphrase)'),
              ),
            ],
          ),
        ),
        // Quick settings checkboxes
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(5, (index) {
              return Row(
                children: [
                  Checkbox(
                    value: _quickSettings[index],
                    onChanged: (val) {
                      setState(() {
                        _quickSettings[index] = val ?? false;
                      });
                    },
                  ),
                  index == 0 ? Text('EN') : SizedBox.shrink(),
                  index == 1 ? Text('SK') : SizedBox.shrink(),
                  index == 2 ? Text('CZ') : SizedBox.shrink(),
                  index == 3 ? Text('Metadata') : SizedBox.shrink(),
                ],
              );
            }),
          ),
        ),

        Container(
          color: const Color.fromARGB(200, 210, 238, 241),
          child: ExpansionTile(
            title: const Text("Query Details"),
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
                  'Results Count: ${enResults.length}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
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
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10.0,
                  vertical: 5.0,
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _quickSettings[0]
                            ? Expanded(
                              child: SelectableText.rich(
                                style: TextStyle(fontSize: 18.0),
                                enHighlightedResults.length > index
                                    ? enHighlightedResults[index]
                                    : '',
                              ),
                            )
                            : SizedBox.shrink(),

                        _quickSettings[1]
                            ? Expanded(
                              child: SelectableText(
                                style: TextStyle(fontSize: 18.0),
                                skResults.length > index
                                    ? skResults[index]
                                    : '',
                              ),
                            )
                            : SizedBox.shrink(),
                        _quickSettings[2]
                            ? Expanded(
                              child: SelectableText(
                                style: TextStyle(fontSize: 18.0),
                                czResults.length > index
                                    ? czResults[index]
                                    : '',
                              ),
                            )
                            : SizedBox.shrink(),
                        _quickSettings[3]
                            ? Expanded(
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Text("Celex: "),
                                      SelectableText(
                                        metaCelex.length > index
                                            ? metaCelex[index]
                                            : '',
                                      ),
                                    ],
                                  ),
                                  // If you want to show czResults here as well, add another widget:
                                  Row(
                                    children: [
                                      Text("Cellar: "),
                                      SelectableText(
                                        metaCellar.length > index
                                            ? metaCellar[index]
                                            : '',
                                      ),
                                    ],
                                  ),

                                  Row(
                                    children: [
                                      Text("Date: "),
                                      SelectableText(
                                        docDate.length > index
                                            ? docDate[index]
                                            : '',
                                      ),
                                    ],
                                  ),

                                  Row(
                                    children: [
                                      Text("Class: "),
                                      SelectableText(
                                        className.length > index
                                            ? className[index]
                                            : '',
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Text("Unmatched paragraphs: "),
                                      SelectableText(
                                        parNotMatched.length > index
                                            ? parNotMatched[index]
                                            : '',
                                      ),
                                    ],
                                  ),

                                  Row(
                                    children: [
                                      Text("Open full document: EN-SK, EN-CZ"),
                                    ],
                                  ),

                                  Row(
                                    children: [Text("Open content (dropdown)")],
                                  ),
                                ],
                              ),
                            )
                            : SizedBox.shrink(),
                      ],
                    ),

                    Container(
                      color: const Color.fromARGB(200, 210, 238, 241),
                      child: ExpansionTile(
                        title: const Text("Open content"),
                        onExpansionChanged: (bool expanded) {
                          if (expanded) {
                            // Wrap the async call in an anonymous async function
                            () async {
                              final result = await getContext(
                                metaCellar[index],
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
                                          Expanded(
                                            child: SelectableText(
                                              style: TextStyle(fontSize: 18.0),
                                              contextEnSkCz[0].length > index
                                                  ? contextEnSkCz[0][index]
                                                  : '',
                                            ),
                                          ),
                                          Expanded(
                                            child: SelectableText(
                                              style: TextStyle(fontSize: 18.0),
                                              contextEnSkCz[1].length > index
                                                  ? contextEnSkCz[1][index]
                                                  : '',
                                            ),
                                          ),
                                          Expanded(
                                            child: SelectableText(
                                              style: TextStyle(fontSize: 18.0),
                                              contextEnSkCz[2].length > index
                                                  ? contextEnSkCz[2][index]
                                                  : '',
                                            ),
                                          ),

                                          Expanded(
                                            child: SelectableText(
                                              style: TextStyle(fontSize: 18.0),
                                              '',
                                            ),
                                          ),
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
                    Padding(
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
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
