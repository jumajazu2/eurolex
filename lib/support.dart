import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:LegisTracerEU/logger.dart';
import 'package:LegisTracerEU/file_handling.dart';
import 'package:LegisTracerEU/setup.dart' show userEmail;

Future<void> reportProblem() async {
  final info = await PackageInfo.fromPlatform();
  final appVersion = info.version;
  final os = Platform.operatingSystem;
  final osVersion = Platform.operatingSystemVersion;

  // Read last ~2000 chars of log
  final logManager = const LogManager();
  final fullLog = await logManager.readLogs();
  final snippet =
      fullLog.length > 2000
          ? fullLog.substring(fullLog.length - 2000)
          : fullLog;

  final body = Uri.encodeComponent(
    'Hello Support,\n\n'
    'Issue description: [describe the problem]\n'
    'User email used for access: $userEmail\n'
    'App version: $appVersion\n'
    'OS: $os $osVersion\n\n'
    'Recent log tail:\n'
    '----------------\n'
    '$snippet\n\n'
    'Thank you,\n'
    '[your name]',
  );

  final uri = Uri.parse(
    'mailto:juraj.kuban.sk@gmail.com'
    '?subject=${Uri.encodeComponent('Support request for LegisTracerEU')}'
    '&body=$body',
  );

  if (!await launchUrl(uri)) {
    // Fallback: open web support page in browser
    await launchUrl(
      Uri.parse('https://www.pts-translation.sk/support.html'),
      mode: LaunchMode.externalApplication,
    );
  }
}
