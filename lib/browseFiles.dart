import 'dart:ui';

import 'package:LegisTracerEU/preparehtml.dart';
import 'package:LegisTracerEU/processDOM.dart';
import 'package:LegisTracerEU/setup.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:LegisTracerEU/harvest_progress.dart';
import 'package:LegisTracerEU/harvest_progress_ui.dart';
import 'package:LegisTracerEU/testHtmlDumps.dart';

import 'package:html/parser.dart' as html_parser;

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:LegisTracerEU/main.dart';
import 'package:LegisTracerEU/logger.dart';
import 'package:LegisTracerEU/file_handling.dart';
import 'package:path/path.dart' as path;

String pathDirEN =
    r'\\OPENMEDIAVAULT\ExtSSD\EurLexDump\LEG_EN_HTML_20250601_00_00'; // Windows path
String pathDirSK =
    r'\\OPENMEDIAVAULT\ExtSSD\EurLexDump\LEG_SK_HTML_20250601_00_00'; // Windows path
String pathDirCZ =
    r'\\OPENMEDIAVAULT\ExtSSD\EurLexDump\LEG_CS_HTML_20250601_00_00'; // Windows path
String pathDirMTD =
    r'\\OPENMEDIAVAULT\ExtSSD\EurLexDump\LEG_MTD_HTML_20250601_00_00'; // Windows path

final logger = LogManager();
var indexName = 'eurolex4'; // Index name for logging purposes

final dirEN = Directory(pathDirEN);
final dirSK = Directory(pathDirSK);
final dirCZ = Directory(pathDirCZ);
final dirMTD = Directory(pathDirMTD);

