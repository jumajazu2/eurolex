import 'dart:io';
import 'dart:convert';
import 'package:xmlstream/xmlstream.dart'
    show
        XmlStreamer,
        XmlState,
        XmlEvent,
        XmlStartElementEvent,
        XmlEndElementEvent;
import 'dart:async';
import 'package:xml/xml.dart';
import 'package:http/http.dart' as http;
import 'package:args/args.dart';

/// Command-line tool to parse IATE TBX termbase and upload to OpenSearch
///
/// Usage:
/// dart tools/tbx_to_opensearch.dart --file IATE.tbx --index iate_terminology --server search.pts-translation.sk --email your@email.com --passkey yourkey
///
/// Optional flags:
/// --batch-size 500 (default: 500 concepts per batch)
/// --dry-run (parse without uploading)
/// --verbose (detailed logging)

void main(List<String> args) async {
  final parser =
      ArgParser()
        ..addOption(
          'file',
          abbr: 'f',
          help: 'Path to TBX file',
          mandatory: true,
        )
        ..addOption(
          'index',
          abbr: 'i',
          help: 'OpenSearch index name',
          mandatory: true,
        )
        ..addOption(
          'server',
          abbr: 's',
          help: 'OpenSearch server',
          mandatory: true,
        )
        ..addOption('email', abbr: 'e', help: 'User email', mandatory: true)
        ..addOption('passkey', abbr: 'p', help: 'Access key', mandatory: true)
        ..addOption(
          'batch-size',
          abbr: 'b',
          help: 'Batch size',
          defaultsTo: '500',
        )
        ..addFlag(
          'dry-run',
          abbr: 'd',
          help: 'Parse without uploading',
          negatable: false,
        )
        ..addFlag(
          'verbose',
          abbr: 'v',
          help: 'Verbose logging',
          negatable: false,
        )
        ..addFlag('help', abbr: 'h', help: 'Show usage', negatable: false);

  try {
    final results = parser.parse(args);

    if (results['help'] as bool) {
      print('IATE TBX to OpenSearch uploader');
      print('');
      print(parser.usage);
      exit(0);
    }

    final config = UploadConfig(
      filePath: results['file'] as String,
      indexName: 'iate_${results['passkey']}_${results['index']}',
      server: results['server'] as String,
      email: results['email'] as String,
      passkey: results['passkey'] as String,
      batchSize: int.parse(results['batch-size'] as String),
      dryRun: results['dry-run'] as bool,
      verbose: results['verbose'] as bool,
    );

    await TbxUploader(config).run();
  } catch (e) {
    print('Error: $e');
    print('');
    print(parser.usage);
    exit(1);
  }
}

class UploadConfig {
  final String filePath;
  final String indexName;
  final String server;
  final String email;
  final String passkey;
  final int batchSize;
  final bool dryRun;
  final bool verbose;

  UploadConfig({
    required this.filePath,
    required this.indexName,
    required this.server,
    required this.email,
    required this.passkey,
    required this.batchSize,
    required this.dryRun,
    required this.verbose,
  });
}

class TbxUploader {
  final UploadConfig config;
  int _processedCount = 0;
  int _uploadedCount = 0;
  int _errorCount = 0;
  final List<Map<String, dynamic>> _batch = [];

  TbxUploader(this.config);

  Future<void> run() async {
    print('Starting TBX upload...');
    print('File: ${config.filePath}');
    print('Index: ${config.indexName}');
    print('Server: ${config.server}');
    print('Batch size: ${config.batchSize}');
    if (config.dryRun) print('DRY RUN MODE - no uploads will be performed');
    print('');

    final file = File(config.filePath);
    if (!await file.exists()) {
      throw Exception('File not found: ${config.filePath}');
    }

    final fileSize = await file.length();
    print(
      'File size: ${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB',
    );
    print('');

    // Index/template creation disabled: assumes index already exists
    // if (!config.dryRun) {
    //   await _createIndexTemplate();
    // }

    final startTime = DateTime.now();

    // Stream parse the XML file
    await _streamParseTbx(file);

    // Upload remaining batch
    if (_batch.isNotEmpty) {
      await _uploadBatch();
    }

    final duration = DateTime.now().difference(startTime);
    print('');
    print('Upload complete!');
    print('Processed: $_processedCount concepts');
    print('Uploaded: $_uploadedCount concepts');
    print('Errors: $_errorCount');
    print('Duration: ${duration.inMinutes}m ${duration.inSeconds % 60}s');
  }

