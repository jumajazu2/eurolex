/*

Usage:

Import in your widgets: import 'package:LegisTracerEU/ui_notices.dart';
Show success: showSuccess(context, 'Saved changes');
Show error: showError(context, 'Upload failed');
Show info: showInfo(context, 'Loading…');
Top banner: showBanner(context, message: 'New version available');
Clear: clearSnackbars(context); clearBanners(context);

*/

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

SnackBar _buildSnackBar(
  String message, {
  Color? bg,
  Duration duration = const Duration(seconds: 3),
  SnackBarAction? action,
}) {
  return SnackBar(
    content: Text(message),
    duration: duration,
    backgroundColor: bg,
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.all(12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    action: action,
  );
}

void showSuccess(BuildContext context, String message, {Duration? duration}) {
  ScaffoldMessenger.of(context).showSnackBar(
    _buildSnackBar(
      message,
      bg: Colors.green.shade600,
      duration: duration ?? const Duration(seconds: 2),
    ),
  );
}

void showError(BuildContext context, String message, {Duration? duration}) {
  ScaffoldMessenger.of(context).showSnackBar(
    _buildSnackBar(
      message,
      bg: Colors.red.shade700,
      duration: duration ?? const Duration(seconds: 4),
      action: SnackBarAction(
        textColor: Colors.white,
        label: 'Dismiss',
        onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
      ),
    ),
  );
}

void showInfo(BuildContext context, String message, {Duration? duration}) {
  ScaffoldMessenger.of(context).showSnackBar(
    _buildSnackBar(
      message,
      bg: Colors.blueGrey.shade700,
      duration: duration ?? const Duration(seconds: 3),
    ),
  );
}

void clearSnackbars(BuildContext context) {
  ScaffoldMessenger.of(context).clearSnackBars();
}

void showBanner(
  BuildContext context, {
  required String message,
  bool dismisable = true,
  List<Widget>? actions,
  Color? backgroundColor,
}) {
  ScaffoldMessenger.of(context).showMaterialBanner(
    MaterialBanner(
      backgroundColor: backgroundColor ?? Colors.yellow.shade100,

      content: Text(message),
      actions:
          actions ??
          [
            dismisable
                ? TextButton(
                  onPressed:
                      () =>
                          ScaffoldMessenger.of(
                            context,
                          ).hideCurrentMaterialBanner(),
                  child: const Text('Dismiss'),
                )
                : TextButton(
                  onPressed: () {
                    launchUrl(
                      Uri.parse('https://www.pts-translation.sk/#pricing'),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                  child: const Text('Purchase Subscription'),
                ),
          ],
    ),
  );
}

void clearBanners(BuildContext context) {
  ScaffoldMessenger.of(context).clearMaterialBanners();
}
