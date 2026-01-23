import 'package:LegisTracerEU/tmx_parser.dart';
import 'dart:io';

/// Example usage of the TMX parser
void main() async {
  // Example TMX content (you can also read from a file)
  const tmxContent = '''<?xml version="1.0" encoding="UTF-8"?>
<tmx version="1.4">
  <header creationtool="Example" creationtoolversion="1.0" segtype="sentence" 
          o-tmf="unknown" adminlang="en" srclang="en" datatype="unknown"/>
  <body>
    <tu creationdate="20260122T152808Z" creationid="DESKTOP-II0DE2P\\Juraj" 
        changedate="20260122T152808Z" changeid="DESKTOP-II0DE2P\\Juraj">
      <prop type="x-LastUsedBy">DESKTOP-II0DE2P\\Juraj</prop>
      <prop type="x-Origin">Alignment</prop>
      <prop type="x-ConfirmationLevel">Draft</prop>
      <tuv xml:lang="en-GB">
        <seg>CALL FOR EVIDENCE</seg>
      </tuv>
      <tuv xml:lang="sk-SK">
        <seg>VÝZVA NA PREDKLADANIE PODKLADOV</seg>
      </tuv>
    </tu>
    <tu creationdate="20260122T152900Z" creationid="DESKTOP-II0DE2P\\Juraj">
      <tuv xml:lang="en-GB">
        <seg>European Commission</seg>
      </tuv>
      <tuv xml:lang="sk-SK">
        <seg>Európska komisia</seg>
      </tuv>
    </tu>
    <tu creationdate="20260122T153000Z" creationid="DESKTOP-II0DE2P\\Juraj">
      <tuv xml:lang="en-GB">
        <seg>Legal Framework</seg>
      </tuv>
      <tuv xml:lang="sk-SK">
        <seg>Právny rámec</seg>
      </tuv>
      <tuv xml:lang="cz-CZ">
        <seg>Právní rámec</seg>
      </tuv>
    </tu>
  </body>
</tmx>''';

  // Create parser instance
  final parser = TmxParser(logFileName: 'tmx_example.log');

  try {
    print('=== TMX Parser Example ===\n');

    // Parse the TMX content
    print('Parsing TMX content...');
    final parsedData = parser.parseTmxContent(tmxContent, 'example.tmx');

    print('✓ Successfully parsed ${parsedData.length} translation units\n');

    // Get statistics
    final stats = parser.getStatistics(parsedData);
    print('Statistics:');
    print('  Total entries: ${stats['total_entries']}');
    print('  Languages found: ${(stats['languages'] as List).join(', ')}');
    print('  Language pairs:');
    (stats['language_pairs'] as Map).forEach((pair, count) {
      print('    $pair: $count entries');
    });

    // Display parsed entries
    print('\nParsed Translation Units:');
    print('=' * 60);
    for (var i = 0; i < parsedData.length; i++) {
      final entry = parsedData[i];
      print('\nEntry ${i + 1}:');
      print('  Sequence ID: ${entry['sequence_id']}');
      print('  Created: ${entry['creation_date']}');
      print('  Languages: ${(entry['languages'] as List).join(', ')}');

      // Print all language texts
      for (final lang in entry['languages'] as List) {
        print('  $lang: ${entry['${lang}_text']}');
      }
    }

    // Convert to NDJSON format (for OpenSearch upload)
    print('\n\n=== NDJSON Format (for OpenSearch) ===');
    final ndjson = parser.convertToNdjson(parsedData, 'test_index');
    print(
      'Generated ${ndjson.length} lines (${ndjson.length ~/ 2} documents)\n',
    );

    // Show first document as example
    if (ndjson.length >= 2) {
      print('Example document (first entry):');
      print('Action: ${ndjson[0]}');
      print('Data:   ${ndjson[1]}');
    }

    // Optionally save to file
    print('\n\nSaving parsed data to example_output.json...');
    final outputFile = File('example_output.json');
    await outputFile.writeAsString(
      parsedData.map((e) => e.toString()).join('\n\n'),
    );
    print('✓ Saved to ${outputFile.path}');
  } catch (e) {
    print('ERROR: $e');
    rethrow;
  }
}
