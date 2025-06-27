import 'dart:ffi';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'dart:convert';

import 'preparehtml.dart';

class DomProcessor {
  // Function to parse HTML content and extract text
  static String parseHtmlString(String htmlString) {
    var document = html_parser.parse(htmlString);
    return document.body?.text ?? '';
  }

  // Add more DOM processing methods here as needed
}

List<Map<String, dynamic>> extractParagraphs(
  String htmlEN,
  String htmlSK,
  String metadata,
) {
  //check if files names match expect lang

  if (htmlEN.isEmpty || htmlSK.isEmpty) {
    print('One or more input strings are empty.');
    return [];
  }

  String htmlENFileName = htmlEN.split('@@@')[0].trim();
  String htmlSKFileName = htmlSK.split('@@@')[0].trim();
  String metadataFileName = metadata.split('@@@')[0].trim();

  print('EN File Name: $htmlENFileName');
  print('SK File Name: $htmlSKFileName');
  print('Metadata File Name: $metadataFileName');

  String htmlSKFileNameMod =
      htmlSKFileName.substring(0, 8) + htmlSKFileName.split('.')[1].trim();
  String htmlENFileNameMod =
      htmlENFileName.substring(0, 8) + htmlENFileName.split('.')[1].trim();

  if (htmlSKFileNameMod != htmlENFileNameMod) {
    print('File names do not match!');
    return [];
  }

  print(
    "filenames after lang removed, matched>>> $htmlENFileNameMod, $htmlSKFileNameMod",
  );

  var documentEN = html_parser.parse(htmlEN);
  var documentSK = html_parser.parse(htmlSK);
  var paragraphsEN = documentEN.getElementsByTagName('p');
  var paragraphsSK = documentSK.getElementsByTagName('p');
  var date = documentSK.getElementsByClassName('oj-hd-date');
  print('date: $date');
  //check if paragraps in SK and EN are the same length
  if (paragraphsEN.length != paragraphsSK.length) {
    print(
      'Paragraphs in EN and SK do not match in length, files not identical!',
    );
    return [];
  }

  int sequenceID = 0;

  List<Map<String, dynamic>> jsonData = [];

  for (var i = 0; i < paragraphsEN.length && i < paragraphsSK.length; i++) {
    var enText = paragraphsEN[i].text.trim();
    var skText = paragraphsSK[i].text.trim();

    if (enText.isNotEmpty && skText.isNotEmpty) {
      Map<String, dynamic> jsonEntry = {
        "sequence_id": sequenceID++,
        "date": date,
        "en_text": enText,
        "sk_text": skText,
        "language": {"en": "English", "sk": "Slovak"},
        "class":
            paragraphsEN[i].classes.isNotEmpty
                ? paragraphsEN[i].classes.first
                : "unknown",
      };
      jsonData.add(jsonEntry);
    }
  }
  jsonOutput = jsonEncode(jsonData);
  openSearchUpload(jsonData);
  //JSOn ready, now turning in into NDJSON + action part

  return jsonData;
}

void openSearchUpload(json) {
  // Your regular JSON data (similar to the data you uploaded)
  var bilingualData = json;

  // OpenSearch URL (adjust to your OpenSearch server)
  String opensearchUrl = 'http://localhost:9200/opensearch/_bulk';

  // Prepare the NDJSON data
  List<String> bulkData = [];

  for (var sentence in bilingualData) {
    var action = {
      "index": {
        "_index": "opensearch", // Your OpenSearch index name
        // Let OpenSearch generate a unique _id
        // _id is omitted, so OpenSearch generates it automatically
      },
    };

    // Convert the action and data into JSON and add them to the bulk data
    bulkData.add(jsonEncode(action)); // Add the action line
    bulkData.add(jsonEncode(sentence)); // Add the data line
  }

  // Send the NDJSON data to OpenSearch
  sendToOpenSearch(opensearchUrl, bulkData);
}

// Function to send the NDJSON data to OpenSearch
Future<void> sendToOpenSearch(String url, List<String> bulkData) async {
  final response = await http.post(
    Uri.parse(url),
    headers: {"Content-Type": "application/x-ndjson"},
    body: bulkData.join("\n") + "\n", // Join the bulk data with newlines
  );

  if (response.statusCode == 200) {
    print("Data successfully indexed!");
    print(response.body);
  } else {
    print("Error: ${response.statusCode} - ${response.body}");
  }
}








//var outputList = paragraphs.map((p) => p.text.trim()).toList();





 
