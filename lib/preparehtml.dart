//import 'dart:nativewrappers/_internal/vm/lib/internal_patch.dart';
import 'dart:ui';

import 'package:LegisTracerEU/browseFiles.dart';
import 'package:LegisTracerEU/file_handling.dart';
import 'package:LegisTracerEU/processDOM.dart';
import 'package:LegisTracerEU/search.dart';
import 'package:LegisTracerEU/setup.dart';
import 'package:flutter/material.dart';
import 'dart:convert';

import 'package:html/parser.dart' as html_parser;

import 'dart:io';
import 'package:LegisTracerEU/logger.dart';
import 'package:LegisTracerEU/testHtmlDumps.dart';
import 'package:LegisTracerEU/harvest_progress.dart';
import 'package:LegisTracerEU/harvest_progress_ui.dart';
import 'package:LegisTracerEU/opensearch.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:LegisTracerEU/main.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart';

String fileContentSK = '';
String fileContentEN = '';
String fileContentCZ = '';
String metadata = '';
String fileContent = '';
String fileContent2 = '';
String fileName = '...';
String jsonOutput = '';
var fileSK_DOM;
var fileEN_DOM;
var fileCZ_DOM;
var fileDOM2;
var celexNumbersExtracted = [];
List<String> extractedCelex = [];
var manualEextractedCelex = [''];
var newIndexName = '';
List<String> manualCelex = [];
//List<String> indices = ['*'];
var server = 'https://$osServer';
var manualServer;
var celexRefs;
List<String> customIndices = [];

//purpose: load File 1 containing SK in file name, then load File 2 containing EN in file name

class FilePickerButton extends StatefulWidget {
  @override
  _FilePickerButtonState createState() => _FilePickerButtonState();
}

class _FilePickerButtonState extends State<FilePickerButton> {
  double _progress = 0.01;

  void _recalcProgress() {
    // Count loaded parts (SK, EN, CZ, metadata optional)
    final parts = [
      fileContentSK.isNotEmpty,
      fileContentEN.isNotEmpty,
      fileContentCZ.isNotEmpty,
      metadata.isNotEmpty,
    ];
    final loaded = parts.where((e) => e).length;
    _progress = loaded / parts.length;
  }

