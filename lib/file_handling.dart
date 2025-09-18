import 'dart:convert';
import 'dart:io';
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
    // In release mode, use the executable directory
    final exeDir = getExecutableDir();
    return p.join(exeDir, filename);
  } else {
    // In debug mode, use a relative path
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

Future<void> writeJsonToFile(Map<String, dynamic> newJsonData) async {
  try {
    // Get the writable config file
    final file = File(getFilePath('config.json'));

    // Encode the JSON and write it to the file
    final jsonString = jsonEncode(newJsonData);
    await file.writeAsString(jsonString);

    print("JSON written successfully: $jsonString");
  } catch (e) {
    print("Error writing JSON: $e");
  }
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

    print("JSON Settings loaded successfully: $jsonSettings");

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
      "lang3": "CZ",
      "display_lang1": true,
      "display_lang2": true,
      "display_lang3": true,
      "display_meta": true,
      "auto_lookup": true,
      "log_level": "info",
      "max_log_size": 999999,
      "access_key": "trial",
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

    print("Settings JSON written successfully:\n$jsonString");
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
