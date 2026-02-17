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
  static const String targetIndex =
      'eu_7239_bibles_5langs2'; // Change to your index

  // Batch settings
  static const int batchSize = 1000; // Records per bulk request

  // Index mapping for OpenSearch
  static const bool createIndexMapping = false; // Server handles index creation
}

// ==================== METADATA FUNCTION ====================
/// Add custom metadata to each record from SQLite
/// Modify this function to add your custom fields
Map<String, dynamic> addMetadata(Map<String, dynamic> record) {
  final bibleId = record['bible_id'] as String?;
  final bookName = record['book_name']?.toString() ?? '';
  final chapter = record['bible_chapter']?.toString() ?? '';
  final verse = record['verse']?.toString() ?? '';
  return {
    ...record, // Original fields from SQLite
    // Add your custom metadata here:
    'importedAt': DateTime.now().toIso8601String(),
    'source': 'sqlite_import',
    'version': '1.0',
    'paragraphsNotMatched': false, // For compatibility with legal doc queries
    // Compatibility fields for app (empty/default values)
    'celex': 'BIBLE',
    'dir_id': 'bible_${bibleId ?? '1'}',
    'class': '$bookName $chapter:$verse',
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
        'dm_text': {
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

// ==================== UPLOAD TO OPENSEARCH ====================
Future<void> sendBulkToOpenSearch(List<Map<String, dynamic>> records) async {
  // Use the secure /upload endpoint
  final url = Uri.parse('${Config.proxyUrl}/upload');
  final body = jsonEncode({'index': Config.targetIndex, 'documents': records});

  final response = await http.post(
    url,
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': Config.apiKey,
      'x-email': Config.email,
    },
    body: body,
  );

  if (response.statusCode != 200) {
    throw Exception('Upload failed: ${response.statusCode} ${response.body}');
  }

  // Check for errors in response
  final result = jsonDecode(response.body);
  if (result['errors'] == true) {
    final items = result['items'] as List?;
    if (items != null) {
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

// ==================== LOAD BIBLE LANGUAGE MAP ====================
Map<String, String> loadBibleLanguageMap(Database db) {
  final bibleMap = <String, String>{};

  // Map from abb to language code
  const Map<String, String> abbToLang = {
    'KJV': 'en',
    'ROH': 'sk',
    'LUT': 'de',
    'KJV-FR': 'fr',
    'MNG': 'dm',
  };

  try {
    // Query to see what columns are available
    final bibles = db.select('SELECT * FROM msk_bibles');

    // Debug: Show column names from first row
    if (bibles.isNotEmpty) {
      print('📖 msk_bibles columns: ${bibles.first.keys.toList()}');
    }

    for (final bible in bibles) {
      // The bible identifier - try different column names
      final bibleId =
          bible['ID']?.toString() ??
          bible['bible_id']?.toString() ??
          bible['id']?.toString();
      final abb = bible['abb']?.toString();
      final lang = abb != null ? abbToLang[abb] ?? abb : null;

      if (bibleId != null && lang != null) {
        bibleMap[bibleId] = lang;

        // Debug: print first few bibles
        if (bibleMap.length <= 5) {
          print('  Bible ID: $bibleId (abb: $abb) -> $lang');
        }
      }
    }

    print(
      'Loaded ${bibleMap.length} bible language mappings from msk_bibles\n',
    );
  } catch (e) {
    print('⚠️  Warning: Could not load bible language map: $e\n');
    // Fallback to hardcoded if table doesn't exist
    bibleMap.addAll({'1': 'en', '2': 'sk', '3': 'de', '4': 'fr', '5': 'dm'});
  }

  return bibleMap;
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

    // Load bible language mappings
    final bibleLanguageMap = loadBibleLanguageMap(db);

    // Get total count
    final countResult = db.select(
      'SELECT COUNT(*) as count FROM ${Config.sqliteTable}',
    );
    final totalCount = countResult.first['count'] as int;
    print('Found $totalCount records to import\n');

    // Read all rows and group by (book_id, bible_chapter, verse)
    final rows = db.select(
      'SELECT * FROM ${Config.sqliteTable} ORDER BY book_id, bible_chapter, verse',
    );

    // Grouping key: book_id|bible_chapter|verse
    final Map<String, Map<String, dynamic>> grouped = {};
    final Map<String, Set<String>> groupedLangs = {};
    int sequenceId = 0;

    for (final row in rows) {
      final bookId = row['book_id']?.toString() ?? '';
      final chapter = row['bible_chapter']?.toString() ?? '';
      final verse = row['verse']?.toString() ?? '';
      final bibleId = row['bible_id']?.toString();
      final content = row['content'];

      // Compute canonical book_id based on bible_id offsets
      final bookIdInt = int.tryParse(bookId) ?? 0;
      final bibleIdInt = int.tryParse(bibleId ?? '') ?? 0;
      int offset = 0;
      if (bibleIdInt == 2)
        offset = 69;
      else if (bibleIdInt == 3)
        offset = 135;
      else if (bibleIdInt == 4)
        offset = 201;
      // bible_id 1 and 5 have offset 0
      final canonicalBookId = bookIdInt - offset;
      final canonicalBookIdStr = canonicalBookId.toString();

      final key = '$canonicalBookIdStr|$chapter|$verse';

      // Initialize group if not exists
      if (!grouped.containsKey(key)) {
        sequenceId++;
        grouped[key] = {
          'book_id': canonicalBookIdStr,
          'bible_chapter': int.tryParse(chapter) ?? chapter,
          'verse': int.tryParse(verse) ?? verse,
          'sequence_id': sequenceId,
        };
        groupedLangs[key] = <String>{};
      }

      // Add language-specific text
      if (bibleId != null &&
          content != null &&
          bibleLanguageMap.containsKey(bibleId)) {
        final lang = bibleLanguageMap[bibleId]!;
        grouped[key]!['${lang}_text'] = content;
        groupedLangs[key]!.add(lang);
      } else if (content != null) {
        // Fallback: put in en_text if unknown
        grouped[key]!['en_text'] = content;
        groupedLangs[key]!.add('en');
      }

      // Add/overwrite bible_id for last seen (not critical)
      grouped[key]!['bible_id'] = bibleId;
    }

    // Ensure all groups have all 5 language fields (add empty if missing)
    final allLangs = bibleLanguageMap.values.toSet();
    for (final key in grouped.keys) {
      for (final lang in allLangs) {
        if (!grouped[key]!.containsKey('${lang}_text')) {
          grouped[key]!['${lang}_text'] = '';
        }
      }
    }

    print('All ${grouped.length} verses now have complete language fields');

    // Add book_name and abbreviation, and metadata
    for (final entry in grouped.entries) {
      final rec = entry.value;
      final bookId = rec['book_id']?.toString();
      if (bookId != null && bookData.containsKey(bookId)) {
        rec['book_name'] = bookData[bookId]!['book_name'];
        rec['book_abbreviation'] = bookData[bookId]!['book_abbreviation'];
      }
    }

    // Prepare batches
    var batch = <Map<String, dynamic>>[];
    var processedCount = 0;
    var successCount = 0;
    final groupedList = grouped.values.toList();
    final groupedTotal = groupedList.length;

    for (final rec in groupedList) {
      final enrichedRecord = addMetadata(rec);
      batch.add(enrichedRecord);
      processedCount++;

      if (batch.length >= Config.batchSize) {
        try {
          await sendBulkToOpenSearch(batch);
          successCount += batch.length;
          final progress = (processedCount / groupedTotal * 100)
              .toStringAsFixed(1);
          print(
            'Progress: $processedCount/$groupedTotal ($progress%) - Success: $successCount',
          );
        } catch (e) {
          print('❌ Batch upload failed: $e');
        }
        batch = [];
        await Future.delayed(Duration(milliseconds: 100));
      }
    }

    // Send remaining records
    if (batch.isNotEmpty) {
      try {
        await sendBulkToOpenSearch(batch);
        successCount += batch.length;
        print(
          'Progress: $processedCount/$groupedTotal (100%) - Success: $successCount',
        );
      } catch (e) {
        print('❌ Final batch upload failed: $e');
      }
    }

    print('\n✅ Import completed!');
    print(
      'Total: $groupedTotal, Success: $successCount, Failed: ${groupedTotal - successCount}',
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
