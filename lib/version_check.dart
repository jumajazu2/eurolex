import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:LegisTracerEU/preparehtml.dart';

/// Checks for the latest app version from server endpoint.
/// Returns the version string if successful, otherwise null.
Future<String?> fetchLatestAppVersion() async {
  try {
    // Use secure server endpoint instead of direct website call
    final url = Uri.parse('$server/version');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['version'] as String?;
    }
  } catch (e) {
    print('Failed to fetch latest version: $e');
  }
  return null;
}
