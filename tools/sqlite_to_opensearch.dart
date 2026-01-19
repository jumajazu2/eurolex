/// SQLite to OpenSearch Import Script (Dart)
///
/// Install dependencies:
///   dart pub add sqlite3 http
///
/// Usage:
///   dart run tools/sqlite_to_opensearch.dart

import 'dart:convert';
import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
import 'package:http/http.dart' as http;

// ==================== CONFIGURATION ====================
class Config {
  // SQLite database (local file)
  static const String sqliteDbPath =
      'C:\\Users\\Juraj\\scriptus2\\scriptus\\build\\windows\\x64\\runner\\Release\\versei_mengeAdd.db';
  static const String sqliteTable = 'msk_bible_verses';

  // OpenSearch via your proxy server
  static const String proxyUrl =
      'https://search.pts-translation.sk'; // Or http://localhost:3000 for testing
  static const String apiKey = '7239';
  static const String email = 'juraj.kuban.sk@gmail.com';
  static const String targetIndex = 'eu_7239_bibles'; // Change to your index

  // Batch settings
  static const int batchSize = 1000; // Records per bulk request

  // Index mapping for OpenSearch
  static const bool createIndexMapping = true; // Set to false after first run

  // Bible ID to language mapping
  // Maps bible_id values from database to language codes
  static const Map<String, String> bibleLanguageMap = {
    '1': 'en', // English Bible
    '2': 'sk', // Slovak Bible
    '3': 'de', // German Bible
    '4': 'fr', // French Bible
    '5': 'de2', // German Bible (second version)
  };
}

// ==================== METADATA FUNCTION ====================
/// Add custom metadata to each record from SQLite
/// Modify this function to add your custom fields
Map<String, dynamic> addMetadata(Map<String, dynamic> record) {
  return {
    ...record, // Original fields from SQLite
    // Add your custom metadata here:
    'importedAt': DateTime.now().toIso8601String(),
    'source': 'sqlite_import',
    'version': '1.0',
    'paragraphsNotMatched': false, // For compatibility with legal doc queries
    // Compatibility fields for app (empty/default values)
    'celex': 'BIBLE',
    'dir_id': 'bible_${record['bible_id'] ?? '1'}',
    'class': 'Bible',
    'date': DateTime.now().toIso8601String(),
    // Add more fields as needed
  };
}

// ==================== CREATE INDEX WITH MAPPING ====================
Future<void> createIndexWithMapping() async {
  final url = Uri.parse('${Config.proxyUrl}/${Config.targetIndex}');

  final mapping = {
    'mappings': {
      'properties': {
        // Language-specific text fields (compatible with your existing queries)
        'en_text': {
          'type': 'text',
          'analyzer': 'standard',
          'fields': {
            'keyword': {'type': 'keyword'},
          },
        },
        'sk_text': {
          'type': 'text',
          'analyzer': 'standard',
          'fields': {
            'keyword': {'type': 'keyword'},
          },
        },
        'de_text': {
          'type': 'text',
          'analyzer': 'standard',
          'fields': {
            'keyword': {'type': 'keyword'},
          },
        },
        'de2_text': {
          'type': 'text',
          'analyzer': 'standard',
          'fields': {
            'keyword': {'type': 'keyword'},
          },
        },
        'fr_text': {
          'type': 'text',
          'analyzer': 'standard',
          'fields': {
            'keyword': {'type': 'keyword'},
          },
        },
        'cs_text': {
          'type': 'text',
          'analyzer': 'standard',
          'fields': {
            'keyword': {'type': 'keyword'},
          },
        },
        // Metadata fields
        'bible_id': {'type': 'keyword'},
        'book_id': {'type': 'keyword'},
        'book_name': {'type': 'keyword'},
        'book_abbreviation': {'type': 'keyword'},
        'bible_chapter': {'type': 'integer'},
        'verse': {'type': 'integer'},
        'id': {'type': 'keyword'},
        'sequence_id': {'type': 'integer'}, // For context display
        'celex': {'type': 'keyword'}, // Compatibility field
        'dir_id': {'type': 'keyword'}, // Compatibility field
        'class': {'type': 'keyword'}, // Compatibility field
        'date': {'type': 'date'}, // Compatibility field
        'paragraphsNotMatched': {
          'type': 'boolean',
        }, // For compatibility with legal doc queries
        'importedAt': {'type': 'date'},
        'source': {'type': 'keyword'},
        'version': {'type': 'keyword'},
      },
    },
  };

  try {
    final response = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': Config.apiKey,
        'x-email': Config.email,
      },
      body: jsonEncode(mapping),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      print('✅ Index created successfully with proper mapping\n');
    } else if (response.statusCode == 400 &&
        response.body.contains('already exists')) {
      print('ℹ️  Index already exists, skipping creation\n');
    } else {
      print(
        '⚠️  Index creation response: ${response.statusCode} ${response.body}\n',
      );
    }
  } catch (e) {
    print('⚠️  Could not create index (may already exist): $e\n');
  }
}

