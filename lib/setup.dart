import 'dart:convert';
import 'dart:math';

import 'package:eurolex/file_handling.dart';
import 'package:eurolex/main.dart';
import 'package:eurolex/opensearch.dart';
import 'package:flutter/material.dart';
import 'package:eurolex/processDOM.dart';
import 'package:eurolex/display.dart';
import 'package:eurolex/preparehtml.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
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

  @override
  void initState() {
    super.initState();
    // If loadSettingsFromFile is async, await it; otherwise wrap.
    Future(() async {
      await loadSettingsFromFile(); // adjust if non-async
      setState(() {
        userEmail = (jsonSettings['user_email'] ?? '').toString();
        print('userEmail loaded: $userEmail');
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

    final isAdmin =
        _emailCtrl.text.trim().toLowerCase() == 'juraj.kuban.sk@gmail.com';

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
                              value: lang1,
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
                              value: lang2,
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
                              value: lang3,
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
                            onPressed: _confirmSettings,
                            child: const Text('Confirm'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Maintenance (admin only)
            if (isAdmin) ...[
              const Text(
                'Maintenance',
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
                              : IconButton(
                                icon: const Icon(Icons.delete, size: 18),
                                onPressed: () {
                                  setState(() {
                                    confirmAndDeleteOpenSearchIndex(
                                      context,
                                      indicesFull[index][0],
                                    ).then((_) {
                                      setState(() {
                                        getListIndicesFull(server).then((_) {
                                          setState(() {
                                            print(
                                              "Indices reloaded details: $indicesFull",
                                            );
                                          });
                                        });
                                      });
                                    });
                                  });
                                  setState(() {
                                    getListIndicesFull(server).then((_) {
                                      setState(() {
                                        print(
                                          "Indices reloaded details: $indicesFull",
                                        );
                                      });
                                    });
                                  });
                                },
                              ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              const Text(
                'Current Settings JSON saved in:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(File(getFilePath('settings.json')).path),
              Text(jsonSettings.toString()),
            ],
          ],
        ),
      ),
    );
  }
}
