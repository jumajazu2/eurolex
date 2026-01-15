import 'dart:convert';
import 'dart:math';

import 'package:LegisTracerEU/file_handling.dart';
import 'package:LegisTracerEU/main.dart';
import 'package:LegisTracerEU/sparql.dart';
import 'package:flutter/material.dart';
import 'package:LegisTracerEU/processDOM.dart';
import 'package:LegisTracerEU/preparehtml.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:LegisTracerEU/ui_notices.dart';
import 'dart:async';
import 'dart:io';

import 'package:LegisTracerEU/logger.dart';

// Simple globals (no `library` / `part`).
// User
String userEmail = jsonSettings['user_email'] ?? '';
String userPasskey = jsonSettings['access_key'] ?? '';
// Working languages

class indicesMaintenance extends StatefulWidget {
  @override
  _indicesMaintenanceState createState() => _indicesMaintenanceState();
}

class _indicesMaintenanceState extends State<indicesMaintenance> {
  Future<void> _openFolder(String path) async {
    try {
      await Process.run('explorer', [path]);
    } catch (_) {
      try {
        await launchUrl(Uri.file(path));
      } catch (e) {
        // swallow
      }
    }
  }

  Future<void> _openLogsFolder() async {
    final logPath = await getFilePath(LogManager.fileName);
    final dirPath = File(logPath).parent.path;
    await _openFolder(dirPath);
  }

  Future<String?> _legacyLogsDir() async {
    final legacyLog = await getLegacyAppDataPathIfExists(LogManager.fileName);
    if (legacyLog == null) return null;
    return File(legacyLog).parent.path;
  }

  final _emailCtrl = TextEditingController(text: userEmail);
  final _passkeyCtrl = TextEditingController(text: userPasskey);
  String? _emailError;
  double _fontScale = 1.0;
  String _fontFamily = 'System';
  bool _autoScaleWithSystem = false;
  // Search results-only font scale (does not affect global UI)
  double _resultsFontScale = 1.0;
  // Update: hosted JSON endpoint (editable as needed)
  static const String updateInfoUrl =
      'https://www.pts-translation.sk/updateInfoUrl.json';

  @override
  void initState() {
    super.initState();
    // If loadSettingsFromFile is async, await it; otherwise wrap.
    Future(() async {
      await loadSettingsFromFile(); // adjust if non-async
      setState(() {
        userEmail = (jsonSettings['user_email'] ?? '').toString();
        print('userEmail loaded: $userEmail');
        _fontScale = ((jsonSettings['font_scale'] ?? 1.0) as num).toDouble();
        _fontFamily =
            (jsonSettings['font_family']?.toString().trim().isNotEmpty ?? false)
                ? jsonSettings['font_family'].toString()
                : 'System';
        _autoScaleWithSystem =
            (jsonSettings['auto_scale_with_system'] ?? false) == true;
        _resultsFontScale =
            ((jsonSettings['search_results_font_scale'] ?? 1.0) as num)
                .toDouble();
        final all =
            (langsEU ?? const <String>[])
                .map((e) => e.toUpperCase())
                .toSet()
                .toList(); // unique

        String? v1 = jsonSettings['lang1']?.toString().toUpperCase();
        String? v2 = jsonSettings['lang2']?.toString().toUpperCase();
        String? v3 = jsonSettings['lang3']?.toString().toUpperCase();

        if (!all.contains(v1)) v1 = null;
        if (!all.contains(v2)) v2 = null;
        if (!all.contains(v3)) v3 = null;

        lang1 = v1;
        lang2 = v2;
        lang3 = v3;
        _emailCtrl.text = userEmail;
      });
    });

    isAdminNotifier.addListener(() async {
      await getListIndicesFull(server, isAdminNotifier.value);
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passkeyCtrl.dispose();
    super.dispose();
    bool _showcaseStarted = false;
  }

  int _compareVersions(String a, String b) {
    // Split at '+' to separate main version and build number
    List<String> aParts = a.split('+');
    List<String> bParts = b.split('+');
    String aMain = aParts[0];
    String bMain = bParts[0];
    int aBuild = aParts.length > 1 ? int.tryParse(aParts[1]) ?? 0 : 0;
    int bBuild = bParts.length > 1 ? int.tryParse(bParts[1]) ?? 0 : 0;

    List<int> pa = aMain.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> pb = bMain.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final len = max(pa.length, pb.length);
    while (pa.length < len) pa.add(0);
    while (pb.length < len) pb.add(0);
    for (int i = 0; i < len; i++) {
      if (pa[i] < pb[i]) return -1;
      if (pa[i] > pb[i]) return 1;
    }
    // If main versions are equal, compare build numbers
    if (aBuild < bBuild) return -1;
    if (aBuild > bBuild) return 1;
    return 0;
  }

  String? _currentVersion;
  String? _availableVersion;
  bool _checkingUpdate = false;
  String? _updateError;

  bool _isValidEmail(String value) {
    if (value.isEmpty) return true; // allow blank, only format-check non-empty
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    return emailRegex.hasMatch(value);
  }

  Future<void> _checkForStoreUpdate() async {
    setState(() {
      _checkingUpdate = true;
      _updateError = null;
    });
    try {
      final resp = await http
          .get(Uri.parse(updateInfoUrl))
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) {
        setState(() {
          _updateError = 'Update check failed (${resp.statusCode})';
          _checkingUpdate = false;
        });
        return;
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final latest = (data['version'] ?? '').toString();
      final storeUrl =
          (data['storeUrl'] ?? 'https://apps.microsoft.com/detail/9NKNVGXJFSW5')
              .toString();

      final info = await PackageInfo.fromPlatform();
      final current = info.version;
      setState(() {
        _currentVersion = current;
        _availableVersion = latest;
        _checkingUpdate = false;
      });
      final cmp = _compareVersions(current, latest);
      if (cmp < 0) {
        final uri = Uri.parse(storeUrl);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('You’re up to date')));
      }
    } catch (e) {
      setState(() {
        _updateError = 'Update check error: $e';
        _checkingUpdate = false;
      });
    }
  }

