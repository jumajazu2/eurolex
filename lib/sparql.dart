import 'dart:convert';
import 'testHtmlDumps.dart';
import 'package:http/http.dart' as http;
import 'package:LegisTracerEU/logger.dart';
import 'package:LegisTracerEU/main.dart' show deviceId;

Map<String, String> addDeviceIdHeader([Map<String, String>? headers]) {
  final h = <String, String>{};
  if (headers != null) h.addAll(headers);
  if (deviceId != null && deviceId!.isNotEmpty) h['x-device-id'] = deviceId!;
  return h;
}

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
  'GLE': 'GA', // Ukrainian
};

// Centralized lightweight logger for SPARQL calls.
void _sparqlLog(String msg) {
  try {
    LogManager(fileName: 'sparql.log').log(msg);
  } catch (_) {}
}

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

  try {
    http.Response resp;
    String method = 'POST';
    try {
      resp = await http
          .post(
            Uri.parse(endpoint),
            headers: addDeviceIdHeader({
              'Accept': 'application/sparql-results+json',
              'Content-Type':
                  'application/x-www-form-urlencoded; charset=UTF-8',
            }),
            body: {'query': query},
          )
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      // Fallback to GET if POST is blocked
      final getUri = Uri.parse(
        endpoint,
      ).replace(queryParameters: {'query': query});
      method = 'GET';
      resp = await http
          .get(
            getUri,
            headers: addDeviceIdHeader({
              'Accept': 'application/sparql-results+json',
            }),
          )
          .timeout(const Duration(seconds: 12));
    }

    _sparqlLog(
      'titles sector=$sector year=$year method=$method status=' +
          resp.statusCode.toString() +
          ' len=' +
          resp.body.length.toString(),
    );

    if (resp.statusCode != 200) {
      print(
        'SPARQL titles HTTP ${resp.statusCode}: ${resp.body.substring(0, resp.body.length > 300 ? 300 : resp.body.length)}',
      );
      _sparqlLog(
        'titles error sector=$sector year=$year status=' +
            resp.statusCode.toString() +
            ' body=' +
            resp.body.substring(
              0,
              resp.body.length > 300 ? 300 : resp.body.length,
            ),
      );
      return const [];
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
  } catch (e) {
    print('SPARQL titles fetch error (sector=$sector, year=$year): $e');
    _sparqlLog(
      'titles exception sector=$sector year=$year err=' + e.toString(),
    );
    return const [];
  }
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

  try {
    http.Response resp;
    String method = 'POST';
    try {
      resp = await http
          .post(
            Uri.parse(endpoint),
            headers: addDeviceIdHeader({
              'Accept': 'application/sparql-results+json',
              'Content-Type':
                  'application/x-www-form-urlencoded; charset=UTF-8',
            }),
            body: {'query': query},
          )
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      // Fallback to GET if POST is blocked
      final getUri = Uri.parse(
        endpoint,
      ).replace(queryParameters: {'query': query});
      method = 'GET';
      resp = await http
          .get(
            getUri,
            headers: addDeviceIdHeader({
              'Accept': 'application/sparql-results+json',
            }),
          )
          .timeout(const Duration(seconds: 12));
    }

    _sparqlLog(
      'links sector=$sector year=$year method=$method status=' +
          resp.statusCode.toString() +
          ' len=' +
          resp.body.length.toString(),
    );

    if (resp.statusCode != 200) {
      print(
        'SPARQL links HTTP ${resp.statusCode}: ${resp.body.substring(0, resp.body.length > 300 ? 300 : resp.body.length)}',
      );
      _sparqlLog(
        'links error sector=$sector year=$year status=' +
            resp.statusCode.toString() +
            ' body=' +
            resp.body.substring(
              0,
              resp.body.length > 300 ? 300 : resp.body.length,
            ),
      );
      return const [];
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
  } catch (e) {
    print('SPARQL links fetch error (sector=$sector, year=$year): $e');
    _sparqlLog('links exception sector=$sector year=$year err=' + e.toString());
    return const [];
  }
}

Future<Map<String, String>> fetchTitlesForCelex(dynamic celex) async {
  const endpoint = 'https://publications.europa.eu/webapi/rdf/sparql';
  final celexStr = celex.toString();
  final Map<String, String> titleMap = {};

  final query = '''
prefix cdm: <http://publications.europa.eu/ontology/cdm#>
prefix purl: <http://purl.org/dc/elements/1.1/>
prefix xsd: <http://www.w3.org/2001/XMLSchema#>

select distinct ?langCode ?title
where {
  # Optimization: Bind CELEX immediately
  VALUES ?celex { "$celexStr"^^xsd:string }

  ?work cdm:resource_legal_id_celex ?celex .

  ?expr cdm:expression_belongs_to_work ?work ;
        cdm:expression_uses_language ?lang ;
        cdm:expression_title ?title .

  ?lang purl:identifier ?langCode .
}
''';

  try {
    // Prefer POST; some environments may block it, so fallback to GET
    http.Response resp;
    String method = 'POST';
    try {
      resp = await http
          .post(
            Uri.parse(endpoint),
            headers: {
              'Accept': 'application/sparql-results+json',
              'Content-Type':
                  'application/x-www-form-urlencoded; charset=UTF-8',
            },
            body: {'query': query},
          )
          .timeout(const Duration(seconds: 12));
    } catch (e) {
      // POST failed (e.g., blocked). Try GET with URL-encoded query
      final getUri = Uri.parse(
        endpoint,
      ).replace(queryParameters: {'query': query});
      method = 'GET';
      resp = await http
          .get(getUri, headers: {'Accept': 'application/sparql-results+json'})
          .timeout(const Duration(seconds: 12));
    }

    _sparqlLog(
      'titles-celex celex=' +
          celexStr +
          ' method=' +
          method +
          ' status=' +
          resp.statusCode.toString() +
          ' len=' +
          resp.body.length.toString(),
    );

    if (resp.statusCode != 200) {
      _sparqlLog(
        'titles-celex error celex=' +
            celexStr +
            ' status=' +
            resp.statusCode.toString() +
            ' body=' +
            resp.body.substring(
              0,
              resp.body.length > 300 ? 300 : resp.body.length,
            ),
      );
      throw Exception('SPARQL HTTP ${resp.statusCode}: ${resp.body}');
    }

    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    final bindings = (decoded['results']?['bindings'] as List?) ?? const [];

    for (final row in bindings) {
      final langCode = row['langCode']?['value'] as String? ?? '';
      final title = row['title']?['value'] as String? ?? '';

      if (langCode.isNotEmpty && title.isNotEmpty) {
        final twoLetter = langMap[langCode] ?? langCode;
        titleMap[twoLetter] = title;
      }
    }
  } catch (e) {
    print('Error fetching titles for CELEX $celexStr: $e');
    _sparqlLog(
      'titles-celex exception celex=' + celexStr + ' err=' + e.toString(),
    );
  }
  print('Fetched titles for CELEX $celexStr: $titleMap');
  return titleMap;
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
      // Try POST first, then fallback to GET if needed
      http.Response resp;
      String method = 'POST';
      try {
        resp = await http
            .post(
              Uri.parse(endpoint),
              headers: addDeviceIdHeader({
                'Accept': 'application/sparql-results+json',
                'Content-Type':
                    'application/x-www-form-urlencoded; charset=UTF-8',
              }),
              body: {'query': query},
            )
            .timeout(const Duration(seconds: 15));
      } catch (_) {
        final getUri = Uri.parse(
          endpoint,
        ).replace(queryParameters: {'query': query});
        method = 'GET';
        resp = await http
            .get(
              getUri,
              headers: addDeviceIdHeader({
                'Accept': 'application/sparql-results+json',
              }),
            )
            .timeout(const Duration(seconds: 15));
      }
      _sparqlLog(
        'linksNumber sector=' +
            sectorStr +
            ' year=' +
            yearStr +
            ' page=' +
            page.toString() +
            ' method=' +
            method +
            ' status=' +
            resp.statusCode.toString() +
            ' len=' +
            resp.body.length.toString(),
      );
      if (resp.statusCode != 200) {
        _sparqlLog(
          'linksNumber error sector=' +
              sectorStr +
              ' year=' +
              yearStr +
              ' page=' +
              page.toString() +
              ' status=' +
              resp.statusCode.toString() +
              ' body=' +
              resp.body.substring(
                0,
                resp.body.length > 300 ? 300 : resp.body.length,
              ),
        );
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
        // resultMap[celex]![twoLetter] = url;
        resultMap[celex]!.putIfAbsent(
          twoLetter,
          () => url,
        ); //to ensure that only the first url is used when there are more URLs for a lang,
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
      _sparqlLog(
        'linksNumber exception page=' +
            page.toString() +
            ' err=' +
            e.toString(),
      );
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

Future<Map<String, Map<String, String>>> fetchLinksForCelex(
  dynamic celex,
  String format,
) async {
  const endpoint = 'https://publications.europa.eu/webapi/rdf/sparql';
  final celexStr = celex;

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
VALUES ?celex { "$celexStr"^^xsd:string }

  ?work cdm:resource_legal_id_celex ?celex .

  ?expr cdm:expression_belongs_to_work ?work ;
        cdm:expression_uses_language ?lang .
  ?lang purl:identifier ?langCode .
  ?manif cdm:manifestation_manifests_expression ?expr ;
        cdm:manifestation_type ?format .
  ?item cdm:item_belongs_to_manifestation ?manif .
  FILTER(str(?format)="$format")
}
ORDER BY ?celex
''';

    try {
      // Try POST with fallback to GET
      http.Response resp;
      String method = 'POST';
      try {
        resp = await http
            .post(
              Uri.parse(endpoint),
              headers: addDeviceIdHeader({
                'Accept': 'application/sparql-results+json',
                'Content-Type':
                    'application/x-www-form-urlencoded; charset=UTF-8',
              }),
              body: {'query': query},
            )
            .timeout(const Duration(seconds: 15));
      } catch (_) {
        final getUri = Uri.parse(
          endpoint,
        ).replace(queryParameters: {'query': query});
        method = 'GET';
        resp = await http
            .get(
              getUri,
              headers: addDeviceIdHeader({
                'Accept': 'application/sparql-results+json',
              }),
            )
            .timeout(const Duration(seconds: 15));
      }
      _sparqlLog(
        'links-celex celex=' +
            celexStr +
            ' format=' +
            format +
            ' page=' +
            page.toString() +
            ' method=' +
            method +
            ' status=' +
            resp.statusCode.toString() +
            ' len=' +
            resp.body.length.toString(),
      );
      if (resp.statusCode != 200) {
        _sparqlLog(
          'links-celex error celex=' +
              celexStr +
              ' format=' +
              format +
              ' page=' +
              page.toString() +
              ' status=' +
              resp.statusCode.toString() +
              ' body=' +
              resp.body.substring(
                0,
                resp.body.length > 300 ? 300 : resp.body.length,
              ),
        );
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
        // resultMap[celex]![twoLetter] = url;
        resultMap[celex]!.putIfAbsent(
          twoLetter,
          () => url,
        ); //to ensure that only the first url is used when there are more URLs for a lang,
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
      _sparqlLog(
        'links-celex exception page=' +
            page.toString() +
            ' err=' +
            e.toString(),
      );
      break;
    }
  }
  int totalLangVariants = 0;
  for (final m in resultMap.values) {
    totalLangVariants += m.length;
  }
  print(
    'Harvest Done for individual CELEX $celexStr: ${resultMap.length}, $totalLangVariants language variants, resultMap: $resultMap.',
  );

  return resultMap;
}
