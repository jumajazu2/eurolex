import 'package:xml/xml.dart';
import 'dart:convert';
import 'package:LegisTracerEU/logger.dart';

/// Parses TMX (Translation Memory eXchange) files and converts them to multilingual maps
class TmxParser {
  final LogManager logger;

  TmxParser({String? logFileName})
    : logger = LogManager(fileName: logFileName ?? 'tmx_parser.log');

  /// Parse TMX file content and return a list of translation units
  /// Each translation unit contains segments in multiple languages
  List<Map<String, dynamic>> parseTmxContent(
    String tmxContent,
    String fileName,
  ) {
    try {
      logger.log('Starting TMX parsing for file: $fileName');

      final document = XmlDocument.parse(tmxContent);

      // Try to find body element (case-insensitive, with or without namespace)
      XmlElement? body;

      // Method 1: Direct search for 'body'
      body = document.findElements('body').firstOrNull;

      // Method 2: Case-insensitive search
      if (body == null) {
        body =
            document.findAllElements('body').firstOrNull ??
            document.findAllElements('Body').firstOrNull ??
            document.findAllElements('BODY').firstOrNull;
      }

      // Method 3: Search within tmx element
      if (body == null) {
        final tmxElement =
            document.findAllElements('tmx').firstOrNull ??
            document.findAllElements('TMX').firstOrNull;
        if (tmxElement != null) {
          body =
              tmxElement.findElements('body').firstOrNull ??
              tmxElement.findAllElements('body').firstOrNull;
        }
      }

      if (body == null) {
        // Log the document structure to help debug
        logger.log('ERROR: No <body> element found in TMX file');
        logger.log(
          'Document structure: ${document.toXmlString(pretty: true).substring(0, 500)}...',
        );
        throw Exception(
          'Invalid TMX file: No <body> element found. The file may not be a valid TMX format.',
        );
      }

      final translationUnits = body.findElements('tu');
      final results = <Map<String, dynamic>>[];
      int sequenceId = 0;

      logger.log('Found ${translationUnits.length} translation units');

      for (final tu in translationUnits) {
        final tuEntry = _parseTranslationUnit(tu, sequenceId, fileName);
        if (tuEntry != null) {
          results.add(tuEntry);
          sequenceId++;
        }
      }

      logger.log('Successfully parsed ${results.length} translation units');
      return results;
    } catch (e) {
      logger.log('ERROR parsing TMX: $e');
      rethrow;
    }
  }

  /// Parse a single translation unit (tu) element
  Map<String, dynamic>? _parseTranslationUnit(
    XmlElement tu,
    int sequenceId,
    String fileName,
  ) {
    try {
      // Get metadata from tu attributes
      final creationDate = tu.getAttribute('creationdate') ?? '';
      final changeDate = tu.getAttribute('changedate') ?? '';
      final creationId = tu.getAttribute('creationid') ?? '';

      // Extract language segments
      final tuvs = tu.findElements('tuv');
      final segments = <String, String>{};

      for (final tuv in tuvs) {
        final langAttr = tuv.getAttribute('xml:lang');
        if (langAttr == null) continue;

        // Normalize language codes (e.g., "en-GB" -> "en", "sk-SK" -> "sk")
        final lang = _normalizeLanguageCode(langAttr);

        final seg = tuv.findElements('seg').firstOrNull;
        if (seg != null) {
          final text = seg.innerText.trim();
          if (text.isNotEmpty) {
            segments[lang] = text;
          }
        }
      }

      // Skip if we don't have at least 2 languages
      if (segments.length < 2) {
        logger.log(
          'Skipping TU with insufficient languages: ${segments.keys.join(", ")}',
        );
        return null;
      }

      // Create the multilingual entry
      final entry = <String, dynamic>{
        'sequence_id': sequenceId,
        'filename': fileName,
        'source': 'TMX',
        'creation_date': creationDate,
        'change_date': changeDate,
        'creator': creationId,
        'paragraphsNotMatched': false,  // Required for search filters
        'namesNotMatched': false,        // Required for search filters
      };

      // Add language segments with standardized keys
      for (final langEntry in segments.entries) {
        entry['${langEntry.key}_text'] = langEntry.value;
      }

      // Add empty fields for common languages to satisfy exists clauses
      // This ensures searches with 3 languages enabled will still find 2-language pairs
      final commonLangs = ['en', 'sk', 'cz', 'de', 'fr', 'es', 'it'];
      for (final lang in commonLangs) {
        if (!segments.containsKey(lang)) {
          entry['${lang}_text'] = '';  // Empty string for missing languages
        }
      }

      // Add a combined languages field for reference
      entry['languages'] = segments.keys.toList();

      return entry;
    } catch (e) {
      logger.log('ERROR parsing translation unit: $e');
      return null;
    }
  }

  /// Normalize language codes to their base form
  /// Examples: "en-GB" -> "en", "sk-SK" -> "sk", "pt-BR" -> "pt"
  String _normalizeLanguageCode(String langCode) {
    final normalized = langCode.toLowerCase().split('-').first.split('_').first;
    return normalized;
  }

  /// Convert parsed TMX data to OpenSearch NDJSON format
  List<String> convertToNdjson(
    List<Map<String, dynamic>> tmxData,
    String indexName,
  ) {
    final bulkData = <String>[];

    for (final entry in tmxData) {
      // Create the index action
      final action = {
        'index': {'_index': indexName},
      };

      bulkData.add(jsonEncode(action));
      bulkData.add(jsonEncode(entry));
    }

    logger.log('Converted ${tmxData.length} entries to NDJSON format');
    return bulkData;
  }

  /// Get summary statistics about the TMX data
  Map<String, dynamic> getStatistics(List<Map<String, dynamic>> tmxData) {
    if (tmxData.isEmpty) {
      return {
        'total_entries': 0,
        'languages': <String>[],
        'language_pairs': <String, int>{},
      };
    }

    final languageSet = <String>{};
    final languagePairCounts = <String, int>{};

    for (final entry in tmxData) {
      final languages = (entry['languages'] as List?)?.cast<String>() ?? [];
      languageSet.addAll(languages);

      // Count language pairs
      if (languages.length == 2) {
        final pair = languages.toList()..sort();
        final pairKey = pair.join('-');
        languagePairCounts[pairKey] = (languagePairCounts[pairKey] ?? 0) + 1;
      }
    }

    return {
      'total_entries': tmxData.length,
      'languages': languageSet.toList()..sort(),
      'language_pairs': languagePairCounts,
    };
  }
}