  // Function to open file picker and load the file content
  Future<void> pickAndLoadFile() async {
    // Open file picker dialog
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    print(result);

    if (result != null) {
      // Get the file path
      String filePath = result.files.single.path!;
      fileName = path.basename(filePath);

      // Read the content of the file
      File file = File(filePath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        String content = utf8.decode(bytes, allowMalformed: true);
        print('File content loaded successfully: $content');
        if (!mounted) return;
        setState(()
        // Update the state with the file content
        {
          fileContent = content;
          print('File content loaded successfully: $fileContent');

          if (fileName.contains('SK')) {
            // If the file name contains 'SK', save it to a specific location
            fileContentSK = "$fileName + @@@ + $content";
            // Store the content for SK files
          } else if (fileName.contains('EN')) {
            // If the file name contains 'EN', save it to a specific location
            fileContentEN = "$fileName + @@@ + $content";
          } else if (fileName.contains('CZ')) {
            // If the file name contains 'CZ', save it to a specific location
            fileContentCZ = "$fileName + @@@ + $content";
          } else if (fileName.contains('.rdf')) {
            // If the file name contains 'CZ', save it to a specific location
            metadata = content;
          } else {
            print("File does not match SK, EN, CZ or MTD criteria.");
          }

          _recalcProgress();

          if (fileContentSK.isNotEmpty && fileContentEN.isNotEmpty) {
            // If both SK and EN files are loaded, parse the HTML content
            fileEN_DOM = html_parser.parse(fileContentEN);
            fileSK_DOM = html_parser.parse(fileContentSK);
            print('Files EN SK parsed successfully.');

            var paragraphsEN = fileEN_DOM.getElementsByTagName('p');
            /*
            for (var index = 0; index < paragraphsEN.length; index++) {
              print(paragraphsEN[index].text);
            }
            var resultPen = paragraphsEN[9].attributes;
            print("resultPen: $resultPen");
*/
            //insert button that starts processing of DOM on press
          } else if (fileContentSK.isEmpty || fileContentEN.isEmpty) {
            fileContent = 'No valid SK or EN file content loaded.';
          }
        });
      } else {
        print("File does not exist!");
      }
    } else {
      print("No file selected.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // ...existing code...
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: pickAndLoadFile,
            child: const Text('Pick File'),
          ),
          const SizedBox(height: 12),
          if (_progress > 0 && _progress < 1)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(value: _progress),
                const SizedBox(height: 4),
                Text('${(_progress * 100).floor()}%'),
              ],
            ),
          if (_progress >= 1.0) const LinearProgressIndicator(value: 1.0),
          const SizedBox(height: 20),
          // Box to display file content
          fileContent.isEmpty
              ? const Text('No document uploaded to Collection yet.')
              : Container(
                // ...existing code...
                constraints: const BoxConstraints(
                  maxHeight: 200,
                  maxWidth: 200,
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        Text(
                          fileName,
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: () {
                            extractParagraphs(
                              fileContentEN,
                              fileContentSK,
                              fileContentCZ,
                              metadata,
                              "dir",
                              indexName,
                            );
                          },
                          child: const Text('Extract Paragraphs'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class FilePickerButton2 extends StatefulWidget {
  @override
  _FilePickerButtonState2 createState() => _FilePickerButtonState2();
}

class _FilePickerButtonState2 extends State<FilePickerButton2> {
  double _progress = 0.01;
  bool simulateUpload = false;
  bool debugMode = false;
  bool _useWorkingLanguagesOnly = false;
  HarvestSession? _harvestSession;
  bool _showProgressTable = false;

  // Unify progress logic with picker 1: phases -> file read, celex extraction, uploads.
  // We treat total phases as: 1 (file loaded) + 1 (celex list extracted) + N uploads.
  int _totalUploads = 0;
  int _completedUploads = 0;
  bool _fileLoaded = false;
  bool _celexExtracted = false;

  // Index name input state and validation
  String _indexBase2 = '';
  String? _indexError2;

  String? _validateIndexName(String base, String userPrefix) {
    if (base.isEmpty) return 'Index name is required.';
    final value = base.trim();
    if (value == '.' || value == '..') return 'Cannot be \'\.\' or \'..\'.';
    if (RegExp(r'[A-Z]').hasMatch(value)) return 'Use lowercase letters only.';
    if (RegExp(r'^[\_\-\+]').hasMatch(value)) {
      return 'Cannot start with _ , - , or +.';
    }
    if (!RegExp(r'^[a-z0-9._-]+$').hasMatch(value)) {
      return 'Allowed: a-z, 0-9, dot, underscore, hyphen.';
    }
    final full = 'eu_${userPrefix}_$value';
    if (full.length > 255) return 'Full index name too long (max 255 chars).';
    return null;
  }

  List<String>? _getSelectedWorkingLanguages() {
    if (!_useWorkingLanguagesOnly) return null;
    final selected = <String>[];
    if (lang1 != null && lang1!.isNotEmpty) selected.add(lang1!);
    if (lang2 != null && lang2!.isNotEmpty) selected.add(lang2!);
    if (lang3 != null && lang3!.isNotEmpty) selected.add(lang3!);
    return selected.isEmpty ? null : selected;
  }

  void _recalcProgress() {
    final basePhases = (_fileLoaded ? 1 : 0) + (_celexExtracted ? 1 : 0);
    final totalPhases = 2 + _totalUploads; // 2 fixed phases + upload phases
    final done = basePhases + _completedUploads;
    _progress = totalPhases == 0 ? 0.0 : done / totalPhases;
  }

  Future<void> _saveCelexDebugFile(
    List<String> celexNumbers,
    String indexName,
    String source,
  ) async {
    try {
      final debugDir = Directory('logs');
      if (!await debugDir.exists()) {
        await debugDir.create(recursive: true);
      }

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final debugFileName = 'celex_${source}_${indexName}_$timestamp.json';
      final debugFile = File(path.join(debugDir.path, debugFileName));

      final debugData = {
        'source': source,
        'index': indexName,
        'timestamp': timestamp,
        'celex_count': celexNumbers.length,
        'celex_numbers': celexNumbers,
      };

      final jsonOutput = const JsonEncoder.withIndent('  ').convert(debugData);
      await debugFile.writeAsString(jsonOutput);

      final logger = LogManager();
      logger.log('Debug file saved: ${debugFile.path}');
      print('Debug JSON saved to: ${debugFile.path}');
    } catch (e) {
      final logger = LogManager();
      logger.log('ERROR saving debug file: $e');
    }
  }

  Future<void> retryFailedCelex(List celex, String indexName) async {
    //failedCelex.clear();
    for (final cel in celex) {
      var status = await uploadSparqlForCelex(
        cel,
        newIndexName,
        "html",
        0,
        debugMode,
        simulateUpload,
      );
      print(status);

      //failedCelex.removeWhere((item) => item.contains(cel));
      print("After retry, failedCelex: $failedCelex");

      _completedUploads++;
      if (!mounted) return;
      setState(() {
        _recalcProgress();
      });
    }

    if (!mounted) return;

    if (failedCelex.isNotEmpty) {}
    setState(() {
      _recalcProgress(); // should hit 100%
      getCustomIndices(
        server,
        isAdmin,
        jsonSettings['access_key'] ?? DEFAULT_ACCESS_KEY,
      );
    });
  }

  Future<void> pickAndLoadFile2() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (!mounted) return;
    setState(() {
      celexNumbersExtracted.clear();
      //   extractedCelex.clear();
      failedCelex.clear();
      _progress = 0.01;
      _fileLoaded = false;
      _celexExtracted = false;
      _totalUploads = 0;
      _completedUploads = 0;
      _showProgressTable = false;
    });
    if (result == null) return;

    final filePath = result.files.single.path!;
    fileName = path.basename(filePath);
    final file = File(filePath);
    if (!await file.exists()) return;

    final bytes = await file.readAsBytes();
    final content = utf8.decode(bytes, allowMalformed: true);
    fileContent2 = content;
    _fileLoaded = true;

    if (fileContent2.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        fileDOM2 = html_parser.parse(fileContent2);
        for (final td in fileDOM2.getElementsByTagName('td')) {
          if (td.text.contains('Celex number:')) {
            final celexNumberTd = td.nextElementSibling;
            final celexNumber = celexNumberTd?.text.trim();
            if (celexNumber != null) celexNumbersExtracted.add(celexNumber);
          }
        }
        _celexExtracted = true;
        _totalUploads = celexNumbersExtracted.length;
        _recalcProgress();
      });
    } else {
      if (!mounted) return;
      setState(() {
        _recalcProgress();
      });
    }

    // Create harvest session
    final timestamp = DateTime.now().toIso8601String().replaceAll(
      RegExp(r'[:.\s]'),
      '-',
    );
    final sessionId = 'file_refs_$timestamp';
    final session = HarvestSession(
      sessionId: sessionId,
      indexName: newIndexName,
      celexOrder: List<String>.from(celexNumbersExtracted),
    );

    // Initialize progress for all CELEXs
    for (final celex in celexNumbersExtracted) {
      session.documents[celex] = CelexProgress(
        celex: celex,
        languages: {'ALL': LangStatus.pending},
      );
    }

    setState(() {
      _harvestSession = session;
      _showProgressTable = true;
    });
    await session.save();

    final logger = LogManager();

    for (var i = 0; i < celexNumbersExtracted.length; i++) {
      final celex = celexNumbersExtracted[i];
      final progress = session.documents[celex]!;
      progress.startedAt = DateTime.now();

      // Check if exists
      final exists = await celexExistsInIndex(newIndexName, celex);
      if (exists) {
        progress.languages['ALL'] = LangStatus.skipped;
        progress.completedAt = DateTime.now();
      } else {
        // Remove placeholder and prepare for actual languages
        progress.languages.clear();

        await uploadSparqlForCelexWithProgress(
          celex,
          newIndexName,
          "xhtml",
          (String lang, LangStatus status, int unitCount) {
            if (progress is! CelexProgress) {
              print(
                'ERROR: progress is not CelexProgress, it is: ${progress.runtimeType}',
              );
              return;
            }
            progress.languages[lang] = status;
            if (unitCount > 0) progress.unitCounts[lang] = unitCount;
            if (mounted) setState(() {});
          },
          (int httpStatus) {
            if (progress is! CelexProgress) {
              print(
                'ERROR: progress is not CelexProgress, it is: ${progress.runtimeType}',
              );
              return;
            }
            progress.httpStatus = httpStatus;
            if (mounted) setState(() {});
          },
          0,
          debugMode,
          simulateUpload,
          _getSelectedWorkingLanguages(), // Pass selected languages
        );

        // Don't overwrite statuses - they were already set by the callback
        // Only update completedAt
        progress.completedAt = DateTime.now();
      }

      session.currentPointer = i + 1;
      await session.save();

      _completedUploads++;
      if (!mounted) return;
      setState(() {
        _recalcProgress();
      });
    }

    if (!mounted) return;

    // Save debug file if debug mode is enabled
    if (debugMode) {
      await _saveCelexDebugFile(
        List<String>.from(celexNumbersExtracted),
        newIndexName,
        'file_upload',
      );
    }

    if (failedCelex.isNotEmpty) {
      await retryFailedCelex(failedCelex, newIndexName);
    }

    session.completedAt = DateTime.now();
    await session.save();

    if (!mounted) return;
    setState(() {
      _recalcProgress(); // should hit 100%
      getCustomIndices(
        server,
        isAdmin,
        jsonSettings['access_key'] ?? DEFAULT_ACCESS_KEY,
      );
    });

    //try retry for failed celex numbers using HTML harvesting instead of XHTML
  }

  // build: add progress bar similar to first picker
  @override
  Widget build(BuildContext context) {
    // Step completion states
    final bool step1Complete =
        newIndexName.isNotEmpty &&
        newIndexName != "eurolex_" &&
        _indexError2 == null;
    final bool step2Complete = fileContent2.isNotEmpty;

    return Padding(
      // ...existing code...
      padding: const EdgeInsets.all(12.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(height: 10),
            Text(
              'Add a list of EU documents to your Collection',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            SizedBox(height: 15),
            Container(
              color: Color(0xFFF5F7FA),
              padding: EdgeInsets.all(8),
              child: Image.asset('lib/data/List2.png', height: 100),
            ),
            SizedBox(height: 15),
            Text(
              'You can upload a list of EU documents to your new or existing Collection to get the most relevant results.',
              style: TextStyle(fontSize: 17.5),
            ),
            SizedBox(height: 30),

            // Step 1: Choose Collection
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '1.',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose Collection',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Search Collection',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  hint: const Text(
                                    'Choose existing collection',
                                  ),
                                  value:
                                      indices.contains(newIndexName)
                                          ? newIndexName
                                          : null,
                                  items:
                                      indices.map((String value) {
                                        return DropdownMenuItem<String>(
                                          value: value,
                                          child: Text(value),
                                        );
                                      }).toList(),
                                  onTap: () async {
                                    await getCustomIndices(
                                      server,
                                      isAdmin,
                                      userPasskey,
                                    );
                                    if (!mounted) return;
                                    setState(() {});
                                  },
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      newIndexName = newValue!;
                                    });
                                    print(
                                      'Selected for Celex Refs upload: $newValue',
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'OR',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 5,
                            child: TextField(
                              decoration: InputDecoration(
                                labelText: 'Enter New Collection Name',
                                border: OutlineInputBorder(),
                                errorText: _indexError2,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp('[a-z0-9._-]'),
                                ),
                              ],
                              onChanged: (value) {
                                final v = value.toLowerCase();
                                setState(() {
                                  _indexBase2 = v;
                                  _indexError2 = _validateIndexName(
                                    v,
                                    userPasskey,
                                  );
                                });
                              },
                              onSubmitted: (value) {
                                final v = value.toLowerCase();
                                final err = _validateIndexName(v, userPasskey);
                                setState(() {
                                  _indexError2 = err;
                                  if (err == null) {
                                    newIndexName = 'eu_${userPasskey}_$v';
                                  }
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 20),

            // Step 2: Pick file
            Opacity(
              opacity: step1Complete ? 1.0 : 0.4,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '2.',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select a list of CELEX document references',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 10),
                        (newIndexName == '' ||
                                newIndexName == "eurolex_" ||
                                _indexError2 != null)
                            ? Text('Complete Step 1 First!')
                            : Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                ElevatedButton(
                                  onPressed:
                                      step1Complete ? pickAndLoadFile2 : null,
                                  child: Text(
                                    'Click to Pick File with List of References',
                                  ),
                                ),
                                if (isAdmin) ...[
                                  Tooltip(
                                    message:
                                        'Simulate (all processing except uploading data to the database)',
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Checkbox(
                                          value: simulateUpload,
                                          onChanged:
                                              step1Complete
                                                  ? (v) {
                                                    setState(() {
                                                      simulateUpload =
                                                          v ?? false;
                                                    });
                                                  }
                                                  : null,
                                        ),
                                        const Text('Simulate'),
                                      ],
                                    ),
                                  ),
                                  Tooltip(
                                    message:
                                        'Debug Mode: save detailed logs to debug_output folder',
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Checkbox(
                                          value: debugMode,
                                          onChanged:
                                              step1Complete
                                                  ? (v) {
                                                    setState(() {
                                                      debugMode = v ?? false;
                                                    });
                                                  }
                                                  : null,
                                        ),
                                        const Text('Debug Mode'),
                                      ],
                                    ),
                                  ),
                                ],
                                Tooltip(
                                  message:
                                      'Upload only selected working languages from Search tab (${[lang1, lang2, lang3].where((l) => l != null && l.isNotEmpty).join(', ')})',
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Checkbox(
                                        value: _useWorkingLanguagesOnly,
                                        onChanged:
                                            step1Complete
                                                ? (v) {
                                                  setState(() {
                                                    _useWorkingLanguagesOnly =
                                                        v ?? false;
                                                  });
                                                }
                                                : null,
                                      ),
                                      Text(
                                        'Working Lang Only (${[lang1, lang2, lang3].where((l) => l != null && l.isNotEmpty).join(', ')})',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),

            // Step 3: Upload
            Opacity(
              opacity: step2Complete ? 1.0 : 0.4,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '3.',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Upload the documents to the Collection',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          step2Complete
                              ? 'File loaded. Processing will start automatically.'
                              : 'Select a file first.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),

            // Progress bar (added)
            if (_progress > 0 && _progress < 1)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(value: _progress),
                  const SizedBox(height: 4),
                  Text('${(_progress * 100).floor()}%'),
                ],
              ),
            if (_progress >= 1.0) const LinearProgressIndicator(value: 1.0),
            const SizedBox(height: 20),

            fileContent2.isEmpty
                ? const Text('No document uploaded to Collection yet.')
                : (_showProgressTable && _harvestSession != null)
                ? Container(
                  height: MediaQuery.of(context).size.height * 0.45,
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: HarvestProgressWidget(
                    session: _harvestSession!,
                    onCancel: () {
                      if (mounted) {
                        setState(() {
                          _showProgressTable = false;
                        });
                      }
                    },
                  ),
                )
                : const Text('Upload starting...'),
          ],
        ),
      ),
    );
  }
}