  Future<void> _streamParseTbx(File file) async {
    // True streaming, low-memory parser for <conceptEntry>
    final inputStream = file.openRead().transform(utf8.decoder);
    final conceptBuffer = StringBuffer();
    bool inConceptEntry = false;
    int conceptDepth = 0;
    await for (final chunk in inputStream) {
      // Process chunk char by char for robust tag detection
      int i = 0;
      while (i < chunk.length) {
        if (!inConceptEntry) {
          // Look for <conceptEntry
          final startIdx = chunk.indexOf('<conceptEntry', i);
          if (startIdx == -1) break;
          // Find the end of the start tag
          final tagEnd = chunk.indexOf('>', startIdx);
          if (tagEnd == -1) break; // Wait for next chunk
          inConceptEntry = true;
          conceptDepth = 1;
          conceptBuffer.clear();
          conceptBuffer.write(chunk.substring(startIdx, tagEnd + 1));
          i = tagEnd + 1;
        } else {
          // Buffer until we close the conceptEntry
          final closeIdx = chunk.indexOf('</conceptEntry>', i);
          if (closeIdx == -1) {
            // No close tag in this chunk, buffer all
            conceptBuffer.write(chunk.substring(i));
            break;
          } else {
            // Found close tag, buffer up to and including it
            conceptBuffer.write(chunk.substring(i, closeIdx + 15));
            final conceptXml = conceptBuffer.toString();
            inConceptEntry = false;
            i = closeIdx + 15;
            try {
              final doc = await _parseConceptEntry(conceptXml);
              if (doc != null) {
                _batch.add(doc);
                _processedCount++;
                if (_batch.length >= config.batchSize) {
                  await _uploadBatch();
                }
                if (_processedCount % 1000 == 0) {
                  print('Processed: $_processedCount concepts...');
                }
              }
            } catch (e) {
              _errorCount++;
              if (config.verbose) {
                print('Error parsing concept: $e');
              }
            }
          }
        }
      }
    }
  }

  Future<Map<String, dynamic>?> _parseConceptEntry(String xml) async {
    // Use DOM parser for each conceptEntry
    final document = XmlDocument.parse(xml);
    final conceptEntry = document.rootElement;
    // concept_id
    final conceptId = conceptEntry.getAttribute('id');
    // subjectField
    String? subjectField;
    final subjectDescripCandidates = conceptEntry
        .findAllElements('descrip')
        .where((e) => e.getAttribute('type') == 'subjectField');
    final subjectDescrip =
        subjectDescripCandidates.isNotEmpty
            ? subjectDescripCandidates.first
            : null;
    if (subjectDescrip != null) {
      subjectField = subjectDescrip.text.trim();
    }
    // languages, terms, term_types, reliability_codes
    final Map<String, List<String>> termsByLang = {};
    final Map<String, List<String>> termTypesByLang = {};
    final Map<String, List<int>> reliabilityByLang = {};
    final Set<String> languages = {};
    for (final langSec in conceptEntry.findAllElements('langSec')) {
      final lang =
          langSec.getAttribute('xml:lang') ?? langSec.getAttribute('lang');
      if (lang == null) continue;
      final normLang = _normalizeLanguageCode(lang);
      languages.add(normLang);
      termsByLang[normLang] = [];
      termTypesByLang[normLang] = [];
      reliabilityByLang[normLang] = [];
      for (final termSec in langSec.findAllElements('termSec')) {
        // term
        final termElemCandidates = termSec.findElements('term');
        final termElem =
            termElemCandidates.isNotEmpty ? termElemCandidates.first : null;
        if (termElem != null) {
          final term = termElem.text.trim();
          if (term.isNotEmpty) termsByLang[normLang]!.add(term);
        }
        // termType
        final termTypeElemCandidates = termSec
            .findAllElements('termNote')
            .where((e) => e.getAttribute('type') == 'termType');
        final termTypeElem =
            termTypeElemCandidates.isNotEmpty
                ? termTypeElemCandidates.first
                : null;
        if (termTypeElem != null) {
          final termType = termTypeElem.text.trim();
          if (termType.isNotEmpty) termTypesByLang[normLang]!.add(termType);
        }
        // reliabilityCode
        final relElemCandidates = termSec
            .findAllElements('descrip')
            .where((e) => e.getAttribute('type') == 'reliabilityCode');
        final relElem =
            relElemCandidates.isNotEmpty ? relElemCandidates.first : null;
        if (relElem != null) {
          final rel = int.tryParse(relElem.text.trim());
          if (rel != null) reliabilityByLang[normLang]!.add(rel);
        }
      }
    }
    if (conceptId == null) return null;
    final doc = <String, dynamic>{
      'concept_id': conceptId,
      'filename': config.filePath.split(Platform.pathSeparator).last,
      'languages': languages.toList(),
    };
    if (subjectField != null && subjectField.isNotEmpty) {
      doc['subject_field'] = subjectField;
    }
    for (final entry in termsByLang.entries) {
      if (entry.value.isNotEmpty) {
        doc['${entry.key}_text'] = entry.value.join(', ');
      }
    }
    final allTermTypes =
        termTypesByLang.values.expand((e) => e).toSet().toList();
    if (allTermTypes.isNotEmpty) {
      doc['term_types'] = allTermTypes;
    }
    final allReliability =
        reliabilityByLang.values.expand((e) => e).toSet().toList();
    if (allReliability.isNotEmpty) {
      doc['reliability_codes'] = allReliability;
    }
    return doc;
  }

