import 'dart:convert';
import 'package:http/http.dart' as http;

final langMap = {
  'BUL': 'BG', // Bulgarian
  'CES': 'CS', // Czech
  'DAN': 'DA', // Danish
  'DEU': 'DE', // German
  'ELL': 'EL', // Greek
  'ENG': 'EN', // English
  'SPA': 'ES', // Spanish
  'EST': 'ET', // Estonian
  'FIN': 'FI', // Finnish
  'FRA': 'FR', // French
  'HRV': 'HR', // Croatian
  'HUN': 'HU', // Hungarian
  'ITA': 'IT', // Italian
  'LIT': 'LT', // Lithuanian
  'LAV': 'LV', // Latvian
  'MLT': 'MT', // Maltese
  'NLD': 'NL', // Dutch
  'POL': 'PL', // Polish
  'POR': 'PT', // Portuguese
  'RON': 'RO', // Romanian
  'SLK': 'SK', // Slovak
  'SLV': 'SL', // Slovenian
  'SWE': 'SV', // Swedish
};

String convertLangCode(String code) {
  return langMap[code] ?? code;
}

/*
  final lines = <String>[];
  for (final row in bindings) {
    final celex = row['celex']?['value'] as String? ?? '';
    final title = row['title']?['value'] as String? ?? '';
    final langCode = row['langCode']?['value'] as String? ?? '';
    final twoLetter = langMap[langCode] ?? langCode;  // Fallback to original if not mapped
    if (celex.isNotEmpty) {
      lines.add('$celex\t$title\t$twoLetter');
    }
  }
*/

/// Returns lines in the form: "CELEX<TAB>Title"
Future<List<String>> fetchSectorXCelexTitles(
  dynamic sector,
  dynamic year,
) async {
  const endpoint = 'https://publications.europa.eu/webapi/rdf/sparql';

  final sectorStr = sector.toString();
  final yearStr = year.toString();

  // Use a non-const, non-raw string so interpolation works
  final query = '''
PREFIX cdm: <http://publications.europa.eu/ontology/cdm#>

SELECT ?celex ?title
WHERE {
  # Work level
  ?work a cdm:resource_legal ;
        cdm:resource_legal_id_celex ?celex .

  # Sector and year derived from CELEX
  FILTER(STRSTARTS(STR(?celex), "$sectorStr"))
  FILTER(SUBSTR(STR(?celex), 2, 4) = "$yearStr")

  # Expression level (English title)
  ?exp  cdm:expression_belongs_to_work ?work ;
        cdm:expression_uses_language <http://publications.europa.eu/resource/authority/language/ENG> ;
        cdm:expression_title ?title .
}
ORDER BY ?celex
LIMIT 10000
''';

  final resp = await http.post(
    Uri.parse(endpoint),
    headers: {
      'Accept': 'application/sparql-results+json',
      'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
    },
    body: {'query': query},
  );

  if (resp.statusCode != 200) {
    throw Exception('SPARQL HTTP ${resp.statusCode}: ${resp.body}');
  }

  final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
  final bindings = (decoded['results']?['bindings'] as List?) ?? const [];

  final lines = <String>[];
  for (final row in bindings) {
    final celex = row['celex']?['value'] as String? ?? '';
    final title = row['title']?['value'] as String? ?? '';
    if (celex.isNotEmpty) {
      lines.add('$celex\t$title');
    }
  }

  return lines;
}