final now = DateTime.now();
final fileSafeStamp =
    '${now.year.toString().padLeft(4, '0')}-'
    '${now.month.toString().padLeft(2, '0')}-'
    '${now.day.toString().padLeft(2, '0')}_'
    '${now.hour.toString().padLeft(2, '0')}-'
    '${now.minute.toString().padLeft(2, '0')}';

class manualCelexList extends StatefulWidget {
  _manualCelexListState createState() => _manualCelexListState();
}

class _manualCelexListState extends State<manualCelexList> {
  double _progress = 0.01; // 0.0 - 1.0
  bool simulateUpload = false;
  bool debugMode = false;
  bool _useWorkingLanguagesOnly = false;

  // Progress tracking
  HarvestSession? _harvestSession;
  bool _showProgressTable = false;

  // Index name input state and validation
  String _indexBaseManual = '';
  String? _indexErrorManual;

  List<String>? _getSelectedWorkingLanguages() {
    if (!_useWorkingLanguagesOnly) return null;
    final selected = <String>[];
    if (lang1 != null && lang1!.isNotEmpty) selected.add(lang1!);
    if (lang2 != null && lang2!.isNotEmpty) selected.add(lang2!);
    if (lang3 != null && lang3!.isNotEmpty) selected.add(lang3!);
    return selected.isEmpty ? null : selected;
  }

