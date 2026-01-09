//import 'dart:nativewrappers/_internal/vm/lib/internal_patch.dart';
import 'dart:ui';

import 'package:LegisTracerEU/browseFiles.dart';
import 'package:LegisTracerEU/file_handling.dart';
import 'package:LegisTracerEU/processDOM.dart';
import 'package:LegisTracerEU/search.dart';
import 'package:LegisTracerEU/setup.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:LegisTracerEU/bulkupload.dart';
import 'dart:convert';

import 'package:html/parser.dart' as html_parser;

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:LegisTracerEU/logger.dart';
import 'package:LegisTracerEU/testHtmlDumps.dart';
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
var manualCelex = [];
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
        String content = await file.readAsString();
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
              ? const Text('No file loaded.')
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

  void _recalcProgress() {
    final basePhases = (_fileLoaded ? 1 : 0) + (_celexExtracted ? 1 : 0);
    final totalPhases = 2 + _totalUploads; // 2 fixed phases + upload phases
    final done = basePhases + _completedUploads;
    _progress = totalPhases == 0 ? 0.0 : done / totalPhases;
  }

  Future<void> retryFailedCelex(List celex, String indexName) async {
    //failedCelex.clear();
    for (final cel in celex) {
      extractedCelex.add('${_completedUploads + 1}/$_totalUploads: $celex:');

      var status = await uploadSparqlForCelex(cel, newIndexName, "html");
      print(status);

      //failedCelex.removeWhere((item) => item.contains(cel));
      print("After retry, failedCelex: $failedCelex");
      if (failedCelex.contains(celex)) {
        extractedCelex.add('XHTML FAILED, WILL RETRY in HTML LATER');
      } else {}

      _completedUploads++;
      if (!mounted) return;
      setState(() {
        _recalcProgress();
      });
    }

    if (!mounted) return;

    if (failedCelex.isNotEmpty) {}
    setState(() {
      if (failedCelex.isNotEmpty) {
        extractedCelex.add(
          'FAILED CELEX NUMBERS (will retry HTML upload): ${failedCelex.join(', ')}',
        );
      } else {
        extractedCelex.add('COMPLETED');
      }

      _recalcProgress(); // should hit 100%
      getCustomIndices(
        server,
        isAdmin,
        jsonSettings['access_key'] ?? DEFAULT_ACCESS_KEY,
      );
    });
  }

  Future<void> pickAndLoadFile2() async {
    setState(() {
      extractedCelex.clear();
      print("extractedCelex cleared at start of pickAndLoadFile2");
    });

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
    });
    if (result == null) return;

    final filePath = result.files.single.path!;
    fileName = path.basename(filePath);
    final file = File(filePath);
    if (!await file.exists()) return;

    final content = await file.readAsString();
    fileContent2 = content;
    _fileLoaded = true;

    if (fileContent2.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        fileDOM2 = html_parser.parse(fileContent2);
        for (final td in fileDOM2.getElementsByTagName('td')) {
          if (td.text.contains('Celex number:')) {
            final celexNumberTd = td.nextElementSibling;
            final celexNumber = celexNumberTd.text.trim();
            celexNumbersExtracted.add(celexNumber);
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

    for (final celex in celexNumbersExtracted) {
      extractedCelex.add('${_completedUploads + 1}/$_totalUploads: $celex:');

      await uploadSparqlForCelex(celex, newIndexName, "xhtml");
      if (failedCelex.contains(celex)) {
        extractedCelex.add('XHTML FAILED, WILL RETRY in HTML LATER');
      } else {}

      _completedUploads++;
      if (!mounted) return;
      setState(() {
        _recalcProgress();
      });
    }

    if (!mounted) return;

    if (failedCelex.isNotEmpty) {
      await retryFailedCelex(failedCelex, newIndexName);
    }
    setState(() {
      if (failedCelex.isNotEmpty) {
        extractedCelex.add(
          'FAILED CELEX NUMBERS (will retry HTML upload): ${failedCelex.join(', ')}',
        );
      } else {
        extractedCelex.add('COMPLETED');
      }

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
    return Padding(
      // ...existing code...
      padding: const EdgeInsets.all(12.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SizedBox(height: 20),
          Text(
            'Enter EC File with List of Celex References to Upload',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          SizedBox(height: 20),
          Text(
            'First Choose Index In Dropdown List or Enter Index Name below!',
          ),

          // Button to open file picker
          InputDecorator(
            decoration: InputDecoration(
              labelText: 'Search Index', // Label embedded in the frame
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value:
                    indices.contains(newIndexName)
                        ? newIndexName
                        : null, // Default selected value
                items:
                    indices.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                onTap: () async {
                  await getCustomIndices(server, isAdmin, userPasskey);
                  if (!mounted) return;
                  setState(() {});
                },

                onChanged: (String? newValue) {
                  setState(() {
                    newIndexName = newValue!;
                  });
                  // Handle dropdown selection
                  print('Selected for Celex Refs upload: $newValue');
                },
              ),
            ),
          ),
          SizedBox(height: 10),
          TextField(
            decoration: InputDecoration(
              labelText:
                  'Index Name (Press Enter to Confirm - Allowed: a-z, 0-9, dot, underscore, hyphen. Cannot start with _ , - , +)',
              border: OutlineInputBorder(),
              errorText: _indexError2,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[a-z0-9._-]')),
            ],
            onChanged: (value) {
              final v = value.toLowerCase();
              setState(() {
                _indexBase2 = v;
                _indexError2 = _validateIndexName(v, userPasskey);
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
          (newIndexName == '' ||
                  newIndexName == "eurolex_" ||
                  _indexError2 != null)
              ? Text('Enter Index Name First!')
              : ElevatedButton(
                onPressed: pickAndLoadFile2,
                child: Text(
                  'Pick File with References (Upload to $newIndexName)',
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
              ? const Text('No file loaded.')
              : Container(
                width:
                    double.infinity, // Make container take full available width
                constraints: const BoxConstraints(
                  maxHeight: 400,
                  // Remove maxWidth or set to double.infinity for full width
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        SelectableText.rich(
                          TextSpan(
                            children:
                                extractedCelex.isEmpty
                                    ? [
                                      const TextSpan(
                                        text: 'No Celex Numbers Processed.',
                                      ),
                                    ]
                                    : buildCelexSpans(extractedCelex),
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
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

  // Index name input state and validation
  String _indexBaseManual = '';
  String? _indexErrorManual;

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

  Future manualCelexListUpload(manualCelexListEntry, newIndexName) async {
    setState(() {
      extractedCelex.clear();
      _progress = 0.01;
    });

    final logger = LogManager();
    final total = manualCelexListEntry.length;
    for (var index = 0; index < total; index++) {
      var i = manualCelexListEntry[index];
      extractedCelex.add('${index + 1}/$total: $i:');
      await uploadSparqlForCelex(i, newIndexName, "xhtml");

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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          SizedBox(height: 10),
          Text(
            'Manually Enter Comma-Separated Celex References to Upload',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          SizedBox(height: 20), // Space between the button and content box
          Text(
            'First Choose Index In Dropdown List or Enter Index Name below!',
          ),

          InputDecorator(
            decoration: InputDecoration(
              labelText: 'Search Index', // Label embedded in the frame
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value:
                    indices.contains(newIndexName)
                        ? newIndexName
                        : indices.first, // Default selected value
                items:
                    indices.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),

                onTap: () async {
                  await getCustomIndices(server, isAdmin, userPasskey);
                  if (!mounted) return;
                  setState(() {});
                },
                onChanged: (String? newValue) {
                  setState(() {
                    newIndexName = newValue!;
                  });
                  // Handle dropdown selection
                  print('Selected for manual Celex Refs upload: $newValue');
                },
              ),
            ),
          ),
          SizedBox(height: 10),
          TextField(
            decoration: InputDecoration(
              labelText:
                  'Index Name (Press Enter to Confirm - Allowed: a-z, 0-9, dot, underscore, hyphen. Cannot start with _ , - , +)',
              border: OutlineInputBorder(),
              errorText: _indexErrorManual,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[a-z0-9._-]')),
            ],
            onChanged: (value) {
              final v = value.toLowerCase();
              setState(() {
                _indexBaseManual = v;
                _indexErrorManual = _validateIndexName(v, userPasskey);
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

          SizedBox(height: 10),
          TextField(
            decoration: InputDecoration(
              labelText: 'Enter Celex Numbers (comma separated):',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                manualCelex = value.split(',').map((e) => e.trim()).toList();
              });
            },
          ),

          SizedBox(height: 10),
          (newIndexName == '' || newIndexName == "eurolex_")
              ? Text('Enter Index Name First!')
              : ElevatedButton(
                onPressed:
                    (_indexErrorManual != null)
                        ? null
                        : () {
                          if (newIndexName.isNotEmpty &&
                              newIndexName != "eurolex_") {
                            manualCelexListUpload(manualCelex, newIndexName);
                          } else {
                            print('Please enter an index name first.');
                          }
                        },
                child: Text('Process Celex Numbers (Upload to $newIndexName)'),
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
          // existing results container:
          manualCelex.isEmpty
              ? const Text('No file loaded.')
              : Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        SelectableText.rich(
                          TextSpan(
                            children:
                                extractedCelex.isEmpty
                                    ? [
                                      const TextSpan(
                                        text: 'No Celex Numbers Processed.',
                                      ),
                                    ]
                                    : buildCelexSpans(extractedCelex),
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
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
      String htmlContent = response.body;
      print('HTML content loaded successfully: celex: $celex, lang: $lang');
      return htmlContent;
    } else {
      final snippetLen =
          response.body.length > 100 ? 100 : response.body.length;
      final errorMsg =
          'Failed to load HTML in Harvest for celex: $celex, lang: $lang. '
          'Status code: ${response.statusCode}, ${response.headers}\n'
          '${response.body.substring(0, snippetLen)}';
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
      String htmlContent = response.body;
      print('HTML content loaded successfully: $url, lang: $lang');
      return htmlContent;
    } else {
      final snippetLen =
          response.body.length > 100 ? 100 : response.body.length;
      final errorMsg =
          'Failed to load HTML in Harvest for $url, lang: $lang. '
          'Status code: ${response.statusCode}, ${response.headers}\n'
          '${response.body.substring(0, snippetLen)}';
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
      },
    );
    if (response.statusCode == 200) {
      String responseBody = response.body;

      if (isAdmin) {
        print('Admin user detected, loading all indices.');
        String responseBody = response.body;
        indices =
            responseBody
                .split('\n') // Split the response into lines
                .toList();
        print('Indices loaded: $indices for server: $server');

        print('Indices for server $server loaded successfully: $responseBody');

        return responseBody; // Return the indices as a string
      }
      if (!isAdmin) {
        if (jsonSettings['access_key'] == "trial") {
          // In trial mode, show only the global index "*"
          indices = ["*"];
          print('Trial mode detected, showing only global index: $indices');
          return "Trial mode - limited indices";
        }

        print('Non-admin user detected, loading custom indices for id: $id');

        indices =
            responseBody
                .split('\n') // Split the response into lines
                .where(
                  (item) => item.contains(id),
                ) // Keep only items containing "eurolex"
                .toList();
        print('Indices loaded: $indices for server: $server');

        print('Indices for server $server loaded successfully: $responseBody');

        return responseBody; // Return the indices as a string
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
      },
    );
    if (response.statusCode == 200) {
      String responseBody = response.body;

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
  final username = 'admin';
  final password = 'admin';
  final basicAuth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
  print("userPasskey for getListIndicesFull: $userPasskey");
  List<List<String>> indicesList = [];
  try {
    final response = await http.get(
      Uri.parse('$server/_cat/indices?h=index,store.size,docs.count'),
      headers: {
        'Authorization': basicAuth,
        'x-api-key': jsonSettings['access_key'],
        'x-email': jsonSettings['user_email'],
      },
    );
    if (response.statusCode == 200) {
      String responseBody = response.body;

      // Each line: indexName store.size docs.count
      if (isAdmin) {
        final lines = responseBody
            .split('\n')
            .where(
              (line) =>
                  line.trim().isNotEmpty &&
                  !line.startsWith('.') &&
                  !line.startsWith('top_queries'),
            );
        final _indicesList =
            lines
                .map((line) {
                  final parts = line.split(RegExp(r'\s+'));
                  if (parts.length >= 3) {
                    // Cast to List<String>
                    return <String>[parts[0], parts[1], parts[2]];
                  } else {
                    return <String>[];
                  }
                })
                .where((sublist) => sublist.isNotEmpty)
                .toList();
        indicesList = _indicesList;
      } else {
        print(
          'Non-admin user detected, filtering indices for userPasskey: $userPasskey',
        );
        final lines = responseBody
            .split('\n')
            .where(
              (line) =>
                  line.trim().isNotEmpty &&
                  !line.startsWith('.') &&
                  !line.startsWith('top_queries') &&
                  line.contains(userPasskey),
            );
        final _indicesList =
            lines
                .map((line) {
                  final parts = line.split(RegExp(r'\s+'));
                  if (parts.length >= 3) {
                    // Cast to List<String>
                    return <String>[parts[0], parts[1], parts[2]];
                  } else {
                    return <String>[];
                  }
                })
                .where((sublist) => sublist.isNotEmpty)
                .toList();

        indicesList = _indicesList;
      }

      // Parse each line into [name, size, docs]

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
List<TextSpan> buildCelexSpans(List<String> lines) {
  return lines.map((line) {
    if (line == 'COMPLETED') {
      return const TextSpan(
        text: '\nCOMPLETED',
        style: TextStyle(fontWeight: FontWeight.bold),
      );
    }
    final parts = line.split(':');
    print(parts);
    if (parts.length < 2) {
      return TextSpan(text: '\n$line');
    }
    final left = parts[0].trim();
    final right =
        parts.length > 2 ? parts.sublist(2).map((s) => s.trim()).join(':') : '';
    final celex = parts[1].trim() + ': '; // handle any extra colons
    return TextSpan(
      children: [
        TextSpan(text: '\n$left: '),
        TextSpan(
          text: celex,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),

        TextSpan(text: right),
      ],
    );
  }).toList();
}

// In your build where you had SelectableText.rich(...)
