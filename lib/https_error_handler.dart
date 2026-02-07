import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:LegisTracerEU/logger.dart';
import 'package:LegisTracerEU/file_handling.dart';
import 'package:LegisTracerEU/setup.dart' show userEmail;
import 'package:LegisTracerEU/preparehtml.dart' show server;
import 'package:LegisTracerEU/main.dart' show jsonSettings;

/// SSL/TLS Error Handler
/// Provides detailed logging and user-friendly error dialogs for certificate verification failures
class HttpsErrorHandler {
  static final LogManager _logger = const LogManager();

  /// Check if an exception is an SSL/TLS certificate error
  static bool isCertificateError(dynamic error) {
    if (error is HandshakeException) {
      return true;
    }
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('handshake') ||
        errorStr.contains('certificate_verify_failed') ||
        errorStr.contains('unable to get local issuer certificate') ||
        errorStr.contains('certificate verify failed') ||
        errorStr.contains('ssl') ||
        errorStr.contains('tls');
  }

  /// Log detailed SSL error information
  static Future<String> logCertificateError(
    dynamic error,
    StackTrace? stackTrace,
    String operation,
  ) async {
    final timestamp = DateTime.now().toIso8601String();
    final errorDetails = StringBuffer();

    errorDetails.writeln('\n========== SSL/TLS ERROR ==========');
    errorDetails.writeln('Timestamp: $timestamp');
    errorDetails.writeln('Operation: $operation');
    errorDetails.writeln('Server: $server');
    errorDetails.writeln('User Email: $userEmail');
    errorDetails.writeln('API Key: ${jsonSettings['access_key'] ?? 'not set'}');
    errorDetails.writeln('\nError Type: ${error.runtimeType}');
    errorDetails.writeln('Error Message: $error');

    // Platform information
    errorDetails.writeln('\nPlatform: ${Platform.operatingSystem}');
    errorDetails.writeln('OS Version: ${Platform.operatingSystemVersion}');
    errorDetails.writeln('Dart Version: ${Platform.version}');

    // Stack trace if available
    if (stackTrace != null) {
      errorDetails.writeln('\nStack Trace:');
      errorDetails.writeln(stackTrace.toString());
    }

    errorDetails.writeln('\n=================================\n');

    final logMessage = errorDetails.toString();
    await _logger.log(logMessage);
    print(logMessage);

    return logMessage;
  }

  /// Show user-friendly error dialog with option to send error report
  static Future<void> showCertificateErrorDialog(
    BuildContext context,
    dynamic error,
    String operation,
  ) async {
    if (!context.mounted) return;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: const [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 32,
                ),
                SizedBox(width: 12),
                Expanded(child: Text('Connection Security Error')),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'The application cannot establish a secure connection to the server due to a certificate verification failure.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Common causes:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  _buildBulletPoint(
                    'Outdated system certificate store (Let\'s Encrypt root certificates)',
                  ),
                  _buildBulletPoint(
                    'Corporate proxy or firewall blocking HTTPS',
                  ),
                  _buildBulletPoint('System date/time incorrect'),
                  _buildBulletPoint(
                    'Antivirus software intercepting connections',
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Recommended solutions:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  _buildBulletPoint(
                    'Update Windows certificates via Windows Update',
                  ),
                  _buildBulletPoint('Verify system date and time are correct'),
                  _buildBulletPoint('Temporarily disable antivirus to test'),
                  _buildBulletPoint(
                    'Contact your IT administrator if on corporate network',
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'Operation: $operation',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Server: $server',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Error: ${_truncateError(error.toString())}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.red,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Close'),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.email),
                label: const Text('Send Error Report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
    );

    if (result == true && context.mounted) {
      await _sendErrorReport(context, error, operation);
    }
  }

  static Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 16)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  static String _truncateError(String error, [int maxLength = 150]) {
    if (error.length <= maxLength) return error;
    return '${error.substring(0, maxLength)}...';
  }

  /// Send error report to support endpoint
  static Future<void> _sendErrorReport(
    BuildContext context,
    dynamic error,
    String operation,
  ) async {
    if (!context.mounted) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Sending error report...'),
                  ],
                ),
              ),
            ),
          ),
    );

    try {
      // Collect detailed error information
      final errorLog = await logCertificateError(
        error,
        StackTrace.current,
        operation,
      );
      final recentLog = await _logger.readLogs();
      final logTail =
          recentLog.length > 3000
              ? recentLog.substring(recentLog.length - 3000)
              : recentLog;

      final message = '''
SSL/TLS Certificate Error Report

$errorLog

Recent Application Logs:
---
$logTail
''';

      // Try to send via support endpoint (using HTTP fallback if HTTPS fails)
      final supportUrl =
          server.startsWith('https://')
              ? server.replaceFirst('https://', 'http://')
              : server;

      final response = await http
          .post(
            Uri.parse('$supportUrl/support'),
            headers: {
              'Content-Type': 'application/json',
              'x-api-key': jsonSettings['access_key'] ?? '',
            },
            body: jsonEncode({
              'email': userEmail.isNotEmpty ? userEmail : 'user@unknown.local',
              'subject': 'SSL/TLS Certificate Error - $operation',
              'message': message,
              'apiKey': jsonSettings['access_key'] ?? '',
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (!context.mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Error report sent successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      // Show fallback - copy error to clipboard or save to file
      await _showSendFailureDialog(context, error, operation);
    }
  }

  static Future<void> _showSendFailureDialog(
    BuildContext context,
    dynamic error,
    String operation,
  ) async {
    final errorLog = await logCertificateError(
      error,
      StackTrace.current,
      operation,
    );

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Cannot Send Report'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Unable to send error report automatically. The error has been logged to:',
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.grey[200],
                  child: SelectableText(
                    LogManager.fileName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Please manually send this log file to support.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  try {
                    final logPath = await getFilePath(LogManager.fileName);
                    final dirPath = logPath.substring(
                      0,
                      logPath.lastIndexOf(Platform.pathSeparator),
                    );
                    await Process.run('explorer', [dirPath]);
                  } catch (e) {
                    print('Failed to open log folder: $e');
                  }
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: const Text('Open Log Folder'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  /// Wrap HTTP operations with certificate error handling
  static Future<T> wrapHttpOperation<T>({
    required BuildContext? context,
    required Future<T> Function() operation,
    required String operationName,
    T? fallbackValue,
  }) async {
    try {
      return await operation();
    } catch (e, stackTrace) {
      if (isCertificateError(e)) {
        await logCertificateError(e, stackTrace, operationName);

        if (context != null && context.mounted) {
          await showCertificateErrorDialog(context, e, operationName);
        }

        if (fallbackValue != null) {
          return fallbackValue;
        }
      }
      rethrow;
    }
  }
}
