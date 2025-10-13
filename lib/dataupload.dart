import 'dart:ui';

import 'package:eurolex/browseFiles.dart';
import 'package:eurolex/preparehtml.dart';
import 'package:eurolex/processDOM.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:html/parser.dart' as html_parser;

import 'dart:io';
import 'package:path_provider/path_provider.dart';

import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:eurolex/main.dart';
import 'package:path/path.dart' as path;
import 'package:eurolex/bulkupload.dart';

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
                    'Upload from Celex Numbers',
                    style: TextStyle(fontSize: 14), // Set the desired font size
                  ),
                ),
                Tab(
                  child: Text(
                    'Upload from List of References',
                    style: TextStyle(fontSize: 14), // Set the desired font size
                  ),
                ),
                Tab(
                  child: Text(
                    'Upload Eur-LexData Dump Files',
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
