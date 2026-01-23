import 'dart:ui';
import 'dart:io';
import 'dart:convert';

import 'package:LegisTracerEU/preparehtml.dart';
import 'package:LegisTracerEU/setup.dart';
import 'package:LegisTracerEU/tmx_parser.dart';
import 'package:LegisTracerEU/processDOM.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;

import 'package:LegisTracerEU/main.dart';
import 'package:LegisTracerEU/logger.dart';

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
  String? _indexError;
  // checkbox state

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialSelectedIndex;
    getCustomIndices(
      server,
      isAdmin,
      jsonSettings['access_key'] ?? DEFAULT_ACCESS_KEY,
    ).then((_) {
      if (mounted) {
        setState(() {
          // Refresh the UI after indices are loaded
        });
      }
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
            'You can upload your own references documents and search in them',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 20),
          const Text(
            'First Choose Index In Dropdown List or Enter Index Name below.\nThen select TMX files or other reference documents to upload.',
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
                value:
                    indices.contains(_selectedIndex)
                        ? _selectedIndex
                        : indices.first,
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
            decoration: InputDecoration(
              labelText:
                  'Index Name (Press Enter to Confirm - Allowed: a-z, 0-9, dot, underscore, hyphen. Cannot start with _ , - , +)',
              border: const OutlineInputBorder(),
              errorText: _indexError,
            ),
            inputFormatters: <TextInputFormatter>[
              // Allow only letters, digits, dot, underscore, hyphen (we will lowercase)
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9._-]')),
              TextInputFormatter.withFunction((oldValue, newValue) {
                return newValue.copyWith(text: newValue.text.toLowerCase());
              }),
            ],
            onChanged: (value) {
              if (_indexError != null) setState(() => _indexError = null);
            },
            onSubmitted: (value) {
              setState(() {
                final err = _validateIndexName(value, userPasskey);
                if (err != null) {
                  _indexError = err;
                  return;
                }
                final composed = 'eu_${userPasskey}_${value.trim()}';
                _manualIndexController.text = composed;
                newIndexName = composed;
                _selectedIndex = newIndexName;
                _indexError = null;
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
            'THIS FEATURE IS CURRENTLY UNAVAILABLE DUE TO MAINTENANCE \nCheck back later soon.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.orange,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            //   style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),

          const SizedBox(height: 10),

          // Action buttons
          Row(
            children: [
              /*   ElevatedButton.icon(
                icon: const Icon(Icons.cloud_upload),
                label: const Text('Upload pasted NDJSON'),
                onPressed:
                    widget.onUploadPastedNdjson == null
                        ? null
                        : () => widget.onUploadPastedNdjson!.call(
                          _effectiveIndex,
                          _pasteController.text,
                        ),
              )*/
              const SizedBox(width: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.upload_file),
                label: const Text('Pick TMX/Reference file and upload'),
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

  String? _validateIndexName(String base, String userPrefix) {
    if (base.isEmpty) return 'Index name is required.';
    final value = base.trim();
    if (value == '.' || value == '..') return 'Cannot be \'.\' or \'..\'.';
    if (RegExp(r'[A-Z]').hasMatch(value)) return 'Use lowercase letters only.';
    if (RegExp(r'^[_\-+]').hasMatch(value)) {
      return 'Cannot start with _ , - , or +.';
    }
    if (!RegExp(r'^[a-z0-9._-]+$').hasMatch(value)) {
      return 'Allowed: a-z, 0-9, dot, underscore, hyphen.';
    }
    final full = 'eu_${userPrefix}_$value';
    if (full.length > 255) return 'Full index name too long (max 255 chars).';
    return null;
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

    // Open file picker dialog
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['tmx', 'xml', 'html', 'htm'],
      withData: true,
    );

    if (result == null) {
      logger.log('No file selected');
      return;
    }

    final filePath = result.files.single.path;
    final fileName = result.files.single.name;

    if (filePath == null) {
      logger.log('ERROR: File path is null');
      if (!mounted) return;
      setState(() {
        // Show error in UI
      });
      return;
    }

    logger.log('Selected file: $fileName at $filePath');

    // Check file extension to determine file type
    final extension = path.extension(fileName).toLowerCase();

    if (extension == '.tmx' ||
        (extension == '.xml' && fileName.toLowerCase().contains('tmx'))) {
      await _processTmxFile(filePath, fileName);
    } else {
      logger.log(
        'Unsupported file type: $extension. Currently only TMX files are supported.',
      );
      if (!mounted) return;
      setState(() {
        // Show error in UI about unsupported file type
      });
    }
  }

  Future<void> _processTmxFile(String filePath, String fileName) async {
    try {
      logger.log('Processing TMX file: $fileName');

      // Read the file
      final file = File(filePath);
      if (!await file.exists()) {
        logger.log('ERROR: File does not exist: $filePath');
        return;
      }

      final bytes = await file.readAsBytes();
      final content = utf8.decode(bytes, allowMalformed: true);

      // Parse TMX content
      final tmxParser = TmxParser(
        logFileName: 'logs/${fileSafeStamp}_${_selectedIndex}_tmx.log',
      );

      final parsedData = tmxParser.parseTmxContent(content, fileName);

      if (parsedData.isEmpty) {
        logger.log('ERROR: No valid translation units found in TMX file');
        return;
      }

      // Get statistics
      final stats = tmxParser.getStatistics(parsedData);
      logger.log('TMX Statistics: ${jsonEncode(stats)}');
      print(
        'TMX parsed: ${stats['total_entries']} entries, '
        'Languages: ${(stats['languages'] as List).join(", ")}',
      );

      // Upload to OpenSearch if not simulating
      if (!simulateUpload) {
        logger.log('Uploading ${parsedData.length} entries to $_selectedIndex');
        await _uploadTmxToOpenSearch(parsedData, _selectedIndex);
      } else {
        logger.log(
          'SIMULATION MODE: Would upload ${parsedData.length} entries',
        );
      }

      // Debug mode: save JSON file
      if (debugMode) {
        await _saveTmxDebugFile(parsedData, fileName);
      }

      logger.log('TMX processing completed successfully');

      // Refresh indices
      await getCustomIndices(
        server,
        isAdmin,
        jsonSettings['access_key'] ?? DEFAULT_ACCESS_KEY,
      );

      if (!mounted) return;
      setState(() {
        // Update UI to show completion
      });
    } catch (e) {
      logger.log('ERROR processing TMX file: $e');
      print('Error processing TMX file: $e');
    }
  }

  Future<void> _uploadTmxToOpenSearch(
    List<Map<String, dynamic>> tmxData,
    String indexName,
  ) async {
    try {
      // Use the existing openSearchUpload function from processDOM
      openSearchUpload(tmxData, indexName);
      logger.log('Successfully uploaded TMX data to OpenSearch');
    } catch (e) {
      logger.log('ERROR uploading to OpenSearch: $e');
      rethrow;
    }
  }

  Future<void> _saveTmxDebugFile(
    List<Map<String, dynamic>> tmxData,
    String originalFileName,
  ) async {
    try {
      final debugDir = Directory('debug_output');
      if (!await debugDir.exists()) {
        await debugDir.create(recursive: true);
      }

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final debugFileName =
          'tmx_${path.basenameWithoutExtension(originalFileName)}_$timestamp.json';
      final debugFile = File(path.join(debugDir.path, debugFileName));

      final jsonOutput = const JsonEncoder.withIndent('  ').convert(tmxData);
      await debugFile.writeAsString(jsonOutput);

      logger.log('Debug file saved: ${debugFile.path}');
      print('Debug JSON saved to: ${debugFile.path}');
    } catch (e) {
      logger.log('ERROR saving debug file: $e');
    }
  }
}

//manager function to scan directories and send files for processing before upload to OpenSearch
