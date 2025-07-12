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
List enHighlightedResults = [];

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
  final List<bool> _quickSettings = List.generate(5, (_) => false);
  final List<String> _results = [];

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
    var queryText = _searchController.text;

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

      className =
          hits.map((hit) => hit['_source']['class'].toString()).toList();

      docDate = hits.map((hit) => hit['_source']['date'].toString()).toList();
    });

    print("Query: $query, Results = $skResults");

    setState(() {});
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
      var enHighlight = highlightFoundWords(hit, queryWords);

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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search field with Enter key trigger
        Padding(
          padding: const EdgeInsets.all(8.0),
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
                onPressed: () {
                  // TODO: Add your third button functionality
                },
                child: Text('Button 3'),
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
                  Text('Q${index + 1}'),
                ],
              );
            }),
          ),
        ),
        // Results list
        Expanded(
          child: ListView.builder(
            itemCount: enHighlightedResults.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Row(
                  children: [
                    Expanded(
                      child: SelectableText.rich(
                        enHighlightedResults.length > index
                            ? enHighlightedResults[index]
                            : '',
                      ),
                    ),
                    Expanded(
                      child: SelectableText(
                        skResults.length > index ? skResults[index] : '',
                      ),
                    ),
                    Expanded(
                      child: SelectableText(
                        czResults.length > index ? czResults[index] : '',
                      ),
                    ),
                    Expanded(
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
                                docDate.length > index ? docDate[index] : '',
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

                          Row(children: [Text("Open content (dropdown)")]),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
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
    );
  }
}
