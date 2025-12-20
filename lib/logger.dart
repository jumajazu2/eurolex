import 'dart:io';
import 'package:LegisTracerEU/file_handling.dart';

class LogManager {
  static const int maxLogSize = 90000000; // bytes (adjust as needed)

  // Backward compatibility: keep existing static name
  static const String fileName = "OSJSON-log.txt";

  // New per-instance filename (defaults to the static one)
  final String _fileName;

  const LogManager({String? fileName})
    : _fileName = fileName ?? LogManager.fileName;

  Future<String> get _logFilePath async => getFilePath(_fileName);

  Future<File> get _logFile async {
    final path = await _logFilePath;
    final file = File(path);
    // Ensure parent directory exists
    await file.parent.create(recursive: true);
    return file;
  }

  Future<void> log(String message) async {
    final file = await _logFile;
    final logEntry = "${DateTime.now().toIso8601String()}, $message\n";

    if (await file.exists()) {
      final len = await file.length();
      // Fast append if below cap
      if (len + logEntry.length <= LogManager.maxLogSize) {
        await file.writeAsString(logEntry, mode: FileMode.append, flush: true);
        return;
      }
    }

    // Fallback: read + trim + overwrite
    var content = '';
    if (await file.exists()) {
      content = await file.readAsString();
    }
    var updated = content + logEntry;
    if (updated.length > LogManager.maxLogSize) {
      final overflow = updated.length - LogManager.maxLogSize;
      updated = updated.substring(overflow);
      final nl = updated.indexOf('\n');
      if (nl != -1) updated = updated.substring(nl + 1);
    }
    await file.writeAsString(updated, mode: FileMode.write, flush: true);
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
