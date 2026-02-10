import 'package:LegisTracerEU/dataupload.dart';
import 'package:LegisTracerEU/file_handling.dart';
import 'package:LegisTracerEU/setup.dart';
import 'package:LegisTracerEU/splash.dart';
import 'package:LegisTracerEU/ui_notices.dart';
import 'package:flutter/material.dart';
import 'package:LegisTracerEU/preparehtml.dart';
import 'package:LegisTracerEU/browseFiles.dart';

import 'package:LegisTracerEU/search.dart';
import 'package:LegisTracerEU/analyser.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:LegisTracerEU/http.dart';
import 'package:LegisTracerEU/opensearch.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

import 'package:LegisTracerEU/version_check.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:LegisTracerEU/support.dart';
import 'dart:io';

enum AppTheme { light, vivid, blue, dark }

final themeNames = {
  AppTheme.light: 'Light',
  AppTheme.vivid: 'Vivid',
  AppTheme.blue: 'Blue',
  AppTheme.dark: 'Dark',
};

final appThemes = {
  AppTheme.light: ThemeData(
    brightness: Brightness.light,
    primaryColor: Color(0xFF277BBB),
    colorScheme: ColorScheme.light(
      primary: Color(0xFF277BBB),
      secondary: Color(0xFF0E5895),
      tertiary: Color(0xFFF28C28),
    ),
    scaffoldBackgroundColor: Color(0xFFF5F7FA),
    appBarTheme: AppBarTheme(backgroundColor: Color(0xFF277BBB)),
  ),
  AppTheme.vivid: ThemeData(
    brightness: Brightness.light,
    primaryColor: Color(0xFFFF6F61),
    colorScheme: ColorScheme.light(
      primary: Color(0xFFFF6F61),
      secondary: Color(0xFFFFB347),
    ),
    scaffoldBackgroundColor: Color(0xFFF5F7FA),
    appBarTheme: AppBarTheme(backgroundColor: Color(0xFFFF6F61)),
  ),
  AppTheme.blue: ThemeData(
    brightness: Brightness.light,
    primaryColor: Color(0xFF1976D2),
    colorScheme: ColorScheme.light(
      primary: Color(0xFF1976D2),
      secondary: Color(0xFF64B5F6),
    ),
    scaffoldBackgroundColor: Color(0xFFF5F7FA),
    appBarTheme: AppBarTheme(backgroundColor: Color(0xFF1976D2)),
  ),
  AppTheme.dark: ThemeData(
    brightness: Brightness.dark,
    primaryColor: Color(0xFF22223B),
    colorScheme: ColorScheme.dark(
      primary: Color(0xFF22223B),
      secondary: Color(0xFF4A4E69),
    ),
    scaffoldBackgroundColor: Color(0xFF232946),
    appBarTheme: AppBarTheme(backgroundColor: Color(0xFF22223B)),
  ),
};

final ValueNotifier<AppTheme> appThemeNotifier = ValueNotifier<AppTheme>(
  AppTheme.light,
);

//String osServer = 'localhost:9200'; // add to Settings or Autolookup
String osServer = 'search.pts-translation.sk';

List<String> indices = ['*'];
List<List<String>> indicesFull = [];

const String DEFAULT_ACCESS_KEY = 'trial';

Map<String, dynamic> jsonSettings = {};
Map<String, dynamic> jsonConfig = {};
Map<String, dynamic> jsonData = {};
String? lang1;
String? lang2;
String? lang3;
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final ValueNotifier<double> fontScaleNotifier = ValueNotifier<double>(1.0);
// Font scale used only for Search results list/table
final ValueNotifier<double> searchResultsFontScaleNotifier =
    ValueNotifier<double>(1.0);
final ValueNotifier<String> fontFamilyNotifier = ValueNotifier<String>(
  'System',
);
LocalIngestServer ingestServer = LocalIngestServer(port: 6175);

String? deviceId;

final isAdminNotifier = ValueNotifier<bool>(isAdmin);

