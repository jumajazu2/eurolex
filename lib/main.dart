import 'package:flutter/material.dart';
import 'package:eurolex/preparehtml.dart';
import 'package:eurolex/browseFiles.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:eurolex/browseFiles.dart';
import 'package:eurolex/search.dart';
import 'package:eurolex/analyser.dart';

void main() {
  runApp(MaterialApp(home: MainTabbedApp()));
}

class MainTabbedApp extends StatefulWidget {
  @override
  _MainTabbedAppState createState() => _MainTabbedAppState();
}

class _MainTabbedAppState extends State<MainTabbedApp>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: 0,
    ); // Search tab first
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 1,

        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Search'),
            Tab(text: 'Auto Analyser'),
            Tab(text: 'Setup'),
            Tab(text: 'Data Process'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          Center(
            child: SearchTabWidget(queryText: "", queryName: ""),
          ), // Replace with your Search widget
          Center(
            child: AnalyserWidget(),
          ), // Replace with your Auto Analyser widget
          Center(child: Text('Setup Tab')), // Replace with your Setup widget
          BrowseFilesWidget(), // Replace with your Data rocess widget
        ],
      ),
    );
  }
}
