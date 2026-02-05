import 'package:LegisTracerEU/preparehtml.dart';
import 'package:LegisTracerEU/setup.dart';
import 'package:LegisTracerEU/main.dart';
import 'package:LegisTracerEU/processDOM.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Check if a CELEX document already exists in the OpenSearch index
/// Returns true if exists, false otherwise
Future<bool> celexExistsInIndex(String indexName, String celex) async {
  try {
    // Use existing /:index/_search endpoint (same as getDistinctCelexForIndex)
    final searchUrl = Uri.parse('$server/$indexName/_search');
    final body = jsonEncode({
      'query': {
        'bool': {
          'should': [
            {
              'term': {'celex': celex},
            },
            {
              'term': {'celex.keyword': celex},
            },
          ],
          'minimum_should_match': 1,
        },
      },
      'size': 1,
      '_source': false,
    });

    print('🔍 CHECK-EXISTS URL: $searchUrl');
    print('🔍 Query body: $body');
    print('🔍 Headers: x-api-key=$userPasskey, x-email=$userEmail');

    final resp = await http
        .post(
          searchUrl,
          headers: addDeviceIdHeader({
            'Content-Type': 'application/json',
            'x-api-key': userPasskey,
            'x-email': userEmail,
          }),
          body: body,
        )
        .timeout(const Duration(seconds: 10));

    print('🔍 Response status: ${resp.statusCode}');
    print('🔍 Response body: ${resp.body}');

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      final hits = data['hits']?['total']?['value'] ?? 0;
      final exists = hits > 0;
      print(
        '🔍 CELEX $celex in $indexName: ${exists ? "EXISTS (skipping)" : "NOT FOUND (will upload)"}',
      );
      return exists;
    } else {
      print(
        '⚠️ Error checking CELEX $celex: HTTP ${resp.statusCode} - ${resp.body}',
      );
      return false;
    }
  } catch (e) {
    print('❌ Error checking if CELEX $celex exists: $e');
    return false; // Assume doesn't exist on error
  }
}

Future<bool> deleteOpenSearchIndex(index) async {
  try {
    var indicesBefore = await getListIndicesFull(server, isAdmin);
    print(
      'Remaining indices before delete: ${indicesBefore.map((i) => i[0]).join(', ')}',
    );

    // SECURE: Use server endpoint which validates admin status
    final resp = await http.delete(
      Uri.parse('$server/$index'),
      headers: {'x-api-key': userPasskey, 'x-email': userEmail},
    );

    print('DELETE: ${resp.statusCode}');

    if (resp.statusCode == 200) {
      var indicesAfter = await getListIndicesFull(server, isAdmin);
      print(
        'Remaining indices after delete: ${indicesAfter.map((i) => i[0]).join(', ')}',
      );
      return true;
    } else {
      print('Delete failed ${resp.statusCode}: ${resp.body}');
      return false;
    }
  } catch (e) {
    print('Error deleting index: $e');
    return false;
  }
}