  String? _validateIndexName(String base, String userPrefix) {
    if (base.isEmpty) return 'Index name is required.';
    final value = base.trim();
    if (value == '.' || value == '..') return 'Cannot be \'\.\' or \'..\'.';
    if (RegExp(r'[A-Z]').hasMatch(value)) return 'Use lowercase letters only.';
    if (RegExp(r'^[\_\-\+]').hasMatch(value)) {
      return 'Cannot start with _ , - , or +.';
    }
    if (!RegExp(r'^[a-z0-9._-]+$').hasMatch(value)) {
      return 'Allowed: a-z, 0-9, dot, underscore, hyphen.';
    }
    final full = 'eu_${userPrefix}_$value';
    if (full.length > 255)
      return 'Full collection name too long (max 255 chars).';
    return null;
  }

  Future<void> _saveCelexDebugFile(
    List<String> celexNumbers,
    String indexName,
    String source,
  ) async {
    try {
      final debugDir = Directory('logs');
      if (!await debugDir.exists()) {
        await debugDir.create(recursive: true);
      }

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final debugFileName = 'celex_${source}_${indexName}_$timestamp.json';
      final debugFile = File(path.join(debugDir.path, debugFileName));

      final debugData = {
        'source': source,
        'index': indexName,
        'timestamp': timestamp,
        'celex_count': celexNumbers.length,
        'celex_numbers': celexNumbers,
      };

      final jsonOutput = const JsonEncoder.withIndent('  ').convert(debugData);
      await debugFile.writeAsString(jsonOutput);

      final logger = LogManager();
      logger.log('Debug file saved: ${debugFile.path}');
      print('Debug JSON saved to: ${debugFile.path}');
    } catch (e) {
      final logger = LogManager();
      logger.log('ERROR saving debug file: $e');
    }
  }