bool isAdmin = false;
bool adminUIEnabled =
    false; // Toggle to disable admin UI even when logged in as admin - defaults to false for security
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Swallow narrow classes of noisy errors in debug: clipboard PlatformExceptions
  // and a known HardwareKeyboard KeyUp mismatch assertion on Windows.
  FlutterError.onError = (FlutterErrorDetails details) {
    final error = details.exception;
    final stack = details.stack ?? StackTrace.empty;
    final message = details.exceptionAsString();
    if (_shouldIgnoreError(error, stack, message)) {
      debugPrint('Ignored benign error: $message');
      return;
    }
    FlutterError.presentError(details);
  };

  WidgetsBinding.instance.platformDispatcher.onError = (
    Object error,
    StackTrace stack,
  ) {
    if (_shouldIgnoreError(error, stack, error.toString())) {
      debugPrint('Ignored benign error: $error');
      return true; // handled
    }
    return false; // not handled
  };
  try {
    // Ensure runtime fetching works even if AssetManifest.* isn't available
    GoogleFonts.config.allowRuntimeFetching = true;
  } catch (_) {}
  _initDeviceId().then((_) {
    runApp(
      MaterialApp(
        navigatorKey: navigatorKey,
        theme: appThemes[AppTheme.light],
        builder: (context, child) {
          return ValueListenableBuilder<double>(
            valueListenable: fontScaleNotifier,
            builder: (context, scale, _) {
              return ValueListenableBuilder<String>(
                valueListenable: fontFamilyNotifier,
                builder: (context, family, __) {
                  // Use MediaQuery to scale all text globally (affects explicit sizes too)
                  final mq = MediaQuery.of(context);
                  final s = scale.clamp(0.8, 1.6);

                  // Apply selected font family to current theme while preserving colors and M3
                  final baseTheme = Theme.of(context);
                  final appliedTextTheme = _applyFontFamily(
                    baseTheme.textTheme,
                    family,
                  );

                  return MediaQuery(
                    data: mq.copyWith(textScaler: TextScaler.linear(s)),
                    child: Theme(
                      data: baseTheme.copyWith(textTheme: appliedTextTheme),
                      child: child!,
                    ),
                  );
                },
              );
            },
          );
        },
        home: MainTabbedApp(),
      ),
    );
  });
}

bool _shouldIgnoreError(Object error, StackTrace stack, String message) {
  final s = stack.toString();

  // 1) Clipboard-related PlatformExceptions during paste
  if (error is PlatformException) {
    if (s.contains('clipboard.dart') ||
        (s.contains('editable_text.dart') && s.contains('pasteText')) ||
        s.contains('JSONMethodCodec.decodeEnvelope')) {
      return true;
    }
  }

  // 2) HardwareKeyboard KeyUp mismatch assertion (debug-only)
  //    "Failed assertion: ... _pressedKeys.containsKey(event.physicalKey)"
  if (message.contains('hardware_keyboard.dart') &&
      (message.contains('_pressedKeys.containsKey') ||
          message.contains('KeyUpEvent is dispatched') ||
          s.contains('hardware_keyboard.dart'))) {
    return true;
  }

  return false;
}

