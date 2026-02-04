import 'package:LegisTracerEU/preparehtml.dart';
import 'package:LegisTracerEU/main.dart';
import 'package:flutter/material.dart';

import 'package:LegisTracerEU/bulkupload.dart';

class DataUploadPage extends StatefulWidget {
  @override
  State<DataUploadPage> createState() => _DataUploadPageState();
}

class _DataUploadPageState extends State<DataUploadPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      // Reset state when tab changes
      setState(() {
        // Reset global variables used by tabs
        newIndexName = '';
        manualCelex = [];
        fileContent2 = '';
        extractedCelex.clear();
        celexNumbersExtracted.clear();
      });
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // TabBar at the top
          TabBar(
            controller: _tabController,
            tabs: [
              Tab(
                child: Text(
                  'Upload Celex Numbers',
                  style: TextStyle(fontSize: 14),
                ),
              ),
              Tab(
                child: Text(
                  'Upload List of References',
                  style: TextStyle(fontSize: 14),
                ),
              ),
              Tab(
                child: Text(
                  'Upload Trados Studio Alignment (TMX)',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          // TabBarView for tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                Center(child: manualCelexList()),
                Center(child: FilePickerButton2()),
                Center(child: DataUploadTab(indices: indices)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
