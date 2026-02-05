import 'package:LegisTracerEU/preparehtml.dart';
import 'package:LegisTracerEU/setup.dart';
import 'package:LegisTracerEU/main.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Check if a CELEX document already exists in the OpenSearch index
/// Returns true if exists, false otherwise
Future<bool> celexExistsInIndex(String indexName, String celex) async {
  try {
    final searchUrl = Uri.parse('https://$server/$indexName/_search');
    final body = jsonEncode({
      'query': {
        'term': {'celex.keyword': celex}
      },
      'size': 1,
      '_source': false,
    });

    final resp = await http.post(
      searchUrl,
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': userPasskey,
        'x-email': jsonSettings['user_email'],
      },
      body: body,
    );

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      final hits = data['hits']?['total']?['value'] ?? 0;
      return hits > 0;
    }
    return false;
  } catch (e) {
    print('Error checking if CELEX $celex exists: $e');
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
      headers: {
        'x-api-key': userPasskey,
        'x-email': jsonSettings['user_email'],
      },
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
