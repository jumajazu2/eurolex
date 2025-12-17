import 'dart:convert';
import 'dart:math';

import 'package:LegisTracerEU/file_handling.dart';
import 'package:LegisTracerEU/main.dart';
import 'package:LegisTracerEU/opensearch.dart';
import 'package:LegisTracerEU/sparql.dart';
import 'package:flutter/material.dart';
import 'package:LegisTracerEU/processDOM.dart';
import 'package:LegisTracerEU/display.dart';
import 'package:LegisTracerEU/preparehtml.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:LegisTracerEU/ui_notices.dart';
import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
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
  final _emailCtrl = TextEditingController(text: userEmail);
  final _passkeyCtrl = TextEditingController(text: userPasskey);
  double _fontScale = 1.0;
  String _fontFamily = 'System';

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
                            child: TextField(
                              controller: _emailCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              onChanged: (v) {
                                userEmail = v;
                                jsonSettings['user_email'] = v;
                                // no setState here
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _passkeyCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Passkey',
                                border: OutlineInputBorder(),
                              ),
                              obscureText: false,
                              onChanged: (v) => userPasskey = v,
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
                          ElevatedButton(
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

            const SizedBox(height: 24),

            // Maintenance (admin only)
            const Text(
              'List of Indices for Maintenance',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
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
            Text(File(getFilePath('settings.json')).path),
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
          "field":
              "celex.keyword", // fallback to "celex" if no keyword sub-field
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
    if (resp.statusCode != 200) return [];

    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    final buckets =
        (decoded["aggregations"]?["celexes"]?["buckets"] as List?) ?? [];
    final preferredLang = (lang1 ?? 'EN').toUpperCase();
    final items = <String>[];

    for (final b in buckets) {
      final key = b['key']?.toString();
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