  Future<void> _confirmSettings() async {
    userEmail = _emailCtrl.text.trim();
    userPasskey = _passkeyCtrl.text.trim();
    jsonSettings['user_email'] = userEmail;
    jsonSettings['access_key'] = userPasskey;
    if (lang1 != null) jsonSettings['lang1'] = lang1;
    if (lang2 != null) jsonSettings['lang2'] = lang2;
    if (lang3 != null) jsonSettings['lang3'] = lang3;

    final nowAdmin =
        _emailCtrl.text.trim().toLowerCase() == 'juraj.kuban.sk@gmail.com';
    isAdminNotifier.value = nowAdmin; // triggers tabs rebuild
    isAdmin = nowAdmin;

    if (!userPasskey.contains('trial') && userPasskey.isNotEmpty) {
      // Remove trial banner if exists
      ScaffoldMessenger.of(context).clearMaterialBanners();
    }
    if (userPasskey.contains('trial') || userPasskey.isEmpty) {
      // Show trial banner
      showBanner(
        context,
        message:
            "You are using Trial Mode. You have 7 free searches per day. For unlimited access, enter your Passkey in Setup tab or click Purchase Subscription to visit Pricing page.",
        dismisable: false,
        backgroundColor: Colors.orange.shade200,
      );
    }

    try {
      await writeSettingsToFile(jsonSettings);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Settings saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dropdown items from langsEU (assumed List<String> from main.dart)
    final itemValues =
        (langsEU ?? const <String>[])
            .map((e) => e.toUpperCase())
            .toSet()
            .toList();
    final items =
        itemValues
            .map((l) => DropdownMenuItem<String>(value: l, child: Text(l)))
            .toList();

    // Index dropdown for maintenance (if needed)

    //final isAdmin =  _emailCtrl.text.trim().toLowerCase() == 'juraj.kuban.sk@gmail.com';

    final isAdmin = isAdminNotifier.value;

    return Scaffold(
      // appBar: AppBar(title: const Text('Setup')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User + Languages on one line
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User section (left)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'User',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: _emailCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Email',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                  onChanged: (v) {
                                    final value = v.trim();
                                    final valid = _isValidEmail(value);
                                    setState(() {
                                      userEmail = value;
                                      jsonSettings['user_email'] = value;
                                      _emailError = valid
                                          ? null
                                          : 'Please enter a valid email address';
                                    });
                                  },
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  height: 16,
                                  child:
                                      _emailError == null
                                          ? const SizedBox.shrink()
                                          : Text(
                                            _emailError!,
                                            style: TextStyle(
                                              color:
                                                  Theme.of(context)
                                                      .colorScheme
                                                      .error,
                                              fontSize: 12,
                                            ),
                                          ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: _passkeyCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Passkey',
                                    border: OutlineInputBorder(),
                                  ),
                                  obscureText: false,
                                  onChanged: (v) => userPasskey = v,
                                ),
                                const SizedBox(height: 4),
                                const SizedBox(
                                  height: 16,
                                  // reserved space so it aligns vertically with the email field
                                  child: SizedBox.shrink(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Languages section (right)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Languages',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // 1) Lang 1
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: lang1,
                              items: items,
                              isExpanded: true, // fill available width
                              decoration: const InputDecoration(
                                labelText: 'Language 1',
                                border: OutlineInputBorder(),
                              ),
                              onChanged:
                                  (v) => setState(() {
                                    lang1 = v;
                                    jsonSettings['lang1'] = v;
                                  }),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // 2) Lang 2
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: lang2,
                              items: items,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Language 2',
                                border: OutlineInputBorder(),
                              ),
                              onChanged:
                                  (v) => setState(() {
                                    lang2 = v;
                                    jsonSettings['lang2'] = v;
                                  }),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // 3) Lang 3
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: lang3,
                              items: items,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Language 3',
                                border: OutlineInputBorder(),
                              ),
                              onChanged:
                                  (v) => setState(() {
                                    lang3 = v;
                                    jsonSettings['lang3'] = v;
                                  }),
                            ),
                          ),

                          // Move Confirm outside the three Expanded dropdowns
                          const SizedBox(width: 12),
                          OutlinedButton(
                            onPressed: () async {
                              await _confirmSettings();
                              await getListIndicesFull(
                                server,
                                isAdminNotifier.value,
                              );
                              if (mounted) {
                                setState(() {});
                              }
                            },
                            child: const Text('Confirm'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Text(
              'Appearance',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Text Size - All User Interface'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _fontScale,
                    min: 0.85,
                    max: 1.40,
                    divisions: 11,
                    label: _fontScale.toStringAsFixed(2),
                    onChanged: (v) {
                      setState(() => _fontScale = v);
                      jsonSettings['font_scale'] = v;
                      fontScaleNotifier.value = v;
                    },
                    onChangeEnd: (v) async {
                      try {
                        await writeSettingsToFile(jsonSettings);
                      } catch (_) {}
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Text('${(_fontScale * 100).round()}%'),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () async {
                    setState(() => _fontScale = 1.0);
                    jsonSettings['font_scale'] = 1.0;
                    fontScaleNotifier.value = 1.0;
                    try {
                      await writeSettingsToFile(jsonSettings);
                    } catch (_) {}
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Font size reset to default'),
                        ),
                      );
                    }
                  },
                  child: const Text('Restore default'),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Text('Text Size - Results Only'),
            const SizedBox(height: 8),
            // Search results-only font size slider
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _resultsFontScale,
                    min: 0.85,
                    max: 1.40,
                    divisions: 11,
                    label: _resultsFontScale.toStringAsFixed(2),
                    onChanged: (v) {
                      setState(() => _resultsFontScale = v);
                      jsonSettings['search_results_font_scale'] = v;
                      searchResultsFontScaleNotifier.value = v;
                    },
                    onChangeEnd: (v) async {
                      try {
                        await writeSettingsToFile(jsonSettings);
                      } catch (_) {}
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Text('${(_resultsFontScale * 100).round()}%'),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () async {
                    setState(() => _resultsFontScale = 1.0);
                    jsonSettings['search_results_font_scale'] = 1.0;
                    searchResultsFontScaleNotifier.value = 1.0;
                    try {
                      await writeSettingsToFile(jsonSettings);
                    } catch (_) {}
                  },
                  child: const Text('Restore results default'),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Font family'),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _fontFamily,
                  items:
                      const [
                            'System',
                            'Inter',
                            'Merriweather',
                            'Montserrat',
                            'Nunito',
                            'Source Serif 4',
                            'EB Garamond',
                            'Lexend',
                            'Noto Sans',
                          ]
                          .map(
                            (f) => DropdownMenuItem(value: f, child: Text(f)),
                          )
                          .toList(),
                  onChanged: (v) async {
                    if (v == null) return;
                    setState(() => _fontFamily = v);
                    jsonSettings['font_family'] = v;
                    fontFamilyNotifier.value = v;
                    try {
                      await writeSettingsToFile(jsonSettings);
                    } catch (_) {}
                  },
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () async {
                    setState(() => _fontFamily = 'System');
                    jsonSettings['font_family'] = 'System';
                    fontFamilyNotifier.value = 'System';
                    try {
                      await writeSettingsToFile(jsonSettings);
                    } catch (_) {}
                  },
                  child: const Text('System default'),
                ),
              ],
            ),

            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Auto scale with system text size'),

              contentPadding: EdgeInsets.zero,
              value: _autoScaleWithSystem,
              onChanged: (v) async {
                setState(() => _autoScaleWithSystem = v);
                jsonSettings['auto_scale_with_system'] = v;
                try {
                  await writeSettingsToFile(jsonSettings);
                } catch (_) {}
              },
            ),

            const SizedBox(height: 24),

            const Text(
              'Updates',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton(
                  onPressed: _checkingUpdate ? null : _checkForStoreUpdate,
                  child:
                      _checkingUpdate
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Text('Check for Store Update'),
                ),
                const SizedBox(width: 24),
                if (_currentVersion != null && _availableVersion != null)
                  SelectableText(
                    'Current: $_currentVersion, Available: $_availableVersion',
                  ),
                if (_updateError != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Text(
                      _updateError!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // Maintenance (admin only)
            const Text(
              'List of Indices for Maintenance',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // Index selection dropdown for maintenance (optional, if you want to allow switching)
            // The rest of the maintenance UI (unchanged)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: indicesFull.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, // Two columns
                childAspectRatio: 15, // Adjust for row height
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemBuilder: (BuildContext context, int index) {
                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    dense: true,
                    title: Row(
                      children: [
                        Text(
                          indicesFull[index][0],
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          ' (' + indicesFull[index][1] + ' ',
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          indicesFull[index][2] + ' units)',
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    trailing:
                        indicesFull[index][0].contains("sparql")
                            ? null
                            : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Info icon (available to both admin and owner)
                                IconButton(
                                  icon: const Icon(
                                    Icons.info_outline,
                                    size: 18,
                                  ),
                                  tooltip: 'Index details',
                                  onPressed: () {
                                    final name = indicesFull[index][0];
                                    final shardCount = indicesFull[index][1];
                                    final unitCount = indicesFull[index][2];

                                    showDialog(
                                      context: context,
                                      builder: (_) {
                                        String _filter = '';
                                        return AlertDialog(
                                          title: SelectableText(
                                            'Your Custom Index: $name',
                                          ),
                                          content: FutureBuilder<List<String>>(
                                            future: getDistinctCelexForIndex(
                                              name,
                                            ),
                                            builder: (ctx, snap) {
                                              final loading =
                                                  snap.connectionState ==
                                                  ConnectionState.waiting;
                                              final error = snap.hasError;
                                              final celexes =
                                                  snap.data ?? const <String>[];

                                              return SizedBox(
                                                width: 1200,
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Size: ${shardCount.toString().toUpperCase()}',
                                                    ),
                                                    Text('Units: $unitCount'),

                                                    const Divider(),
                                                    Text(
                                                      'Documents (${celexes.length}):',
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    if (loading)
                                                      const Padding(
                                                        padding:
                                                            EdgeInsets.only(
                                                              top: 8,
                                                            ),
                                                        child:
                                                            LinearProgressIndicator(),
                                                      ),
                                                    if (error)
                                                      const Padding(
                                                        padding:
                                                            EdgeInsets.only(
                                                              top: 8,
                                                            ),
                                                        child: Text(
                                                          'Failed to load CELEX list',
                                                        ),
                                                      ),
                                                    if (!loading && !error)
                                                      StatefulBuilder(
                                                        builder: (ctx2, setSB) {
                                                          final list =
                                                              _filter.isEmpty
                                                                  ? celexes
                                                                  : celexes
                                                                      .where(
                                                                        (e) => e
                                                                            .toLowerCase()
                                                                            .contains(
                                                                              _filter.toLowerCase(),
                                                                            ),
                                                                      )
                                                                      .toList();
                                                          return Column(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              TextField(
                                                                decoration: const InputDecoration(
                                                                  labelText:
                                                                      'Filter documents',
                                                                  isDense: true,
                                                                  border:
                                                                      OutlineInputBorder(),
                                                                ),
                                                                onChanged:
                                                                    (
                                                                      v,
                                                                    ) => setSB(
                                                                      () =>
                                                                          _filter =
                                                                              v,
                                                                    ),
                                                              ),
                                                              const SizedBox(
                                                                height: 8,
                                                              ),
                                                              SizedBox(
                                                                height: 400,
                                                                child:
                                                                    list.isEmpty
                                                                        ? const Center(
                                                                          child: Text(
                                                                            'No CELEX values found.',
                                                                          ),
                                                                        )
                                                                        : ListView.builder(
                                                                          itemCount:
                                                                              list.length,
                                                                          itemBuilder: (
                                                                            _,
                                                                            i,
                                                                          ) {
                                                                            final c =
                                                                                list[i];
                                                                            final d =
                                                                                '${i + 1}. $c';
                                                                            return ListTile(
                                                                              dense:
                                                                                  false,
                                                                              title: SelectableText(
                                                                                d,
                                                                              ),
                                                                            );
                                                                          },
                                                                        ),
                                                              ),
                                                            ],
                                                          );
                                                        },
                                                      ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed:
                                                  () =>
                                                      Navigator.of(
                                                        context,
                                                      ).pop(),
                                              child: const Text('Close'),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                ),

                                // Delete icon (admin or owner only)
                                if (isAdmin ||
                                    indicesFull[index][0].contains(userPasskey))
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      size: 18,
                                      color: Colors.redAccent,
                                    ),
                                    tooltip: 'Delete index',
                                    onPressed: () {
                                      setState(() {
                                        confirmAndDeleteOpenSearchIndex(
                                          context,
                                          indicesFull[index][0],
                                        ).then((_) {
                                          setState(() {
                                            getListIndicesFull(
                                              server,
                                              isAdmin,
                                            ).then((_) {
                                              setState(() {
                                                print(
                                                  "Indices reloaded details: $indicesFull",
                                                );
                                              });
                                            });
                                          });
                                        });
                                      });
                                    },
                                  ),
                              ],
                            ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'Current Settings saved in:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            FutureBuilder<String>(
              future: getFilePath('settings.json'),
              builder: (context, snapshot) {
                final text =
                    snapshot.hasData
                        ? snapshot.data!
                        : 'Resolving settings path...';
                return Text(text);
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton(
                  onPressed: _openLogsFolder,
                  child: const Text('Open Logs Folder'),
                ),
                const SizedBox(width: 12),
                FutureBuilder<String?>(
                  future: _legacyLogsDir(),
                  builder: (context, snap) {
                    if (!snap.hasData || snap.data == null) {
                      return const SizedBox.shrink();
                    }
                    return OutlinedButton(
                      onPressed: () => _openFolder(snap.data!),
                      child: const Text('Open Legacy Logs Folder'),
                    );
                  },
                ),
              ],
            ),
            if (isAdminNotifier.value) Text(jsonSettings.toString()),
          ],
        ),
      ),
    );
  }
}

Future<List<String>> getDistinctCelexForIndex(String index) async {
  final uri = Uri.parse('https://$osServer/$index/_search');

  final body = jsonEncode({
    "size": 0,
    "aggs": {
      "celexes": {
        "terms": {
          "field": "celex", // fallback to "celex" if no keyword sub-field
          "size": 10000, // raise if your index holds more unique docs
        },
      },
    },
  });

  try {
    final resp = await http
        .post(
          uri,
          headers: {
            "Content-Type": "application/json",
            "x-api-key": userPasskey,
            'x-email': '${jsonSettings['user_email']}',
          },
          body: body,
        )
        .timeout(const Duration(seconds: 15));

    print('CELEX fetch response status: ${resp.body}');
    if (resp.statusCode != 200) return [];

    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    final buckets =
        (decoded["aggregations"]?["celexes"]?["buckets"] as List?) ?? [];
    final preferredLang = (lang1 ?? 'EN').toUpperCase();
    final items = <String>[];

    for (final b in buckets) {
      final key = b['key']?.toString().toUpperCase();
      final count = b['doc_count'];
      if (key == null || count == null) continue;

      final titleMap = await fetchTitlesForCelex(key); // await the Future
      final title1 =
          titleMap[preferredLang] ??
          titleMap['EN'] ??
          (titleMap.isNotEmpty ? titleMap.values.first : '');

      final title2 = titleMap[lang2?.toUpperCase()] ?? '';

      items.add('$key ($count):\n$title1\n$title2');
    }

    return items;
  } catch (_) {
    return [];
  }
}