  // DEPRECATED: Legacy upload function using extractedCelex list.
  // Use manualCelexListUploadWithProgress() instead.
  // This function is not called anywhere and can be removed in future cleanup.
  Future manualCelexListUpload(manualCelexListEntry, newIndexName) async {
    setState(() {
      extractedCelex.clear();
      _progress = 0.01;
    });

    // Save debug file if debug mode is enabled
    if (debugMode) {
      await _saveCelexDebugFile(
        List<String>.from(manualCelexListEntry),
        newIndexName,
        'manual_upload',
      );
    }

    final logger = LogManager();
    final total = manualCelexListEntry.length;
    for (var index = 0; index < total; index++) {
      var i = manualCelexListEntry[index];
      extractedCelex.add('${index + 1}/$total: $i:');
      await uploadSparqlForCelex(
        i,
        newIndexName,
        "xhtml",
        0,
        debugMode,
        simulateUpload,
      );

      if (!mounted) return;
      setState(() {
        // extractedCelex.add('$i ${index + 1}/$total');
        _progress = (index + 1) / total;
      });

      logger.log("$i uploaded to $activeIndex in manual Celex upload.");
    }

    if (!mounted) return;
    setState(() {
      extractedCelex.add('COMPLETED');
      getCustomIndices(
        server,
        isAdmin,
        jsonSettings['access_key'] ?? DEFAULT_ACCESS_KEY,
      );
    });
  }