Future<void> _initDeviceId() async {
  try {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isWindows) {
      final win = await deviceInfo.windowsInfo;
      deviceId = win.deviceId;
    } else if (Platform.isLinux) {
      final linux = await deviceInfo.linuxInfo;
      deviceId = linux.machineId;
    } else if (Platform.isMacOS) {
      final mac = await deviceInfo.macOsInfo;
      deviceId = mac.systemGUID;
    } else if (Platform.isAndroid) {
      final android = await deviceInfo.androidInfo;
      deviceId = android.id;
    } else if (Platform.isIOS) {
      final ios = await deviceInfo.iosInfo;
      deviceId = ios.identifierForVendor;
    } else {
      deviceId = null;
    }
    print('Device ID: ' + (deviceId ?? 'null'));
  } catch (e) {
    deviceId = null;
    print('Failed to get device ID: $e');
  }
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
    _checkForUpdate();
    // Show splash screen as dialog on first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: navigatorKey.currentContext ?? context,
        barrierDismissible: false,
        builder: (_) => SplashScreen(),
      );
      Future.delayed(const Duration(seconds: 3), () {
        if (navigatorKey.currentContext != null) {
          Navigator.of(navigatorKey.currentContext!).pop();
        } else {
          Navigator.of(context).pop();
        }
      });
    });
    /*/   _tabController = TabController(length: 5, vsync: this, initialIndex: 0);

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
*/
    loadSettingsFromFile().then((_) {
      final accessKey = (jsonSettings['access_key'] ?? '').toString();
      final savedEmail = (jsonSettings['user_email'] ?? '').toString().trim();

      if (accessKey == 'trial') {
        // Ensure a context exists
        WidgetsBinding.instance.addPostFrameCallback((_) {
          //  if (mounted) showTrialDialog();
          if (mounted)
            showBanner(
              context,
              message:
                  "You are using Trial Mode. You have 7 free searches per day. For unlimited access, enter your Passkey in Setup tab or click Purchase Subscription to visit Pricing page.",
              dismisable: false,
              backgroundColor: Colors.orange.shade200,
            );
        });
      }

      // If first startup without email, prompt for email once
      if (savedEmail.isEmpty && mounted) {
        // Delay slightly so the splash dialog (closed after 3s) is gone
        Future.delayed(const Duration(milliseconds: 3500), () {
          if (!mounted) return;
          final ctx = navigatorKey.currentContext ?? context;
          if (ctx == null) return;
          showDialog(
            context: ctx,
            barrierDismissible: false,
            builder: (dCtx) {
              final ctrl = TextEditingController(text: savedEmail);
              String? error;
              bool isValid(String value) {
                if (value.trim().isEmpty) return false;
                final re = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                return re.hasMatch(value.trim());
              }

              return StatefulBuilder(
                builder: (dCtx, setSB) {
                  return PopScope(
                    canPop: false,
                    child: AlertDialog(
                      title: const Text('Enter your email'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Please enter the email you use for access, even in Trial Mode. It helps identify your account for support and licensing.\n By providing your email, you agree that we may send you service-related information and offers.',
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: ctrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              border: const OutlineInputBorder(),
                              errorText: error,
                            ),
                            onChanged: (v) {
                              setSB(() {
                                error =
                                    isValid(v)
                                        ? null
                                        : 'Please enter a valid email address';
                              });
                            },
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () async {
                            final v = ctrl.text.trim();
                            if (!isValid(v)) {
                              setSB(() {
                                error = 'Please enter a valid email address';
                              });
                              return;
                            }
                            jsonSettings['user_email'] = v;
                            userEmail = v;
                            try {
                              await writeSettingsToFile(jsonSettings);
                            } catch (_) {}
                            if (dCtx.mounted) Navigator.of(dCtx).pop();
                          },
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        });
      }

      lang1 = jsonSettings['lang1']?.toString().toUpperCase();
      lang2 = jsonSettings['lang2']?.toString().toUpperCase();
      lang3 = jsonSettings['lang3']?.toString().toUpperCase();
      isAdmin =
          jsonSettings['user_email']?.toString().toLowerCase() ==
          'juraj.kuban.sk@gmail.com';
      adminUIEnabled = jsonSettings['admin_ui_enabled'] ?? false;
      isAdminNotifier.value = isAdmin && adminUIEnabled;
      print("isAdmin: $isAdmin, adminUIEnabled: $adminUIEnabled");

      // Initialize font scale from settings
      final fs = jsonSettings['font_scale'];
      if (fs is num) fontScaleNotifier.value = fs.toDouble();

      // Initialize font family from settings
      final ff = jsonSettings['font_family'];
      if (ff is String && ff.trim().isNotEmpty) {
        fontFamilyNotifier.value = ff;
      } else {
        fontFamilyNotifier.value = 'System';
      }

      // Load indices after settings are loaded so isAdmin and access_key are available
      getCustomIndices(
        server,
        isAdmin,
        jsonSettings['access_key'] ?? DEFAULT_ACCESS_KEY,
      ).then((_) {
        if (mounted) {
          setState(() {
            print("Indices loaded FULL: $indices for isAdmin: $isAdmin");
            getListIndicesFull(server, isAdmin);
          });
        }
      });
    });

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

  void _checkForUpdate() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version + "+" + info.buildNumber;
      print('[VersionCheck] Current app version: $currentVersion');
      final latest = await fetchLatestAppVersion();
      print('[VersionCheck] Latest version fetched: $latest');
      if (latest != null) {
        final isNewer = _isNewerVersion(latest, currentVersion);
        print('[VersionCheck] Is newer version available? $isNewer');
        if (isNewer) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            print('[VersionCheck] Showing update banner for version $latest');
            showBanner(
              context,
              message:
                  'A new version ($latest) is available! Please update your current version ($currentVersion) for the latest features and fixes.',
              dismisable: true,
              backgroundColor: Colors.lightBlue.shade100,
              actions: [
                TextButton(
                  onPressed: () {
                    print(
                      '[VersionCheck] Update button pressed, opening download page',
                    );
                    launchUrl(
                      Uri.parse(
                        'https://apps.microsoft.com/detail/9NKNVGXJFSW5',
                      ),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                  child: const Text('Update'),
                ),
                TextButton(
                  onPressed: () {
                    print(
                      '[VersionCheck] Dismiss button pressed, hiding banner',
                    );
                    ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
                  },
                  child: const Text('Dismiss'),
                ),
              ],
            );
          });
        }
      }
    } catch (e) {
      print('[VersionCheck] Error during version check: $e');
    }
  }

  // Returns true if v1 > v2
  bool _isNewerVersion(String v1, String v2) {
    List<int> parse(String v) =>
        v.split('+')[0].split('.').map(int.parse).toList();
    final a = parse(v1);
    final b = parse(v2);
    for (int i = 0; i < a.length && i < b.length; i++) {
      if (a[i] > b[i]) return true;
      if (a[i] < b[i]) return false;
    }
    return a.length > b.length;
  }

  @override
  void dispose() {
    // Only dispose if _tabController is initialized
    try {
      _tabController.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isAdminNotifier,
      builder: (_, isAdmin, __) {
        return DefaultTabController(
          key: ValueKey(isAdmin), // recreate controller on admin flip
          length: isAdmin ? 5 : 4, // tab count depends on isAdmin
          child: Scaffold(
            appBar: AppBar(
              toolbarHeight: 1,
              bottom: TabBar(
                indicatorColor: Color(0xFF277BBB),
                labelColor: Color(0xFFF5F7FA),
                unselectedLabelColor: Color(0xFFF5F7FA).withOpacity(0.7),
                labelStyle: TextStyle(fontWeight: FontWeight.bold),
                unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal),
                onTap: (index) {
                  // Refresh indices when switching tabs to ensure correct filtering
                  getCustomIndices(
                    server,
                    isAdmin,
                    jsonSettings['access_key'] ?? DEFAULT_ACCESS_KEY,
                  ).then((_) {
                    if (mounted) {
                      setState(() {
                        print(
                          "Tab $index switched - Indices refreshed: $indices for isAdmin: $isAdmin",
                        );
                      });
                    }
                  });

                  // Setup tab is index 2 in both modes
                  if (index == 2) {
                    print("Setup tab clicked!");
                    getListIndicesFull(server, isAdmin).then((_) {
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
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
            floatingActionButton: FloatingActionButton.small(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SupportForm()),
                );
              },
              child: const Icon(Icons.help_outline),
              tooltip: 'Report a problem',
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildTabs(bool isAdmin) => [
    Tab(child: Text('Search', style: TextStyle(fontSize: 16.8))),
    Tab(child: Text('IATE Terminology', style: TextStyle(fontSize: 16.8))),
    Tab(child: Text('Setup', style: TextStyle(fontSize: 16.8))),
    if (isAdmin)
      Tab(child: Text('Data Process', style: TextStyle(fontSize: 16.8))),
    Tab(child: Text('Upload References', style: TextStyle(fontSize: 16.8))),
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

TextTheme _applyFontFamily(TextTheme base, String family) {
  switch (family) {
    case 'Inter':
      return GoogleFonts.interTextTheme(base);
    case 'Merriweather':
      return GoogleFonts.merriweatherTextTheme(base);
    case 'Montserrat':
      return GoogleFonts.montserratTextTheme(base);
    case 'Nunito':
      return GoogleFonts.nunitoTextTheme(base);
    case 'Source Serif 4':
      return GoogleFonts.sourceSerif4TextTheme(base);
    case 'EB Garamond':
      return GoogleFonts.ebGaramondTextTheme(base);
    case 'Lexend':
      return GoogleFonts.lexendTextTheme(base);
    case 'Noto Sans':
      return GoogleFonts.notoSansTextTheme(base);
    case 'System':
    default:
      return base;
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
          title: Text('Delete Collection'),
          content: Text(
            'Do you really want to delete Collection "$index"? This is irreversible and the collection will be permanently deleted and all data in it lost.',
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