void listFilesInDirEN() async {
  print('Checking directory: ${dirEN.path}');

  logger.log("******Process started for directory: ${dirEN.path}");

  int pointer = 0;

  if (await dirEN.exists()) {
    try {
      List<FileSystemEntity> files = dirEN.listSync();
      files.sort((a, b) => a.path.compareTo(b.path));

      if (files.isEmpty) {
        print('Directory is accessible but contains no files.');
      } else {
        int startIndex = 0; //to restart data processing into OS after a failure
        for (int i = startIndex; i < files.length; i++) {
          dirPointer = i; // Update the global pointer for directory processing
          var file = files[i]; //first level of subfolders
          print(file.path);

          print(
            'PROGRESS: Total folders: ${files.length}, processed folders: $pointer',
          );
          pointer++;
          var currentDir = file.path;
          print('Current directory: $currentDir');

          //create localised directory paths

          var checkEnDir = await checkDir(
            Directory(currentDir),
          ); //return the list of accessible directories for EN

          String enDir = currentDir;

          var skDir = currentDir.replaceFirst(r"_EN_", r"_SK_");
          var czDir = currentDir.replaceFirst(r"_EN_", r"_CS_");

          var checkSkDir = await checkDir(Directory(skDir));
          print(
            "dirpointer $i, checkSkDir.length = ${checkSkDir?.length ?? "null"},  checkSkDir = $checkSkDir",
          ); //return the list of accessible directories for EN

          var checkCzDir = await checkDir(
            Directory(czDir),
          ); //return the list of accessible directories for EN
          print(
            "dirpointer $i, checkCzDir.length = ${checkCzDir?.length ?? "null"}, checkCzDir = $checkCzDir",
          );
          print(
            "dirpointer $i, checkEnDir.length = ${checkEnDir?.length ?? "null"}, checkEnDir = $checkEnDir",
          );
          if ((checkSkDir == null) || (checkCzDir == null))
          //for now, later if at least one file is avaible add it and use some placeholder for the unavailable language
          {
            print(
              "Directory does not exist or is not accessible for SK or CZ, skipping",
            );

            logger.log(
              "$dirPointer, ${currentDir.split(r"\").last}, NotProcessed, Files for SK and/or CZ do not exist",
            );
            continue; //this is why not logging
          }

          if (checkEnDir.length == 1 &&
              checkSkDir.length == 1 &&
              checkCzDir.length == 1) {
            print(
              "dirpointer $i EN, SK and CZ directories -one for each language- are accessible and contain files, no change in paths.",
            );
          } else if (checkEnDir.length == 2 &&
              (checkSkDir.length == 1 || checkCzDir.length == 1)) {
            print(
              "dirpointer $i EN, SK and CZ directories differ - 2 for EN, 1 for SK or CZ, EN $checkEnDir, SK $checkSkDir, CZ $checkCzDir.",
            );
            if (checkSkDir[0].contains(r'\html') &&
                checkEnDir[0].contains(r'\html') == "html") {
              enDir = checkEnDir[0];
              print(
                "dirpointer $i SK contains only html $skDir, EN dir will read the file from html dir: $enDir",
              );
            } else if (checkSkDir[0].contains(r'\html') &&
                checkEnDir[1].contains(r'\html')) {
              enDir = checkEnDir[1];

              print(
                "dirpointer $i SK contains only html $skDir, EN dir will read the file from html dir: $enDir",
              );
            }
          }

          if (checkSkDir[0].contains(r'\xhtml') &&
              checkEnDir[0].contains(r'\xhtml')) {
            enDir = checkEnDir[0];
            print(
              "dirpointer $i SK contains only xhtml $skDir, EN dir will read the file from xhtml dir: $enDir",
            );
          } else if (checkSkDir.isNotEmpty &&
              checkEnDir.length > 1 &&
              checkSkDir[0].contains(r'\xhtml') &&
              checkEnDir[1].contains(r'\xhtml')) {
            enDir = checkEnDir[1];

            print(
              "dirpointer $i SK contains only xhtml $skDir, EN dir will read the file from xhtml dir: $enDir",
            );
          }

          var enFile = await getFile(Directory(enDir));
          var skFile = await getFile(Directory(skDir));
          var czFile = await getFile(Directory(czDir));
          var mtdDir = currentDir.replaceFirst(r"_EN_", r"_MTD_");

          var mtdFile = await getFile(Directory(mtdDir));
          print(
            "dirpointer $i Files before passing to extractParagraphs ${enFile.length}, ${skFile.length}, ${czFile.length}, ${mtdFile.length}",
          );
          var dirID = currentDir.split(r"\").last;
          print('Directory ID: $dirID');

          var paragraphs = extractParagraphs(
            enFile,
            skFile,
            czFile,
            mtdFile,
            dirID,
            indexName,
          );

          print(
            "|*********************************************************************************************",
          );
        }
      }
    } catch (e) {
      print('Error accessing directory: $e');
    }
  } else {
    print('Directory does not exist or is not accessible: ${dirEN.path}');
  }
}

//checks if the Cellar ID directory contains one or two subdirectories html and xhtml
Future checkDir(Directory dir) async {
  List accessibleDirs = [];

  if (await dir.exists()) {
    try {
      List<FileSystemEntity> files2 =
          dir.listSync(); //second level of subfolders -html, xhtml

      print(
        "checking where files are: $files2, number of items: ${files2.length}",
      );

      if (files2.isEmpty) {
        print('Directory is accessible but contains no files.');
        return dir;
      } else {
        for (var file
            in files2) //looping through accessible directories html or xhtml
        {
          print('File path in level 2: $file');

          if (file is Directory) {
            // If the file is a directory, you can call the function recursively

            accessibleDirs.add(file.path);

            print(
              "YYY accessible director ${file.path} in $dir",
            ); //file is html or xhtml
          }

          // You can also call the function to list files in the subdirectory
        }

        print("returning accessible directories: $accessibleDirs");
        return accessibleDirs; // Return the list of accessible directories
      }
    } catch (e) {
      print('Error accessing directory: $e');
    }
  } else {
    print('Directory does not exist or is not accessible: ${dir.path}');
  }
}

Future<String> getFile(dir) async {
  // Function to get file from directory, first must skip one or more subdirectories then read file from the lowest level
  print('getting file from directory: $dir');

  if (await dir.exists()) {
    try {
      List<FileSystemEntity> files2 =
          dir.listSync(); //second level of subfolders -html, xhtml

      print("second level files: $files2, number of items: ${files2.length}");

      if (files2.isEmpty) {
        print('Directory is accessible but contains no files.');
      } else {
        for (var file in files2) {
          print('File path in level 2: $file');

          if (file is File &&
              (file.path.endsWith('.html') || file.path.endsWith('.rdf'))) {
            // If the subfile is a file, read it
            print(file.path);
            final bytes = await file.readAsBytes();
            String readFile = utf8.decode(bytes, allowMalformed: true);
            // print('Reading file: ${readFile.substring(0, 50)}...');

            if (readFile.isNotEmpty) {
              var fileName = path.basename(file.path);
              print('File name: $fileName');
              readFile = '$fileName@@@$readFile';
              //   print('File: ${readFile.substring(0, 50)}');
              return readFile; // Return the read file content
            } else {
              print('File is empty, skipping...');
              return '';
            }
          }

          if (file is Directory) {
            // If the file is a directory, you can call the function recursively
            List<FileSystemEntity> filesInDir2 = file.listSync();

            print(
              "YYY Files inDir2: $filesInDir2, file $file",
            ); //file is html or xhtml

            for (var subfile in filesInDir2) {
              if (subfile is File &&
                  (subfile.path.endsWith('.html') ||
                      subfile.path.endsWith('.rdf'))) {
                // If the subfile is a file, read it
                print(subfile.path);

                try {
                  final bytes = await subfile.readAsBytes();
                  String readFile = utf8.decode(bytes, allowMalformed: true);
                  //  print('Reading file: ${readFile.substring(0, 50)}...');

                  if (readFile.isNotEmpty) {
                    var fileName = path.basename(subfile.path);
                    print('File name: $fileName');
                    readFile = '$fileName@@@$readFile';
                    //  print('File: ${readFile.substring(0, 50)}...');

                    return readFile; // Return the read file content
                  } else {
                    print('File is empty, skipping...');
                    return '';
                  }
                } catch (e) {
                  print('Error reading file as UTF-8: ${subfile.path} - $e');
                  continue;
                }
              }

              if (subfile is Directory) {
                // Go even deeper...
                List<FileSystemEntity> filesInSubDir = subfile.listSync();

                print('is directory and contains these files: $filesInSubDir');

                print(
                  "Only one low level directory detected, the output will contain only one file",
                );

                for (var fileEntity in filesInSubDir) {
                  if (fileEntity is File) {
                    final bytes = await fileEntity.readAsBytes();
                    String readFile = utf8.decode(bytes, allowMalformed: true);
                    print('Reading file: ${readFile.substring(0, 50)}...');

                    if (readFile.isNotEmpty) {
                      var fileName = path.basename(readFile);
                      print('File name: $fileName');
                      readFile = '$fileName@@@$readFile';
                      //   print('File: ${readFile.substring(0, 50)}...');

                      return readFile;
                    } // Return the read file content
                    if (readFile.isEmpty) {
                      print('File is empty, skipping...');
                      return '';
                    }
                  }
                }
              }

              // You can also call the function to list files in the subdirectory
            }
          }
        }
      }
    } catch (e) {
      print('Error accessing directory: $e');
    }
  } else {
    print('Directory does not exist or is not accessible: ${dir.path}');
  }

  return ''; // Return empty string if no file found
}

class BrowseFilesWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Show the interactive CelexYearsWidget instead of the batch processing UI
    if (isAdmin) return const CelexYearsWidget();
    return Container();
  }
}