  /// New version with harvest progress tracking
  Future<void> manualCelexListUploadWithProgress(
    List<String> celexList,
    String indexName,
  ) async {
    setState(() {
      _progress = 0.01;
      _showProgressTable = true;
    });

    // Create session
    final timestamp = DateTime.now().toIso8601String().replaceAll(
      RegExp(r'[:.\ ]'),
      '-',
    );
    final sessionId = 'manual_celex_$timestamp';

    final session = HarvestSession(
      sessionId: sessionId,
      indexName: indexName,
      celexOrder: celexList,
    );

    // Initialize progress for all CELEXs
    for (final celex in celexList) {
      // We don't know languages yet, so start with pending
      session.documents[celex] = CelexProgress(
        celex: celex,
        languages: {'ALL': LangStatus.pending},
      );
    }

    setState(() => _harvestSession = session);
    await session.save();

    final logger = LogManager();
    final total = celexList.length;

    // Save debug file if enabled
    if (debugMode) {
      await _saveCelexDebugFile(celexList, indexName, 'manual_upload');
    }

    for (var index = 0; index < total; index++) {
      final celex = celexList[index];
      final progress = session.documents[celex]!;
      progress.startedAt = DateTime.now();

      // Check if exists (deduplication)
      final exists = await celexExistsInIndex(indexName, celex);
      if (exists) {
        print('⏭️ Skipping $celex (already exists)');
        progress.languages['ALL'] = LangStatus.skipped;
        progress.completedAt = DateTime.now();
      } else {
        try {
          // Remove the placeholder 'ALL' and prepare for actual languages
          progress.languages.clear();
          if (mounted) setState(() {});

          await uploadSparqlForCelexWithProgress(
            celex,
            indexName,
            "xhtml",
            (String lang, LangStatus status, int unitCount) {
              // Update language status in real-time
              if (progress is! CelexProgress) {
                print(
                  'ERROR: progress is not CelexProgress, it is: ${progress.runtimeType}',
                );
                return;
              }
              progress.languages[lang] = status;
              if (unitCount > 0) {
                progress.unitCounts[lang] = unitCount;
              }
              if (mounted) setState(() {});
            },
            (int httpStatus) {
              if (progress is! CelexProgress) {
                print(
                  'ERROR: progress is not CelexProgress, it is: ${progress.runtimeType}',
                );
                return;
              }
              progress.httpStatus = httpStatus;
              if (mounted) setState(() {});
            },
            0,
            debugMode,
            simulateUpload,
            _getSelectedWorkingLanguages(), // Pass selected languages
          );

          progress.completedAt = DateTime.now();
          logger.log("$celex uploaded to $indexName in manual Celex upload.");
        } catch (e) {
          // Mark all languages as failed
          for (final lang in progress.languages.keys.toList()) {
            progress.languages[lang] = LangStatus.failed;
          }
          progress.errors['general'] = e.toString();
          progress.completedAt = DateTime.now();
          logger.log("Failed to upload $celex: $e");
        }
      }

      if (!mounted) return;
      setState(() {
        _progress = (index + 1) / total;
        session.currentPointer = index;
      });

      await session.save();
    }

    session.completedAt = DateTime.now();
    await session.save();

    if (!mounted) return;
    setState(() {
      getCustomIndices(
        server,
        isAdmin,
        jsonSettings['access_key'] ?? DEFAULT_ACCESS_KEY,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Step completion states
    final bool step1Complete =
        newIndexName.isNotEmpty &&
        newIndexName != "eurolex_" &&
        _indexErrorManual == null;
    final bool step2Complete =
        manualCelex.isNotEmpty && manualCelex.any((c) => c.isNotEmpty);

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: 10),
            Text(
              'Add one or more EU documents to your Collection',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            SizedBox(height: 15),
            Container(
              color: Color(0xFFF5F7FA),
              padding: EdgeInsets.all(8),
              child: Image.asset('lib/data/Celexes2.png', height: 100),
            ),
            SizedBox(height: 15),
            Text(
              'You can create or update your own Collection of EU documents and search in them to get the most relevant results.',
              style: TextStyle(fontSize: 17.5),
            ),
            SizedBox(height: 30),

            // Step 1: Choose Collection
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '1.',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose Collection',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Search Collection',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  hint: const Text(
                                    'Choose existing collection',
                                  ),
                                  value:
                                      indices.contains(newIndexName)
                                          ? newIndexName
                                          : null,
                                  items:
                                      indices.map((String value) {
                                        return DropdownMenuItem<String>(
                                          value: value,
                                          child: Text(value),
                                        );
                                      }).toList(),
                                  onTap: () async {
                                    await getCustomIndices(
                                      server,
                                      isAdmin,
                                      userPasskey,
                                    );
                                    if (!mounted) return;
                                    setState(() {});
                                  },
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      newIndexName = newValue!;
                                    });
                                    print(
                                      'Selected for manual Celex Refs upload: $newValue',
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'OR',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 5,
                            child: TextField(
                              decoration: InputDecoration(
                                labelText: 'Enter New Collection Name',
                                border: OutlineInputBorder(),
                                errorText: _indexErrorManual,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp('[a-z0-9._-]'),
                                ),
                              ],
                              onChanged: (value) {
                                final v = value.toLowerCase();
                                setState(() {
                                  _indexBaseManual = v;
                                  _indexErrorManual = _validateIndexName(
                                    v,
                                    userPasskey,
                                  );
                                });
                              },
                              onSubmitted: (value) {
                                final v = value.toLowerCase();
                                final err = _validateIndexName(v, userPasskey);
                                setState(() {
                                  _indexErrorManual = err;
                                  if (err == null) {
                                    newIndexName = 'eu_${userPasskey}_$v';
                                  }
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 20),

            // Step 2: Enter Celex numbers
            Opacity(
              opacity: step1Complete ? 1.0 : 0.4,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '2.',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enter Celex numbers of the documents to upload',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 10),
                        TextField(
                          enabled: step1Complete,
                          decoration: InputDecoration(
                            labelText: 'Enter Celex Numbers (comma separated)',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            setState(() {
                              manualCelex =
                                  value
                                      .split(',')
                                      .map((e) => e.trim())
                                      .toList();
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),

            // Step 3: Upload button
            Opacity(
              opacity: step2Complete ? 1.0 : 0.4,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '3.',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Upload the document to the Collection',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 10),
                        (newIndexName == '' || newIndexName == "eurolex_")
                            ? Text('Enter Collection Name First!')
                            : Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                ElevatedButton(
                                  onPressed:
                                      (_indexErrorManual != null ||
                                              !step2Complete)
                                          ? null
                                          : () {
                                            if (newIndexName.isNotEmpty &&
                                                newIndexName != "eurolex_") {
                                              manualCelexListUploadWithProgress(
                                                manualCelex,
                                                newIndexName,
                                              );
                                            } else {
                                              print(
                                                'Please enter a collection name first.',
                                              );
                                            }
                                          },
                                  child: Text(
                                    'Click to Upload Celex Numbers to $newIndexName',
                                  ),
                                ),
                                if (isAdmin) ...[
                                  Tooltip(
                                    message:
                                        'Simulate (all processing except uploading data to the database)',
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Checkbox(
                                          value: simulateUpload,
                                          onChanged:
                                              step2Complete
                                                  ? (v) {
                                                    setState(() {
                                                      simulateUpload =
                                                          v ?? false;
                                                    });
                                                  }
                                                  : null,
                                        ),
                                        const Text('Simulate'),
                                      ],
                                    ),
                                  ),
                                  Tooltip(
                                    message:
                                        'Debug Mode: save detailed logs to debug_output folder',
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Checkbox(
                                          value: debugMode,
                                          onChanged:
                                              step2Complete
                                                  ? (v) {
                                                    setState(() {
                                                      debugMode = v ?? false;
                                                    });
                                                  }
                                                  : null,
                                        ),
                                        const Text('Debug Mode'),
                                      ],
                                    ),
                                  ),
                                ],
                                Tooltip(
                                  message:
                                      'Upload only selected working languages from Search tab (${[lang1, lang2, lang3].where((l) => l != null && l.isNotEmpty).join(', ')})',
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Checkbox(
                                        value: _useWorkingLanguagesOnly,
                                        onChanged:
                                            step2Complete
                                                ? (v) {
                                                  setState(() {
                                                    _useWorkingLanguagesOnly =
                                                        v ?? false;
                                                  });
                                                }
                                                : null,
                                      ),
                                      Text(
                                        'Working Lang Only (${[lang1, lang2, lang3].where((l) => l != null && l.isNotEmpty).join(', ')})',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),
            if (_progress > 0 && _progress < 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(value: _progress),
                    SizedBox(height: 4),
                    Text('${(_progress * 100).floor()}%'),
                  ],
                ),
              ),
            if (_progress >= 1.0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(value: 1.0),
              ),
            // Harvest Progress Table
            if (_showProgressTable && _harvestSession != null)
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: 500),
                child: HarvestProgressWidget(
                  session: _harvestSession!,
                  // Only show cancel button while in progress, not after completion
                  onCancel:
                      _harvestSession!.completedAt == null
                          ? () {
                            setState(() {
                              _showProgressTable = false;
                              _harvestSession = null;
                            });
                          }
                          : null,
                ),
              ),
            // existing results container:
            if (!_showProgressTable)
              manualCelex.isEmpty
                  ? const Text('No document uploaded to Collection yet.')
                  : const Text('Upload starting...'),
          ],
        ),
      ),
    );
  }
}

