import 'dart:convert';
import 'dart:io';
import 'package:eurolex/setup.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'package:eurolex/logger.dart';
import 'package:eurolex/main.dart';

String getExecutableDir() {
  return File(Platform.resolvedExecutable).parent.path;
}

String getFilePath(String filename) {
  if (kReleaseMode) {
    // Windows release: use %APPDATA%\LegistracerEU
    final appData =
        Platform.environment['APPDATA']; // e.g. C:\Users\User\AppData\Roaming
    final baseDir =
        (appData != null && appData.isNotEmpty)
            ? p.join(appData, 'LegistracerEU')
            : getExecutableDir(); // fallback if APPDATA missing
    try {
      Directory(baseDir).createSync(recursive: true);
    } catch (_) {}
    return p.join(baseDir, filename);
  } else {
    // Debug: keep existing project-relative path
    print("Debug mode detected. Using relative path.");
    return 'c:/Users/Juraj/Documents/IT/OSLex/eurolex/lib/$filename';
  }
}

Future<void>
loadJsonFromFile() async //loads JSON from config.json file to the global variable jsonData
{
  try {
    // Read the JSON file
    final file = File(getFilePath('config.json'));
    final jsonString = await file.readAsString();

    // Decode the JSON
    jsonData = jsonDecode(jsonString);
  } catch (e) {
    print("Error loading JSON: $e");

    //assume the file does not exist and create a new one
    jsonData = {
      "default_index": "eurolex",
      "default_language": "EN",
      "last_opened_dir": "",
      "last_uploaded_file": "",
      "last_used_index": "eurolex",
      "last_search_query": "",
      "last_search_language": "EN",
      "upload_batch_size": 100,
      "auto_lookup": true,
      "os_server": "$osServer",
      "os_indices": ["*"],
    };

    writeConfigToFile(jsonData); //create the file with default values
  }
}

Future<void> writeJsonToFile(
  Map<String, dynamic> newJsonData,
  String filename,
) async {
  File file = File(getFilePath(filename));
  // Ensure parent directory exists
  try {
    await file.parent.create(recursive: true);
  } catch (e) {
    debugPrint('Dir create failed: ${file.parent.path} → $e');
  }

  // Pretty-print with 2-space indentation and UTF-8
  final jsonString = const JsonEncoder.withIndent('  ').convert(newJsonData);
  await file.writeAsString(jsonString, encoding: utf8);

  print("JSON written successfully to ${file.path}:\n$jsonString");
}

Future<void> writeTextToFile(String text, String filename) async {
  try {
    final directory = await getApplicationDocumentsDirectory();

    final file = File("${directory.path}/$filename");

    await file.writeAsString(text);
    print("Text written successfully to: ${file.path}");
  } catch (e) {
    print("Error writing text: $e");
  }
}

Future<void> writeLinesToFile(List<String> lines, String filename) async {
  final eol = Platform.isWindows ? '\r\n' : '\n';
  await writeTextToFile(lines.join(eol), filename);
}

Future<void>
loadSettingsFromFile() async //loads JSON from config.json file to the global variable jsonSettings
{
  try {
    // Read the JSON file
    final file = File(getFilePath('settings.json'));
    final jsonString = await file.readAsString();

    // Decode the JSON
    jsonSettings = jsonDecode(jsonString);

    print("JSON Settings from $file loaded successfully: $jsonSettings");

    LogManager logger = LogManager();
    logger.log("{$TimeOfDay.now()} $file loaded ok");
  } catch (e) {
    print(
      "Error loading JSON Settings: $e creating new file with default values",
    );
    LogManager logger = LogManager();
    logger.log("{$TimeOfDay.now()} Error loading Settings: $e");

    //assume the file does not exist and create a new one
    jsonSettings = {
      "theme": "light",
      "font_size": 14,
      "lang1": "EN",
      "lang2": "SK",
      "lang3": "CS",
      "display_lang1": true,
      "display_lang2": true,
      "display_lang3": true,
      "display_meta": true,
      "auto_lookup": true,
      "log_level": "info",
      "max_log_size": 999999,
      "access_key": "trial",
      "user_email": userEmail,
      "os_server": osServer,
      "os_indices": ["*"],
    };

    writeSettingsToFile(jsonSettings); //create the file with default values
  }
}

Future<void> writeSettingsToFile(Map<String, dynamic> newJsonData) async {
  try {
    // Get the writable settings file
    final file = File(getFilePath('settings.json'));

    // Encode the JSON with indentation for readability
    final jsonString = const JsonEncoder.withIndent('  ').convert(newJsonData);
    await file.writeAsString(jsonString);

    print("$file\nSettings JSON written successfully:\n$jsonString");
  } catch (e) {
    print("Error writing Settings JSON: $e");
  }
}

Future<void> writeConfigToFile(Map<String, dynamic> newJsonData) async {
  try {
    // Get the writable config file
    final file = File(getFilePath('config.json'));

    // Encode the JSON with indentation for readability
    final jsonString = const JsonEncoder.withIndent('  ').convert(newJsonData);
    await file.writeAsString(jsonString);

    print("Config JSON written successfully:\n$jsonString");
  } catch (e) {
    print("Error writing Config JSON: $e");
  }
}

Future<void> debugToFile(Map<String, dynamic> newJsonData) async {
  try {
    // Get the writable config file
    final file = File(getFilePath('debug.json'));

    // Encode the JSON with indentation for readability
    final jsonString = const JsonEncoder.withIndent('  ').convert(newJsonData);
    await file.writeAsString(jsonString);

    print("Debug Log written successfully:\n$jsonString");
  } catch (e) {
    print("Error writing Debug Log: $e");
  }
}




Future<Map<String, dynamic>> loadCelexYears([
  String path = 'data/celex_years.json',
]) async {
  final file = File(getFilePath(path));
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

bool getYearUploaded(Map<String, dynamic> data, int year) {
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
    };
  }
  range['end'] = newEndYear;
}

