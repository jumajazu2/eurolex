import 'dart:convert';
import 'package:http/http.dart' as http;

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
LIMIT 10
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