Future<String> loadHtmtFromCelex(celex, lang) async {
  // Use HTTPS
  String url =
      'https://eur-lex.europa.eu/legal-content/$lang/TXT/HTML/?uri=CELEX:$celex';
  print('Harvest HTML from URL: $url');

  try {
    // Add browser-like headers (minimal)
    final headers = <String, String>{
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36',
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
      'Accept-Language': '$lang;q=1.0,en;q=0.8',
      'Referer': 'https://eur-lex.europa.eu/',
      'Cache-Control': 'no-cache',
      'Pragma': 'no-cache',
    };

    final response = await http
        .get(Uri.parse(url), headers: headers)
        .timeout(const Duration(seconds: 225));
    // ...existing code...
    if (response.statusCode == 200) {
      String htmlContent = utf8.decode(
        response.bodyBytes,
        allowMalformed: true,
      );
      print('HTML content loaded successfully: celex: $celex, lang: $lang');
      return htmlContent;
    } else {
      final bodyText = utf8.decode(response.bodyBytes, allowMalformed: true);
      final snippetLen = bodyText.length > 100 ? 100 : bodyText.length;
      final errorMsg =
          'Failed to load HTML in Harvest for celex: $celex, lang: $lang. '
          'Status code: ${response.statusCode}, ${response.headers}\n'
          '${bodyText.substring(0, snippetLen)}';
      print(errorMsg);
      throw Exception(errorMsg);
    }
  } catch (e) {
    print('Error loading HTML: $e');
    throw Exception('Error loading HTML: $e');
  }
}

Future<String> loadHtmtFromCellar(url, lang) async {
  // Use HTTPS

  print('Harvest HTML from URL: $url');

  try {
    // Add browser-like headers (minimal)
    final headers = <String, String>{
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36',
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
      'Accept-Language': '$lang;q=1.0,en;q=0.8',
      'Referer': 'https://eur-lex.europa.eu/',
      'Cache-Control': 'no-cache',
      'Pragma': 'no-cache',
    };

    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 1000));
    // ...existing code...
    if (response.statusCode == 200) {
      String htmlContent = utf8.decode(
        response.bodyBytes,
        allowMalformed: true,
      );
      print('HTML content loaded successfully: $url, lang: $lang');
      return htmlContent;
    } else {
      final bodyText = utf8.decode(response.bodyBytes, allowMalformed: true);
      final snippetLen = bodyText.length > 100 ? 100 : bodyText.length;
      final errorMsg =
          'Failed to load HTML in Harvest for $url, lang: $lang. '
          'Status code: ${response.statusCode}, ${response.headers}\n'
          '${bodyText.substring(0, snippetLen)}';
      print(errorMsg);
      throw Exception(errorMsg);
    }
  } catch (e) {
    print('Error loading HTML: $e');
    throw Exception('Error loading HTML: $e');
  }
}

class parseHtml {
  // Function to parse HTML content and extract text
  static String parseHtmlString(String htmlString) {
    // Parse the HTML string
    var document = html_parser.parse(htmlString);
    // Extract text from the parsed document
    return document.body?.text ?? '';
  }
}

