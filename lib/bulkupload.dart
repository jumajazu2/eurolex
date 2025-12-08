import 'dart:ui';

import 'package:eurolex/browseFiles.dart';
import 'package:eurolex/preparehtml.dart';
import 'package:eurolex/processDOM.dart';
import 'package:eurolex/setup.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:html/parser.dart' as html_parser;

import 'dart:io';
import 'package:path_provider/path_provider.dart';

import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:eurolex/main.dart';
import 'package:path/path.dart' as path;
import 'package:eurolex/logger.dart';

bool debugMode = false; // global debug mode flag

class DataUploadTab extends StatefulWidget {
  const DataUploadTab({
    super.key,
    this.indices = const <String>[],
    this.initialSelectedIndex = '',
    this.isUploading = false,
    this.statusText = '',
    this.onRefreshIndices,
    this.onIndexChanged,
    this.onUploadPastedNdjson,
    this.onPickAndUploadFile,
  });

  // Data for UI
  final List<String> indices;
  final String initialSelectedIndex;

  // State from outside (e.g., to show progress/status)
  final bool isUploading;
  final String statusText;

  // Callbacks to plug logic later
  final VoidCallback? onRefreshIndices;
  final ValueChanged<String>? onIndexChanged;
  final Future<void> Function(String effectiveIndex, String ndjson)?
  onUploadPastedNdjson;
  final Future<void> Function(String effectiveIndex)? onPickAndUploadFile;

  @override
  State<DataUploadTab> createState() => _DataUploadTabState();
}

class _DataUploadTabState extends State<DataUploadTab> {
  final _pasteController = TextEditingController();
  final _manualIndexController = TextEditingController();
  final logger = LogManager(fileName: 'bulkupload.log');
  String _selectedIndex = '';
  bool simulateUpload = false;
  // checkbox state

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialSelectedIndex;
    getListIndices(server).then((_) {
      setState(() {
        // Refresh the UI after indices are loaded
      });
    });
  }

  String get _effectiveIndex {
    final manual = _manualIndexController.text.trim();
    if (manual.isNotEmpty) return manual;
    if (_selectedIndex.isNotEmpty) return _selectedIndex;
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final idxItems =
        widget.indices
            .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
            .toList();

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tool header and index selection UI
          Text(
            'Upload Eur-Lex Data Dump Files to OpenSearch',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 20),
          const Text(
            'First Choose Index In Dropdown List or Enter Index Name below!',
            style: TextStyle(fontSize: 16),
          ),

          const SizedBox(height: 20),
          InputDecorator(
            decoration: InputDecoration(
              labelText: 'Search Index',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: indices.contains(_selectedIndex) ? _selectedIndex : null,
                items:
                    indices
                        .map(
                          (value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    newIndexName = newValue ?? '';
                    _selectedIndex = newValue ?? '';
                  });
                  // Handle dropdown selection

                  // ignore: avoid_print
                  print('Selected index for bulk upload: $newValue');
                },
                hint: const Text('Choose existing index'),
              ),
            ),
          ),

          const SizedBox(height: 10),
          TextField(
            controller: _manualIndexController,
            decoration: const InputDecoration(
              labelText: 'Index Name (Press Enter to Confirm!):',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) {
              setState(() {
                final composed = '${userPasskey}_$value';
                _manualIndexController.text = composed;
                newIndexName = composed;
                _selectedIndex = newIndexName;

                print('Entered manual index name for bulk upload: $composed');
              });
            },
          ),

          const SizedBox(height: 8),
          (_selectedIndex.isEmpty || _selectedIndex == 'eurolex_')
              ? const Text('Enter Index Name First!')
              : Row(
                children: [
                  ElevatedButton(
                    onPressed: processBulk,
                    child: Text(
                      'Start Bulk Upload Process (Uploading to $_selectedIndex)',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Tooltip(
                    message:
                        'Simulate (all processing except uploading data to the OpenSearch server)',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: simulateUpload,
                          onChanged: (v) {
                            setState(() {
                              simulateUpload = v ?? false;
                            });
                          },
                        ),
                        const Text('Simulate'),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),
                  Tooltip(
                    message:
                        'Debug Mode: for each uploaded files, a JSON file with multilingual pairs will be created in the local "debug_output" folder, to troubleshoot mismatched paragraphs and other issues.',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: debugMode,
                          onChanged: (v) {
                            setState(() {
                              debugMode = v ?? false;
                            });
                          },
                        ),
                        const Text('Debug Mode'),
                      ],
                    ),
                  ),
                ],
              ),

          const SizedBox(height: 20),

          // Paste NDJSON area
          Text(
            'Paste NDJSON (OpenSearch _bulk format):',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: TextField(
              controller: _pasteController,
              maxLines: null,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '{ "index": {} }\n{ "field": "value" }\n…',
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Action buttons
          Row(
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.cloud_upload),
                label: const Text('Upload pasted NDJSON'),
                onPressed:
                    widget.onUploadPastedNdjson == null
                        ? null
                        : () => widget.onUploadPastedNdjson!.call(
                          _effectiveIndex,
                          _pasteController.text,
                        ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.upload_file),
                label: const Text('Pick file and upload'),
                onPressed: processBulk,
              ),
            ],
          ),

          const SizedBox(height: 12),

          if (widget.isUploading) const LinearProgressIndicator(),

          if (widget.statusText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                widget.statusText,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pasteController.dispose();
    _manualIndexController.dispose();
    super.dispose();
  }

  Future<void> processBulk() async {
    logger.log(
      "*****Started Bulk upload into $newIndexName ******/Simulate:$simulateUpload",
    );
  }
}

//manager function to scan directories and send files for processing before upload to OpenSearch