  String _normalizeLanguageCode(String code) {
    // Convert xml:lang codes to 2-letter ISO codes
    // en-GB -> en, de-DE -> de, etc.
    if (code.isEmpty) return '';
    final parts = code.toLowerCase().split('-');
    return parts.first;
  }

  Future<void> _uploadBatch() async {
    if (_batch.isEmpty) return;
    if (config.dryRun) {
      if (config.verbose) {
        print('DRY RUN: Would upload ${_batch.length} documents');
      }
      _uploadedCount += _batch.length;
      _batch.clear();
      return;
    }

    try {
      // Convert to NDJSON format for bulk API
      final ndjson = StringBuffer();
      for (final doc in _batch) {
        ndjson.writeln(jsonEncode({'index': {}}));
        ndjson.writeln(jsonEncode(doc));
      }

      // Debug: print NDJSON preview and headers
      if (config.verbose || !config.verbose) {
        print('Uploading batch to OpenSearch:');
        print('URL: https://${config.server}/${config.indexName}/_bulk');
        print('Headers:');
        print('  Content-Type: application/x-ndjson');
        print('  Authorization: Basic ...');
        print('  x-api-key: ${config.passkey}');
        print('  x-email: ${config.email}');
        print('NDJSON preview:');
        final lines = ndjson.toString().split('\n');
        for (var i = 0; i < lines.length && i < 6; i++) {
          print('  $i: ${lines[i]}');
        }
        print('---');
      }

      // Upload to OpenSearch
      final url = 'https://${config.server}/${config.indexName}/_bulk';
      final basicAuth = 'Basic ${base64Encode(utf8.encode('admin:admin'))}';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/x-ndjson',
          'Authorization': basicAuth,
          'x-api-key': config.passkey,
          'x-email': config.email,
        },
        body: ndjson.toString(),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _uploadedCount += _batch.length;
        if (config.verbose) {
          print('Uploaded batch of ${_batch.length} documents');
        }
      } else {
        _errorCount += _batch.length;
        print('Upload failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      _errorCount += _batch.length;
      print('Upload error: $e');
    }

    // Always clear batch after upload to avoid memory bloat
    _batch.clear();
  }

  Future<void> _createIndexTemplate() async {
    print('Creating index with mappings...');

    final indexUrl = 'https://${config.server}/${config.indexName}';

    if (config.verbose) {
      print('Index URL: $indexUrl');
      print('Auth: admin:admin');
      print('x-api-key: ${config.passkey}');
      print('x-email: ${config.email}');
    }

    final indexBody = {
      'settings': {
        'number_of_shards': 1,
        'number_of_replicas': 0,
        'analysis': {
          'analyzer': {
            'standard_folding': {
              'type': 'custom',
              'tokenizer': 'standard',
              'filter': ['lowercase', 'asciifolding'],
            },
          },
        },
      },
      'mappings': {
        'properties': {
          'concept_id': {'type': 'keyword'},
          'filename': {'type': 'keyword'},
          'subject_field': {
            'type': 'text',
            'analyzer': 'standard_folding',
            'fields': {
              'keyword': {'type': 'keyword'},
            },
          },
          'languages': {'type': 'keyword'},
          'term_types': {'type': 'keyword'},
          'reliability_codes': {'type': 'integer'},
        },
        'dynamic_templates': [
          {
            'language_text_fields': {
              'match': '*_text',
              'mapping': {'type': 'text', 'analyzer': 'standard_folding'},
            },
          },
        ],
      },
    };

    try {
      final basicAuth = 'Basic ${base64Encode(utf8.encode('admin:admin'))}';

      if (config.verbose) {
        print('Sending POST request...');
        print('Index body: ${jsonEncode(indexBody)}');
      }

      final response = await http.post(
        Uri.parse(indexUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': basicAuth,
          'x-api-key': config.passkey,
          'x-email': config.email,
        },
        body: jsonEncode(indexBody),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('Index created successfully');
      } else {
        print('========================================');
        print('Index creation failed!');
        print('Status Code: ${response.statusCode}');
        print('Status Reason: ${response.reasonPhrase}');
        print('Response Headers:');
        response.headers.forEach((key, value) {
          print('  $key: $value');
        });
        print('Response Body:');
        print(response.body);
        print('========================================');

        // If index already exists, that's okay
        if (response.statusCode == 400 &&
            response.body.contains('resource_already_exists')) {
          print('Index already exists - will use existing index');
        } else {
          print('');
          print(
            'WARNING: Failed to create index. Documents may be rejected if index doesn\'t exist.',
          );
        }
      }
    } catch (e, stackTrace) {
      print('========================================');
      print('Exception during index creation:');
      print('Error: $e');
      print('Stack trace:');
      print(stackTrace);
      print('========================================');
      print('');
      print(
        'WARNING: Failed to create index. Documents may be rejected if index doesn\'t exist.',
      );
    }
    print('');
  }
}
