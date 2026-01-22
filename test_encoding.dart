import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  // Test 1: Download from your server
  print('=== Test 1: Downloading SK file ===');
  final url = 'https://www.pts-translation.sk/FISMA01301SK.html';
  final response = await http.get(Uri.parse(url));

  print('Status: ${response.statusCode}');
  print('Content-Type header: ${response.headers['content-type']}');

  // Test decoding
  final decoded = utf8.decode(response.bodyBytes, allowMalformed: true);

  // Find a sample with accented characters
  final searchTerm = 'témou';
  final index = decoded.indexOf(searchTerm);
  if (index != -1) {
    print('Found "$searchTerm" at index $index');
    print('Context: ${decoded.substring(index - 20, index + 30)}');
  } else {
    print(
      'Could not find "témou", searching for "t" followed by accented char...',
    );
    final regex = RegExp(r't[^\x00-\x7F]mou');
    final match = regex.firstMatch(decoded);
    if (match != null) {
      print('Found pattern at ${match.start}: "${match.group(0)}"');
      final bytes = utf8.encode(match.group(0)!);
      print('Bytes: ${bytes.map((b) => '0x${b.toRadixString(16)}').join(' ')}');
    }
  }

  // Test 2: JSON encoding
  print('\n=== Test 2: JSON encoding ===');
  final testText = 'témou mandátu Európskej';
  print('Original: $testText');
  final jsonStr = jsonEncode({'text': testText});
  print('JSON encoded: $jsonStr');
  final jsonBytes = utf8.encode(jsonStr);
  print(
    'UTF-8 bytes: ${jsonBytes.map((b) => '0x${b.toRadixString(16)}').join(' ')}',
  );

  // Test 3: Decode back
  final decoded2 = utf8.decode(jsonBytes);
  print('Decoded back: $decoded2');
  final parsed = jsonDecode(decoded2);
  print('Parsed text: ${parsed['text']}');
}
