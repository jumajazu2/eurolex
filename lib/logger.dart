import 'dart:io';
import 'package:path_provider/path_provider.dart';

class LogManager {
  static const int maxLogSize = 10000; // bytes (adjust as needed)
  static const String fileName = "OSJSON-log.txt";

  Future<String> get _logFilePath async {
    final directory = await getApplicationDocumentsDirectory();
    return "${directory.path}/$fileName";
  }

  Future<File> get _logFile async {
    final path = await _logFilePath;
    return File(path);
  }

  Future<void> log(String message) async {
    final file = await _logFile;
    final logEntry = "${DateTime.now().toIso8601String()} - $message\n";

    String currentContent = "";
    if (await file.exists()) {
      currentContent = await file.readAsString();
    }

    String updatedContent = currentContent + logEntry;

    if (updatedContent.length > maxLogSize) {
      // Trim oldest part to maintain max size
      int trimFrom = updatedContent.length - maxLogSize;
      updatedContent = updatedContent.substring(trimFrom);
      // Optional: start from next newline to avoid partial log line
      int newLineIndex = updatedContent.indexOf("\n");
      if (newLineIndex != -1) {
        updatedContent = updatedContent.substring(newLineIndex + 1);
      }
    }

    await file.writeAsString(updatedContent);
  }

  Future<String> readLogs() async {
    final file = await _logFile;
    if (await file.exists()) {
      return await file.readAsString();
    }
    return "";
  }
}


/*
HOW TO USE

final logger = LogManager();

void someFunction() {
  logger.log("Something happened!");
}



*/