/// Returns lines with Cellar links"
Future<List<String>> fetchSectorXCellarLinks(
  dynamic sector,
  dynamic year,
) async {
  const endpoint = 'https://publications.europa.eu/webapi/rdf/sparql';

  final sectorStr = sector.toString();
  final yearStr = year.toString();

  // Use a non-const, non-raw string so interpolation works
  final query = '''
PREFIX cdm: <http://publications.europa.eu/ontology/cdm#>

SELECT ?celex ?title
WHERE {
  # Work level
  ?work a cdm:resource_legal ;
        cdm:resource_legal_id_celex ?celex .

  # Sector and year derived from CELEX
  FILTER(STRSTARTS(STR(?celex), "$sectorStr"))
  FILTER(SUBSTR(STR(?celex), 2, 4) = "$yearStr")

  # Expression level (English title)
  ?exp  cdm:expression_belongs_to_work ?work ;
        cdm:expression_uses_language <http://publications.europa.eu/resource/authority/language/ENG> ;
        cdm:expression_title ?title .
}
ORDER BY ?celex
LIMIT 10000
''';

  final resp = await http.post(
    Uri.parse(endpoint),
    headers: {
      'Accept': 'application/sparql-results+json',
      'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
    },
    body: {'query': query},
  );

  if (resp.statusCode != 200) {
    throw Exception('SPARQL HTTP ${resp.statusCode}: ${resp.body}');
  }

  final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
  final bindings = (decoded['results']?['bindings'] as List?) ?? const [];

  final lines = <String>[];
  for (final row in bindings) {
    final celex = row['celex']?['value'] as String? ?? '';
    final title = row['title']?['value'] as String? ?? '';
    if (celex.isNotEmpty) {
      lines.add('$celex\t$title');
    }
  }

  return lines;
}

Future<Map<String, Map<String, String>>> fetchSectorXCellarLinksNumber(
  dynamic sector,
  dynamic year,
) async {
  const endpoint = 'https://publications.europa.eu/webapi/rdf/sparql';
  final sectorStr = sector.toString();
  final yearStr = year.toString();

  final Map<String, Map<String, String>> resultMap = {};
  const int limit = 10000;
  String? lastCelex; // cursor
  bool hasMore = true;
  int page = 0;

  while (hasMore) {
    final cursorFilter =
        lastCelex == null ? '' : 'FILTER(STR(?celex) > "${lastCelex!}")';

    final query = '''
prefix cdm: <http://publications.europa.eu/ontology/cdm#>
prefix purl: <http://purl.org/dc/elements/1.1/>
select distinct ?celex ?langCode ?item
where {
  ?work a cdm:resource_legal ;
        cdm:resource_legal_id_celex ?celex .
  FILTER(STRSTARTS(STR(?celex), "$sectorStr"))
  FILTER(SUBSTR(STR(?celex), 2, 4) = "$yearStr")
  $cursorFilter
  ?expr cdm:expression_belongs_to_work ?work ;
        cdm:expression_uses_language ?lang .
  ?lang purl:identifier ?langCode .
  ?manif cdm:manifestation_manifests_expression ?expr ;
        cdm:manifestation_type ?format .
  ?item cdm:item_belongs_to_manifestation ?manif .
  FILTER(str(?format)="xhtml")
}
ORDER BY ?celex
LIMIT $limit
''';

    try {
      final resp = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Accept': 'application/sparql-results+json',
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        },
        body: {'query': query},
      );
      if (resp.statusCode != 200) {
        throw Exception('SPARQL HTTP ${resp.statusCode}: ${resp.body}');
      }

      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      final bindings = (decoded['results']?['bindings'] as List?) ?? const [];

      if (bindings.isEmpty) {
        hasMore = false;
        break;
      }

      for (final row in bindings) {
        final celex = row['celex']?['value'] as String? ?? '';
        final langCode = row['langCode']?['value'] as String? ?? '';
        final twoLetter = langMap[langCode] ?? langCode;
        final url = row['item']?['value'] as String? ?? '';
        if (celex.isEmpty || url.isEmpty) continue;
        resultMap[celex] ??= {};
        resultMap[celex]![twoLetter] = url;
        lastCelex = celex; // advance cursor continuously
      }

      page++;
      print(
        'Harvest Page $page fetched, lastCelex=$lastCelex, distinct CELEX so far=${resultMap.length}',
      );
      //   print("Harvest, resultMap size: ${resultMap}");

      // If less than limit, final page
      if (bindings.length < limit) {
        hasMore = false;
      }
    } catch (e) {
      print('Harvest Error on page $page: $e');
      break;
    }
  }

  int totalLangVariants = 0;
  for (final m in resultMap.values) {
    totalLangVariants += m.length;
  }
  print(
    'Harvest Done: ${resultMap.length} CELEX, $totalLangVariants language variants.',
  );
  return resultMap;
}