Future<Map<String, dynamic>> loadCelexYears([
  String path = 'data/celex_years.json',
]) async {
  final supportPath = await getFilePath(path);
  File file = File(supportPath);
  if (!await file.exists()) {
    // Try MSIX PFN LocalState first
    final msixPath = await getMsixLocalStatePathIfExists(path);
    if (msixPath != null) {
      file = File(msixPath);
      print('Using MSIX LocalState celex years at $msixPath');
    } else {
      // Fallback to legacy Roaming
      final legacyPath = await getLegacyAppDataPathIfExists(path);
      if (legacyPath != null) {
        file = File(legacyPath);
        print('Using legacy celex years at $legacyPath');
      }
    }
  }
  if (!await file.exists()) {
    throw Exception('Celex years file not found: ${file.path}');
  }
  final s = await file.readAsString();
  return jsonDecode(s) as Map<String, dynamic>;
}

Future<void> saveCelexYears(
  Map<String, dynamic> data, [
  String path = 'data/celex_years.json',
]) async {
  await writeJsonToFile(data, path);
}

int getYearTotal(Map<String, dynamic> data, int year) {
  final y =
      (data['years'] as Map<String, dynamic>)['$year'] as Map<String, dynamic>;
  return (y['total'] as num).toInt();
}

void setYearTotal(Map<String, dynamic> data, int year, int total) {
  final years = data['years'] as Map<String, dynamic>;
  final y = years['$year'] as Map<String, dynamic>;
  y['total'] = total;
}