// ==================== BULK UPLOAD ====================
Future<void> sendBulkToOpenSearch(List<Map<String, dynamic>> records) async {
  // Build NDJSON bulk request body
  final bulkLines = <String>[];
  for (final record in records) {
    // Index action (with or without ID)
    final action =
        record.containsKey('id')
            ? {
              'index': {'_index': Config.targetIndex, '_id': record['id']},
            }
            : {
              'index': {'_index': Config.targetIndex},
            };

    bulkLines.add(jsonEncode(action));
    bulkLines.add(jsonEncode(record));
  }
  final bulkBody = bulkLines.join('\n') + '\n';

  // Send to your proxy server's bulk endpoint
  final url = Uri.parse('${Config.proxyUrl}/opensearch/_bulk');
  final response = await http.post(
    url,
    headers: {
      'Content-Type': 'application/x-ndjson',
      'x-api-key': Config.apiKey,
      'x-email': Config.email,
    },
    body: bulkBody,
  );

  if (response.statusCode != 200) {
    throw Exception(
      'Bulk upload failed: ${response.statusCode} ${response.body}',
    );
  }

  // Check for errors in response
  final result = jsonDecode(response.body);
  if (result['errors'] == true) {
    final items = result['items'] as List;
    final errorCount =
        items.where((item) => item['index']['error'] != null).length;
    if (errorCount > 0) {
      print('⚠️  Warning: $errorCount items had errors');
      // Print first few errors for debugging
      for (var i = 0; i < items.length && i < 3; i++) {
        if (items[i]['index']['error'] != null) {
          print('   Error: ${items[i]['index']['error']}');
        }
      }
    }
  }
}

// ==================== LOAD BOOK DATA ====================
Map<String, Map<String, String>> loadBookData(Database db) {
  final bookMap = <String, Map<String, String>>{};

  try {
    // Query to see what columns are available
    final books = db.select('SELECT * FROM msk_bible_books');

    // Debug: Show column names from first row
    if (books.isNotEmpty) {
      print('📚 msk_bible_books columns: ${books.first.keys.toList()}');
    }

    for (final book in books) {
      // The book identifier - try different column names
      final bookId =
          book['ID']?.toString() ??
          book['id']?.toString() ??
          book['book_id']?.toString();

      if (bookId != null) {
        bookMap[bookId] = {
          'book_name': book['title']?.toString() ?? '',
          'book_abbreviation': book['abb']?.toString() ?? '',
        };

        // Debug: print first few books
        if (bookMap.length <= 5) {
          print(
            '  Book ID: $bookId -> ${bookMap[bookId]!['book_name']} (${bookMap[bookId]!['book_abbreviation']})',
          );
          // Also show bible_id if it exists (to understand the confusion)
          if (book['bible_id'] != null) {
            print(
              '    (Note: this book also has bible_id=${book['bible_id']})',
            );
          }
        }
      }
    }

    print('Loaded ${bookMap.length} books from msk_bible_books\n');
  } catch (e) {
    print('⚠️  Warning: Could not load book data: $e\n');
  }

  return bookMap;
}

