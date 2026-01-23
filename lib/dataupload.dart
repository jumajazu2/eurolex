import 'package:LegisTracerEU/preparehtml.dart';
import 'package:flutter/material.dart';

import 'package:LegisTracerEU/bulkupload.dart';

class DataUploadPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: Column(
          children: [
            // TabBar at the top
            TabBar(
              tabs: [
                Tab(
                  child: Text(
                    'Upload Celex Numbers',
                    style: TextStyle(fontSize: 14), // Set the desired font size
                  ),
                ),
                Tab(
                  child: Text(
                    'Upload List of References',
                    style: TextStyle(fontSize: 14), // Set the desired font size
                  ),
                ),
                Tab(
                  child: Text(
                    'Upload Trados Studio Alignment (TMX)',
                    style: TextStyle(fontSize: 14), // Set the desired font size
                  ),
                ),
              ],
            ),
            // TabBarView for tab content
            Expanded(
              child: TabBarView(
                children: [
                  Center(child: manualCelexList()),
                  Center(child: FilePickerButton2()),
                  Center(child: DataUploadTab()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