//id = passkey, custom indices name format: passkey_user-supplier-name in lowercase
Future getCustomIndices(server, isAdmin, id) async {
  // SECURE: Uses server endpoint which validates API key and filters server-side
  await loadSettingsFromFile();

  try {
    final response = await http.get(
      Uri.parse('$server/_cat/indices?h=index'),
      headers: {
        'x-api-key': jsonSettings['access_key'],
        'x-email': jsonSettings['user_email'],
      },
    );
    if (response.statusCode == 200) {
      String responseBody = utf8.decode(
        response.bodyBytes,
        allowMalformed: true,
      );

      // Server returns all indices for admin, but client can choose to filter
      if (adminUIEnabled && isAdmin) {
        // Admin with UI enabled: show all indices from server
        indices =
            responseBody
                .split('\n')
                .where((line) => line.trim().isNotEmpty)
                .toList();
        print('Admin UI enabled, loading all indices: $indices');
        return responseBody;
      } else if (jsonSettings['access_key'] == "trial") {
        // Trial mode: show only global wildcard
        indices = ["*"];
        print('Trial mode detected, showing only global index: $indices');
        return "Trial mode - limited indices";
      } else {
        // Non-admin OR admin with UI disabled: filter to user's own indices
        indices =
            responseBody
                .split('\n')
                .where((line) => line.trim().isNotEmpty && line.contains(id))
                .toList();
        print('Loading custom indices for id: $id, indices: $indices');
        return responseBody;
      }
    } else {
      print('Failed to load indices. Status code: ${response.statusCode}');
      indices = ["*"];
      return 'Error loading indices: ${response.statusCode}';
    }
  } catch (e) {
    print('Error loading indices: $e');
    return 'Error loading indices: $e';
  }
}

Future getListIndices(server) async {
  // Function to get the list of indices from the server
  await loadSettingsFromFile();
  final username = 'admin';
  final password = 'admin';
  final basicAuth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';

  try {
    final response = await http.get(
      Uri.parse('$server/_cat/indices?h=index'),
      headers: {
        'Authorization': basicAuth,
        'x-api-key': jsonSettings['access_key'],
        'x-email': jsonSettings['user_email'],
      },
    );
    if (response.statusCode == 200) {
      String responseBody = utf8.decode(
        response.bodyBytes,
        allowMalformed: true,
      );

      // Extract the index names from the JSON response
      indices =
          responseBody
              .split('\n') // Split the response into lines
              .where(
                (item) => item.contains('eurolex') || item.contains('imported'),
              ) // Keep only items containing "eurolex"
              .toList();
      print('Indices loaded: $indices for server: $server');

      print('Indices for server $server loaded successfully: $responseBody');

      return responseBody; // Return the indices as a string
    } else {
      print('Failed to load indices. Status code: ${response.statusCode}');
      return 'Error loading indices: ${response.statusCode}';
    }
  } catch (e) {
    print('Error loading indices: $e');
    return 'Error loading indices: $e';
  }
}

Future<List<List<String>>> getListIndicesFull(server, isAdmin) async {
  // SECURE: Uses server endpoint which validates API key and filters server-side
  print("userPasskey for getListIndicesFull: $userPasskey");
  List<List<String>> indicesList = [];
  try {
    final response = await http.get(
      Uri.parse('$server/_cat/indices?h=index,store.size,docs.count'),
      headers: {
        'x-api-key': jsonSettings['access_key'],
        'x-email': jsonSettings['user_email'],
      },
    );
    if (response.statusCode == 200) {
      String responseBody = utf8.decode(
        response.bodyBytes,
        allowMalformed: true,
      );

      // Server returns all indices for admin, but client can choose to filter
      List<String> lines;

      if (adminUIEnabled && isAdmin) {
        // Admin with UI enabled: show all indices from server
        print('Admin UI enabled, showing all indices');
        lines =
            responseBody
                .split('\n')
                .where((line) => line.trim().isNotEmpty)
                .toList();
      } else {
        // Non-admin OR admin with UI disabled: filter to user's own indices
        print('Filtering indices for userPasskey: $userPasskey');
        lines =
            responseBody
                .split('\n')
                .where(
                  (line) =>
                      line.trim().isNotEmpty && line.contains(userPasskey),
                )
                .toList();
      }

      // Parse and fetch readonly status for each index
      final tempList =
          lines
              .map((line) {
                final parts = line.split(RegExp(r'\s+'));
                if (parts.length >= 3) {
                  return <String>[parts[0], parts[1], parts[2]];
                } else {
                  return <String>[];
                }
              })
              .where((sublist) => sublist.isNotEmpty)
              .toList();

      indicesList =
          lines
              .map((line) {
                final parts = line.split(RegExp(r'\s+'));
                if (parts.length >= 3) {
                  return <String>[parts[0], parts[1], parts[2]];
                } else {
                  return <String>[];
                }
              })
              .where((sublist) => sublist.isNotEmpty)
              .toList();

      print('Indices details loaded: $indicesList for server: $server');
      indicesFull = indicesList;
      return indicesList;
    } else {
      print(
        'Failed to load indices details. Status code: ${response.statusCode}',
      );
      return [];
    }
  } catch (e) {
    print('Error loading indices details: $e');
    return [];
  }
}

// Helper to build spans
// Old display function removed - now using HarvestProgressWidget
