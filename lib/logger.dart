import 'dart:io';
import 'package:path_provider/path_provider.dart';

class LogManager {
  static const int maxLogSize = 90000000; // bytes (adjust as needed)

  // Backward compatibility: keep existing static name
  static const String fileName = "OSJSON-log.txt";

  // New per-instance filename (defaults to the static one)
  final String _fileName;

  const LogManager({String? fileName})
    : _fileName = fileName ?? LogManager.fileName;

  Future<String> get _logFilePath async {
    final directory = await getApplicationDocumentsDirectory();
    return "${directory.path}/$_fileName";
  }

  Future<File> get _logFile async {
    final path = await _logFilePath;
    return File(path);
  }

  Future<void> log(String message) async {
    final file = await _logFile;
    final logEntry = "${DateTime.now().toIso8601String()}, $message\n";

    String currentContent = "";
    if (await file.exists()) {
      currentContent = await file.readAsString();
    }

    String updatedContent = currentContent + logEntry;

    if (updatedContent.length > maxLogSize) {
      int trimFrom = updatedContent.length - maxLogSize;
      updatedContent = updatedContent.substring(trimFrom);
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
