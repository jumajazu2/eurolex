import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:eurolex/processDOM.dart'; // Assuming this is your data processing widget

var resultsOS = [];
var decodedResults = [];
var skResults = [];
var enResults = [];
var czResults = [];

class SearchTabWidget extends StatefulWidget {
  const SearchTabWidget({Key? key}) : super(key: key);

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
    });

    print("Query: $query, Results = $skResults");

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
          child: ElevatedButton(
            onPressed: _startSearch,
            child: Text('Start Search'),
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
            itemCount: enResults.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        enResults.length > index ? enResults[index] : '',
                      ),
                    ),
                    Expanded(
                      child: Text(
                        skResults.length > index ? skResults[index] : '',
                      ),
                    ),
                    Expanded(
                      child: Text(
                        czResults.length > index ? czResults[index] : '',
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
