import 'dart:convert';
import 'package:http/http.dart' as http;

/// Checks for the latest app version from a remote endpoint.
/// Returns the version string if successful, otherwise null.
Future<String?> fetchLatestAppVersion() async {
  try {
    // Replace with your actual version endpoint
    final url = Uri.parse('https://www.pts-translation.sk/updateInfoUrl.json');
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