int getSectorCount(Map<String, dynamic> data, int year, String sector) {
  final y =
      (data['years'] as Map<String, dynamic>)['$year'] as Map<String, dynamic>;
  final sectors = y['sectors'] as Map<String, dynamic>;
  return ((sectors[sector] ?? 0) as num).toInt();
}

void setSectorCount(
  Map<String, dynamic> data,
  int year,
  String sector,
  int count,
) {
  final years = data['years'] as Map<String, dynamic>;
  final y = years['$year'] as Map<String, dynamic>;
  final sectors = y['sectors'] as Map<String, dynamic>;
  sectors[sector] = count;
  // Recompute total from sector values
  y['total'] = sectors.values
      .map((v) => (v as num).toInt())
      .fold(0, (a, b) => a + b);
}

bool getYearUploaded2(Map<String, dynamic> data, int year) {
  final y =
      (data['years'] as Map<String, dynamic>)['$year'] as Map<String, dynamic>;
  return (y['uploaded'] ?? false) as bool;
}

void setYearUploaded(Map<String, dynamic> data, int year, bool value) {
  final years = data['years'] as Map<String, dynamic>;
  final y = years['$year'] as Map<String, dynamic>;
  y['uploaded'] = value;
}

bool getSectorUploaded(Map<String, dynamic> data, int year, String sector) {
  final years = data['years'] as Map<String, dynamic>;
  final y = years['$year'] as Map<String, dynamic>;
  final m =
      (y['uploadedBySector'] as Map<String, dynamic>?) ?? <String, dynamic>{};
  return (m[sector] ?? false) as bool;
}

void setSectorUploaded(
  Map<String, dynamic> data,
  int year,
  String sector,
  bool value,
) {
  final years = data['years'] as Map<String, dynamic>;
  final y = years['$year'] as Map<String, dynamic>;
  final m =
      (y['uploadedBySector'] as Map<String, dynamic>?) ?? <String, dynamic>{};
  m[sector] = value;
  y['uploadedBySector'] = m;
}

String? getSectorSessionId(Map<String, dynamic> data, int year, String sector) {
  final years = data['years'] as Map<String, dynamic>;
  final y = years['$year'] as Map<String, dynamic>;
  final m = (y['sessionIds'] as Map<String, dynamic>?) ?? <String, dynamic>{};
  return m[sector] as String?;
}

void setSectorSessionId(
  Map<String, dynamic> data,
  int year,
  String sector,
  String? sessionId,
) {
  final years = data['years'] as Map<String, dynamic>;
  final y = years['$year'] as Map<String, dynamic>;
  final m = (y['sessionIds'] as Map<String, dynamic>?) ?? <String, dynamic>{};
  if (sessionId == null) {
    m.remove(sector);
  } else {
    m[sector] = sessionId;
  }
  y['sessionIds'] = m;
}

void extendRange(Map<String, dynamic> data, int newEndYear) {
  final range = data['range'] as Map<String, dynamic>;
  final start = (range['start'] as num).toInt();
  final currentEnd = (range['end'] as num).toInt();
  if (newEndYear <= currentEnd) return;

  final years = data['years'] as Map<String, dynamic>;
  for (int y = currentEnd + 1; y <= newEndYear; y++) {
    years['$y'] = {
      'total': 0,
      'sectors': {
        's0': 0,
        's1': 0,
        's2': 0,
        's3': 0,
        's4': 0,
        's5': 0,
        's6': 0,
        's7': 0,
        's8': 0,
        's9': 0,
        's10': 0,
      },
      'uploaded': false,
      'uploadedBySector': {
        's0': false,
        's1': false,
        's2': false,
        's3': false,
        's4': false,
        's5': false,
        's6': false,
        's7': false,
        's8': false,
        's9': false,
        's10': false,
      },
      'sessionIds': {},
    };
  }
  range['end'] = newEndYear;
}

