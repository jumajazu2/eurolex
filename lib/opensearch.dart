import 'package:LegisTracerEU/preparehtml.dart';
import 'package:LegisTracerEU/setup.dart';
import 'package:LegisTracerEU/main.dart';
import 'package:LegisTracerEU/processDOM.dart';
import 'package:LegisTracerEU/https_error_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';

/// Check if a CELEX document already exists in the OpenSearch index
/// Returns true if exists, false otherwise
/// Retries once on timeout to handle transient server delays
Future<bool> celexExistsInIndex(String indexName, String celex) async {
  // Try twice: initial attempt + one retry on timeout
  for (int attempt = 1; attempt <= 2; attempt++) {
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

      if (attempt == 1) {
        print('🔍 CHECK-EXISTS URL: $searchUrl');
        print('🔍 Query body: $body');
        print('🔍 Headers: x-api-key=$userPasskey, x-email=$userEmail');
      } else {
        print('🔄 Retry attempt $attempt for CELEX $celex');
      }

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
          .timeout(const Duration(seconds: 30));

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
    } on TimeoutException catch (e) {
      print(
        '⏱️ Timeout checking CELEX $celex (attempt $attempt/2): Server did not respond within 30 seconds',
      );
      if (attempt == 2) {
        // Final attempt failed
        print(
          '❌ CELEX $celex existence check failed after timeout retry. Assuming does not exist.',
        );
        return false; // Assume doesn't exist after retry timeout
      }
      // Wait 2 seconds before retry
      await Future.delayed(const Duration(seconds: 2));
      continue; // Retry
    } on HandshakeException catch (e, stackTrace) {
      // SSL/TLS certificate error - log detailed information
      await HttpsErrorHandler.logCertificateError(
        e,
        stackTrace,
        'CELEX Existence Check for $celex in $indexName',
      );
      print('🔒 SSL/TLS Error checking CELEX $celex: $e');
      print('   This may indicate certificate verification issues.');
      print('   Check application logs for details.');
      return false; // Assume doesn't exist on SSL error
    } catch (e, stackTrace) {
      print('❌ Error checking if CELEX $celex exists: $e');
      // Log other errors if they might be network-related
      if (HttpsErrorHandler.isCertificateError(e)) {
        await HttpsErrorHandler.logCertificateError(
          e,
          stackTrace,
          'CELEX Existence Check for $celex in $indexName',
        );
      }
      return false; // Assume doesn't exist on error
    }
  }
  // Should never reach here, but return false as fallback
  return false;
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
  } on HandshakeException catch (e, stackTrace) {
    // SSL/TLS certificate error - log detailed information
    await HttpsErrorHandler.logCertificateError(
      e,
      stackTrace,
      'Delete OpenSearch Index: $index',
    );
    print('🔒 SSL/TLS Error deleting index: $e');
    return false;
  } catch (e, stackTrace) {
    print('Error deleting index: $e');
    if (HttpsErrorHandler.isCertificateError(e)) {
      await HttpsErrorHandler.logCertificateError(
        e,
        stackTrace,
        'Delete OpenSearch Index: $index',
      );
    }
    return false;
  }
}
