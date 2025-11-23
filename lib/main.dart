import 'package:eurolex/dataupload.dart';
import 'package:eurolex/file_handling.dart';
import 'package:eurolex/setup.dart';
import 'package:flutter/material.dart';
import 'package:eurolex/preparehtml.dart';
import 'package:eurolex/browseFiles.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:eurolex/browseFiles.dart';
import 'package:eurolex/search.dart';
import 'package:eurolex/analyser.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:eurolex/http.dart';

//String osServer = 'localhost:9200'; // add to Settings or Autolookup
String osServer = 'search.pts-translation.sk'; // AWS server
//String osServer = '192.168.1.14:9200';
List<String> indices = ['*'];

Map<String, dynamic> jsonSettings = {};
Map<String, dynamic> jsonConfig = {};
Map<String, dynamic> jsonData = {};
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
LocalIngestServer ingestServer = LocalIngestServer(port: 6175);

void main() {
  runApp(MaterialApp(navigatorKey: navigatorKey, home: MainTabbedApp()));
}

Future<void> startIngestServer() async {
  await ingestServer.start();
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
    _tabController = TabController(length: 5, vsync: this, initialIndex: 0);

    getListIndices(server).then((_) => setState(() {}));

    loadSettingsFromFile().then((_) {
      if (jsonSettings["access_key"] == "trial") {
        // Ensure a context exists
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) showTrialDialog();
        });
      }
    });

    startIngestServer().then((_) {
      ingestServer.stream.listen((payload) {
        print('Incoming Trados payload: $payload');
      });
    });
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
            Tab(text: 'Data Upload'),
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
          Center(child: indicesMaintenance()), // Replace with your Setup widget
          BrowseFilesWidget(),
          DataUploadPage(), // Replace with your Data rocess widget
        ],
      ),
    );
  }

  void showTrialDialog() {
    final ctx = navigatorKey.currentContext;
    print("ctx: $ctx");
    if (ctx == null) return;

    showDialog(
      context: ctx,
      barrierDismissible: true,
      builder:
          (_) => AlertDialog(
            title: const Text('App running in Trial Mode'),
            content: Text(
              '\nYou can use 7 free searches per day.\n\nFor unlimited access, go to Setup tab and enter Your Passkey or click "Purchase" to obtain a Passkey.\n',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
              TextButton(
                onPressed: () {
                  launchUrl(
                    Uri.parse('https://www.pts-translation.sk/#pricing'),
                    mode: LaunchMode.externalApplication,
                  );
                },
                child: const Text('Pricing'),
              ),
            ],
          ),
    );
  }
}