// ==================== MAIN IMPORT FUNCTION ====================
Future<void> importFromSqlite() async {
  print('Starting SQLite to OpenSearch import...\n');
  print('Configuration:');
  print('  SQLite: ${Config.sqliteDbPath} (table: ${Config.sqliteTable})');
  print('  Server: ${Config.proxyUrl}');
  print('  Index: ${Config.targetIndex}');
  print('  Batch size: ${Config.batchSize}\n');

  // Create index with proper mapping if needed
  if (Config.createIndexMapping) {
    await createIndexWithMapping();
  }

  // Open SQLite database
  final db = sqlite3.open(Config.sqliteDbPath, mode: OpenMode.readOnly);

  try {
    // Load book data for joining
    final bookData = loadBookData(db);

    // Get total count
    final countResult = db.select(
      'SELECT COUNT(*) as count FROM ${Config.sqliteTable}',
    );
    final totalCount = countResult.first['count'] as int;
    print('Found $totalCount records to import\n');

    // Get column names
    final columnsResult = db.select('PRAGMA table_info(${Config.sqliteTable})');
    final columnNames =
        columnsResult.map((row) => row['name'] as String).toList();

    // Read and process records in batches
    var batch = <Map<String, dynamic>>[];
    var processedCount = 0;
    var successCount = 0;
    var sequenceId = 0; // Sequential ID for all verses

    // Read verses in proper order (by book_id, chapter, verse)
    final rows = db.select(
      'SELECT * FROM ${Config.sqliteTable} ORDER BY book_id, bible_chapter, verse',
    );

    for (final row in rows) {
      sequenceId++; // Increment for each verse

      // Convert SQLite row to Map
      final record = <String, dynamic>{};
      for (final columnName in columnNames) {
        record[columnName] = row[columnName];
      }

      // Add sequence_id for context display
      record['sequence_id'] = sequenceId;

      // Join book data
      final bookId = record['book_id']?.toString();

      // Debug: Print first verse details
      if (processedCount == 0) {
        print('🔍 DEBUG - First verse:');
        print('   verse book_id: $bookId');
        print('   verse bible_chapter: ${record['bible_chapter']}');
        print('   verse verse: ${record['verse']}');
        final contentStr = record['content']?.toString() ?? '';
        final preview =
            contentStr.length > 50
                ? contentStr.substring(0, 50) + '...'
                : contentStr;
        print('   verse content: $preview');
        print('   Available in bookData: ${bookData.containsKey(bookId)}');
        if (bookData.containsKey(bookId)) {
          print('   Matched book: ${bookData[bookId]!['book_name']}');
        }
        print('');
      }

      if (bookId != null && bookData.containsKey(bookId)) {
        record['book_name'] = bookData[bookId]!['book_name'];
        record['book_abbreviation'] = bookData[bookId]!['book_abbreviation'];
      } else {
        // Debug: Log when no match found
        if (processedCount < 5) {
          print('⚠️  No book match for book_id: $bookId');
        }
      }

      // Transform 'content' to language-specific field based on bible_id
      final bibleId = record['bible_id']?.toString();
      final content = record['content'];

      if (bibleId != null &&
          content != null &&
          Config.bibleLanguageMap.containsKey(bibleId)) {
        final lang = Config.bibleLanguageMap[bibleId];
        record['${lang}_text'] = content;
        // Remove generic 'content' field to keep data clean
        record.remove('content');

        // Track found bible_ids (show summary at end)
        if (processedCount < 10 || processedCount % 1000 == 0) {
          if (processedCount == 0) print('Bible IDs found:');
          print('  Record $processedCount: bible_id=$bibleId → ${lang}_text');
        }
      } else if (content != null) {
        // If bible_id not mapped, put content in en_text as fallback
        record['en_text'] = content;
        record.remove('content');
        if (bibleId != null) {
          print(
            '⚠️  Warning: bible_id "$bibleId" not mapped to language. Add to Config.bibleLanguageMap',
          );
        }
      }

      // Add metadata
      final enrichedRecord = addMetadata(record);
      batch.add(enrichedRecord);

      // Send batch when it reaches batchSize
      if (batch.length >= Config.batchSize) {
        try {
          await sendBulkToOpenSearch(batch);
          successCount += batch.length;
          processedCount += batch.length;

          final progress = (processedCount / totalCount * 100).toStringAsFixed(
            1,
          );
          print(
            'Progress: $processedCount/$totalCount ($progress%) - Success: $successCount',
          );
        } catch (e) {
          print('❌ Batch upload failed: $e');
          processedCount += batch.length;
        }

        batch = [];

        // Small delay to avoid overwhelming the server
        await Future.delayed(Duration(milliseconds: 100));
      }
    }

    // Send remaining records
    if (batch.isNotEmpty) {
      try {
        await sendBulkToOpenSearch(batch);
        successCount += batch.length;
        processedCount += batch.length;

        print(
          'Progress: $processedCount/$totalCount (100%) - Success: $successCount',
        );
      } catch (e) {
        print('❌ Final batch upload failed: $e');
        processedCount += batch.length;
      }
    }

    print('\n✅ Import completed!');
    print(
      'Total: $totalCount, Success: $successCount, Failed: ${totalCount - successCount}',
    );
  } finally {
    db.dispose();
  }
}

// ==================== RUN ====================
void main() async {
  try {
    await importFromSqlite();
  } catch (e, stackTrace) {
    print('❌ Import failed: $e');
    print(stackTrace);
    exit(1);
  }
}