class CelexYearsWidget extends StatefulWidget {
  const CelexYearsWidget({super.key});

  @override
  State<CelexYearsWidget> createState() => _CelexYearsWidgetState();
}

class _CelexYearsWidgetState extends State<CelexYearsWidget> {
  Map<String, dynamic>? data;
  bool saving = false;
  final expandedYears = <String>{};

  // Track active uploads: "year_sector" -> HarvestSession
  final Map<String, HarvestSession> _activeSessions = {};

  // Track which sector is expanded to show progress
  String? _expandedSectorKey;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final loaded =
          await loadCelexYears(); // defaults to data/celex_years.json
      setState(() => data = loaded);

      // Auto-load incomplete sessions to show progress immediately
      await _loadIncompleteSessions();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load celex years: $e')));
    }
  }

  /// Load all incomplete sessions referenced in celex_years.json
  Future<void> _loadIncompleteSessions() async {
    if (data == null) return;

    final yearsMap = data!['years'] as Map<String, dynamic>;
    for (final year in yearsMap.keys) {
      final yearData = yearsMap[year] as Map<String, dynamic>;
      final sessionIds = yearData['sessionIds'] as Map<String, dynamic>? ?? {};
      final uploadedBySector =
          yearData['uploadedBySector'] as Map<String, dynamic>? ?? {};

      for (final sector in sessionIds.keys) {
        final sessionId = sessionIds[sector] as String?;
        final uploaded = uploadedBySector[sector] as bool? ?? false;

        // Load session if it exists and is not completed
        if (sessionId != null && !uploaded) {
          try {
            final session = await HarvestSession.load(sessionId);
            if (session != null && session.completedAt == null) {
              final key = '${year}_$sector';
              if (mounted) {
                setState(() {
                  _activeSessions[key] = session;
                });
              }
            }
          } catch (e) {
            print('Failed to load session $sessionId: $e');
          }
        }
      }
    }
  }

  Future<void> _save() async {
    if (data == null) return;
    setState(() => saving = true);
    try {
      await saveCelexYears(data!);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Saved changes')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (data == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final yearsMap = (data!['years'] as Map<String, dynamic>);
    final years =
        yearsMap.keys.toList()
          ..sort((a, b) => int.parse(b).compareTo(int.parse(a)));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Text(
                'Celex Sectors ${data!['range']['start']}–${data!['range']['end']}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              if (saving)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              // Button to show progress table for active sessions
              if (_activeSessions.isNotEmpty && _expandedSectorKey == null)
                TextButton.icon(
                  onPressed: () async {
                    // Reload session from disk before showing to get latest progress
                    final firstKey = _activeSessions.keys.first;
                    final session = _activeSessions[firstKey];
                    if (session != null) {
                      final reloadedSession = await HarvestSession.load(
                        session.sessionId,
                      );
                      if (reloadedSession != null && mounted) {
                        setState(() {
                          _activeSessions[firstKey] = reloadedSession;
                          _expandedSectorKey = firstKey;
                        });
                      }
                    }
                  },
                  icon: const Icon(Icons.table_chart),
                  label: Text('Show Progress (${_activeSessions.length})'),
                  style: TextButton.styleFrom(foregroundColor: Colors.blue),
                ),
              IconButton(
                onPressed: () async {
                  await _loadIncompleteSessions();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Progress refreshed')),
                  );
                },
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh progress from disk',
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: saving ? null : _save,
                icon: const Icon(Icons.save),
                label: const Text('Save'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: years.length,
            itemBuilder: (ctx, i) {
              final year = years[i];
              final y = yearsMap[year] as Map<String, dynamic>;
              final total = (y['total'] as num?)?.toInt() ?? 0;
              final uploaded = (y['uploaded'] ?? false) as bool;
              final sectors = (y['sectors'] as Map<String, dynamic>);
              final uploadedBySector =
                  (y['uploadedBySector'] as Map<String, dynamic>? ??
                      <String, dynamic>{});
              final isExpanded = expandedYears.contains(year);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 180, // adjust to your layout; 160–200 works well
                        child: Row(
                          children: [
                            Text('$year', style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'total $total',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontFeatures: [
                                    FontFeature.tabularFigures(),
                                  ], // align digits
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Uploaded',
                            style: TextStyle(fontSize: 12),
                          ),
                          Transform.scale(
                            scale: 0.9,
                            child: Checkbox(
                              value: uploaded,
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              onChanged: (v) {
                                setState(() {
                                  setYearUploaded(
                                    data!,
                                    int.parse(year),
                                    v ?? false,
                                  );
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSectorButtonsRow(
                          year,
                          sectors,
                          uploadedBySector,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // Progress widget at bottom when sector is uploading
        if (_expandedSectorKey != null &&
            _activeSessions[_expandedSectorKey] != null)
          Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(
                top: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: HarvestProgressWidget(
              session: _activeSessions[_expandedSectorKey]!,
              onCancel: () async {
                if (mounted) {
                  setState(() {
                    _expandedSectorKey = null;
                  });
                }
              },
            ),
          ),
      ],
    );
  }

  Future<void> _startSectorUpload(int year, String sector) async {
    final sectorNum = int.parse(sector.replaceAll('s', ''));
    final indexName = 'eurolex_sparql_sector$sectorNum';
    final key = '${year}_$sector';

    if (mounted) {
      setState(() {
        _expandedSectorKey = key;
      });
    }

    try {
      final session = await uploadTestSparqlSectorYearWithProgress(
        sectorNum,
        year,
        indexName,
        onProgressUpdate: (updatedSession) {
          if (mounted) {
            setState(() {
              _activeSessions[key] = updatedSession;
            });
          }
        },
        onSessionCreated: (sessionId) {
          // Save session ID immediately when upload starts
          if (mounted) {
            setState(() {
              setSectorSessionId(data!, year, sector, sessionId);
            });
            _save();
          }
        },
      );

      // Mark as uploaded when complete
      if (mounted) {
        setState(() {
          setSectorUploaded(data!, year, sector, true);
          _activeSessions[key] = session;
        });
        await _save();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }

  Future<void> _resumeSectorUpload(
    int year,
    String sector,
    String sessionId,
  ) async {
    final key = '${year}_$sector';

    try {
      final session = await HarvestSession.load(sessionId);
      if (session == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Session not found')));
        }
        return;
      }

      if (session.completedAt != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Session already completed')),
          );
        }
        return;
      }

      if (mounted) {
        setState(() {
          _activeSessions[key] = session;
          _expandedSectorKey = key;
        });
      }

      final sectorNum = int.parse(sector.replaceAll('s', ''));
      final resumedSession = await uploadTestSparqlSectorYearWithProgress(
        sectorNum,
        year,
        session.indexName,
        startPointer: session.currentPointer,
        onProgressUpdate: (updatedSession) {
          if (mounted) {
            setState(() {
              _activeSessions[key] = updatedSession;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          setSectorUploaded(data!, year, sector, true);
          _activeSessions[key] = resumedSession;
        });
        await _save();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Resume failed: $e')));
      }
    }
  }

  Widget _buildSectorButtonsRow(
    String year,
    Map<String, dynamic> sectors,
    Map<String, dynamic> uploadedBySector,
  ) {
    final entries =
        sectors.keys.toList()..sort((a, b) {
          int ai = int.tryParse(a.replaceAll('s', '')) ?? 0;
          int bi = int.tryParse(b.replaceAll('s', '')) ?? 0;
          return ai.compareTo(bi);
        });

    return LayoutBuilder(
      builder: (ctx, constraints) {
        const spacing = 8.0;
        const minCellWidth = 80.0;
        final count = entries.length;
        final available = constraints.maxWidth - spacing * (count - 1);
        final proposed = available / count;
        final useScroll = proposed < minCellWidth;
        final cellWidth = useScroll ? minCellWidth : proposed;

        final row = Row(
          children: List.generate(count, (i) {
            final key = entries[i];
            final countVal = ((sectors[key] ?? 0) as num).toInt();
            final uploaded = (uploadedBySector[key] ?? false) as bool;
            final sessionId = getSectorSessionId(data!, int.parse(year), key);
            final yearInt = int.parse(year);
            final sectorKey = '${year}_$key';
            final isActive = _activeSessions[sectorKey] != null;
            final session = _activeSessions[sectorKey];
            final isIncomplete = sessionId != null && !uploaded;

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: cellWidth,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        uploaded
                            ? Colors.green.withOpacity(0.15)
                            : isActive
                            ? Colors.blue.withOpacity(0.15)
                            : null,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isActive ? Colors.blue : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${key.toUpperCase()}: $countVal',
                        style: const TextStyle(
                          fontSize: 11,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (uploaded && !isIncomplete)
                        const Icon(
                          Icons.check_circle,
                          size: 16,
                          color: Colors.green,
                        )
                      else if (isIncomplete)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.play_arrow, size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Resume',
                              onPressed:
                                  () => _resumeSectorUpload(
                                    yearInt,
                                    key,
                                    sessionId!,
                                  ),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${(session?.progressPercentage ?? 0).toStringAsFixed(0)}%',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ],
                        )
                      else if (isActive)
                        Text(
                          '${session!.progressPercentage.toStringAsFixed(0)}%',
                          style: const TextStyle(fontSize: 10),
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.upload, size: 16),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Upload',
                          onPressed:
                              countVal > 0
                                  ? () => _startSectorUpload(yearInt, key)
                                  : null,
                        ),
                    ],
                  ),
                ),
                if (i < count - 1) const SizedBox(width: spacing),
              ],
            );
          }),
        );

        return useScroll
            ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: row,
            )
            : row;
      },
    );
  }

  Widget _buildSectorTogglesRow(
    String year,
    Map<String, dynamic> sectors,
    Map<String, dynamic> uploadedBySector,
  ) {
    final entries =
        sectors.keys.toList()..sort((a, b) {
          int ai = int.tryParse(a.replaceAll('s', '')) ?? 0;
          int bi = int.tryParse(b.replaceAll('s', '')) ?? 0;
          return ai.compareTo(bi);
        });

    return LayoutBuilder(
      builder: (ctx, constraints) {
        const spacing = 8.0;
        const minCellWidth = 64.0; // compact but readable
        final count = entries.length;
        final available = constraints.maxWidth - spacing * (count - 1);
        final proposed = available / count;
        final useScroll = proposed < minCellWidth;
        final cellWidth = useScroll ? minCellWidth : proposed;

        final row = Row(
          children: List.generate(count, (i) {
            final key = entries[i];
            final countVal = ((sectors[key] ?? 0) as num).toInt();
            final uploaded = (uploadedBySector[key] ?? false) as bool;

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: cellWidth,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: uploaded ? Colors.green.withOpacity(0.15) : null,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Transform.scale(
                        scale: 0.85,
                        child: Checkbox(
                          value: uploaded,
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          onChanged: (v) {
                            setState(() {
                              setSectorUploaded(
                                data!,
                                int.parse(year),
                                key,
                                v ?? false,
                              );
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${key.toUpperCase()}: $countVal',
                        style: const TextStyle(
                          fontSize: 12,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < count - 1) const SizedBox(width: spacing),
              ],
            );
          }),
        );

        return useScroll
            ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: row,
            )
            : row;
      },
    );
  }

  Widget _buildSectorsGrid(
    String year,
    Map<String, dynamic> sectors,
    Map<String, dynamic> uploadedBySector,
  ) {
    final entries =
        sectors.keys.toList()..sort((a, b) {
          // Sort by numeric sector value (s0..s10)
          int ai = int.tryParse(a.replaceAll('s', '')) ?? 0;
          int bi = int.tryParse(b.replaceAll('s', '')) ?? 0;
          return ai.compareTo(bi);
        });

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final isWide = constraints.maxWidth > 700;
        final crossAxisCount = isWide ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: entries.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: isWide ? 4.5 : 3.8,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemBuilder: (ctx, i) {
            final key = entries[i]; // 's0'...'s10'
            final count = ((sectors[key] ?? 0) as num).toInt();
            final uploaded = (uploadedBySector[key] ?? false) as bool;

            return Container(
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(ctx).dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$key: $count',
                      style: const TextStyle(
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  Checkbox(
                    value: uploaded,
                    onChanged: (v) {
                      setState(() {
                        setSectorUploaded(
                          data!,
                          int.parse(year),
                          key,
                          v ?? false,
                        );
                      });
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
