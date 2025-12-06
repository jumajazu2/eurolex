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
import 'package:eurolex/opensearch.dart';

//String osServer = 'localhost:9200'; // add to Settings or Autolookup
String osServer = 'search.pts-translation.sk'; // AWS server
//String osServer = '192.168.1.14:9200';
List<String> indices = ['*'];
List<List<String>> indicesFull = [];

Map<String, dynamic> jsonSettings = {};
Map<String, dynamic> jsonConfig = {};
Map<String, dynamic> jsonData = {};
String? lang1;
String? lang2;
String? lang3;
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
LocalIngestServer ingestServer = LocalIngestServer(port: 6175);

final isAdminNotifier = ValueNotifier<bool>(isAdmin);

bool isAdmin = false;
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

    _tabController.addListener(() {
      // Setup tab is index 2 (third tab)
      if (_tabController.indexIsChanging && _tabController.index == 2) {
        // Run your code here
        print("Setup tab clicked!");
        // For example, reload indices or settings
        getListIndicesFull(server).then((_) {
          setState(() {
            print("Indices loaded details: $indicesFull");
          });
        });
      }
    });

    getListIndices(server).then((_) {
      setState(() {
        print("Indices loaded: $indices");
      });
    });
    loadSettingsFromFile().then((_) {
      if (jsonSettings["access_key"] == "trial") {
        // Ensure a context exists
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) showTrialDialog();
        });
      }
      lang1 = jsonSettings['lang1']?.toString().toUpperCase();
      lang2 = jsonSettings['lang2']?.toString().toUpperCase();
      lang3 = jsonSettings['lang3']?.toString().toUpperCase();
    });
    isAdmin =
        jsonSettings['user_email']?.toString().toLowerCase() ==
        'juraj.kuban.sk@gmail.com';

    startIngestServer().then((_) {
      ingestServer.onRequest = (payload) async {
        // Your search logic here
        // Return a Map<String, dynamic>
        return <String, dynamic>{}; // Return an empty map or your actual result
      };
    });

    /*  startIngestServer().then((_) {
      ingestServer.stream.listen((payload) {
        print('Incoming Trados payload: $payload');
      });
    });*/
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isAdminNotifier,
      builder: (_, isAdmin, __) {
        return DefaultTabController(
          key: ValueKey(isAdmin), // recreate controller on admin flip
          length: isAdmin ? 5 : 4, // tab count depends on admin
          child: Scaffold(
            appBar: AppBar(
              toolbarHeight: 1,
              bottom: TabBar(
                onTap: (index) {
                  // Setup tab is index 2 in both modes
                  if (index == 2) {
                    print("Setup tab clicked!");
                    getListIndicesFull(server).then((_) {
                      setState(() {
                        print("Indices loaded details: $indicesFull");
                      });
                    });
                  }
                },
                tabs: _buildTabs(isAdmin),
              ),
            ),
            body: TabBarView(children: _buildTabViews(isAdmin)),
          ),
        );
      },
    );
  }

  List<Widget> _buildTabs(bool isAdmin) => [
    const Tab(text: 'Search'),
    const Tab(text: 'Auto Analyser'),
    const Tab(text: 'Setup'),
    if (isAdmin) const Tab(text: 'Data Process'),
    const Tab(text: 'Data Upload'),
  ];

  List<Widget> _buildTabViews(bool isAdmin) => [
    Center(child: SearchTabWidget(queryText: "", queryName: "")),
    Center(child: AnalyserWidget()),
    Center(child: indicesMaintenance()),
    if (isAdmin) BrowseFilesWidget(),
    DataUploadPage(),
  ];

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

Future<void> confirmAndDeleteOpenSearchIndex(
  BuildContext context,
  String index,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder:
        (context) => AlertDialog(
          title: Text('Delete Index'),
          content: Text(
            'Do you really want to delete Index "$index"? This is irreversible and the index will be permanently deleted and all data in it lost.',
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
  );

  if (confirmed == true) {
    await deleteOpenSearchIndex(index);
  }
}
