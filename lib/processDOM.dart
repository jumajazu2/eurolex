//import 'dart:ffi';
import 'package:eurolex/main.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'dart:convert';
import 'package:xml/xml.dart' as xml;
import 'package:eurolex/logger.dart';

import 'preparehtml.dart';

var dirPointer = 0; // Pointer for directory processing

class DomProcessor {
  // Function to parse HTML content and extract text
  static String parseHtmlString(String htmlString) {
    var document = html_parser.parse(htmlString);
    return document.body?.text ?? '';
  }

  // Add more DOM processing methods here as needed
}

final logger = LogManager();

List<Map<String, dynamic>> extractParagraphs(
  String htmlEN,
  String htmlSK,
  String htmlCZ,
  String metadata,
  String dirID,
  String indexName, // Directory ID for logging purposes
) {
  //check if files names match expect lang

  if (htmlEN.isEmpty || htmlSK.isEmpty || htmlCZ.isEmpty) {
    print('One or more input strings are empty.');
    logger.log(
      "$dirPointer, $dirID, NotProcessed, One or more input strings are empty",
    );
    return [];
  }

  if (metadata.isNotEmpty) {
    String metadataRDF = metadata;
    // print('Metadata RDF: ${metadataRDF.substring(0, 50)} ...');

    //getmetadata()
  }

  String htmlENFileName = htmlEN.split('@@@')[0].trim();
  String htmlSKFileName = htmlSK.split('@@@')[0].trim();
  String htmlCZFileName = htmlCZ.split('@@@')[0].trim();
  String metadataFileName = metadata.split('@@@')[0].trim();

  bool namesNotMatched = false;
  bool paragraphsNotMatched = false;

  print(
    'EN File Name: $htmlENFileName SK File Name: $htmlSKFileName CZ File Name: $htmlCZFileName Metadata File Name: $metadataFileName',
  );

  /* logger.log(
    "$DateTime()  Process started for files: $htmlENFileName, $htmlSKFileName, $htmlCZFileName",
  );
*/
  String htmlSKFileNameMod =
      htmlSKFileName.substring(0, 8) + htmlSKFileName.split('.')[1].trim();
  String htmlENFileNameMod =
      htmlENFileName.substring(0, 8) + htmlENFileName.split('.')[1].trim();
  String htmlCZFileNameMod =
      htmlCZFileName.substring(0, 8) + htmlCZFileName.split('.')[1].trim();

  String celex = getmetadata(metadata);
  if (celex.contains(".")) {
    celex = celex.split(".").first;
  }
  print('$dirPointer, $dirID, $htmlENFileName, decoded CELEX: $celex');

  if (htmlSKFileNameMod != htmlENFileNameMod ||
      htmlSKFileNameMod != htmlCZFileNameMod ||
      htmlENFileNameMod != htmlCZFileNameMod) {
    print('File names do not match!');

    logger.log(
      "$dirPointer, $dirID, Processed, Celex: $celex, File names do not match-set warning flag namesNotMatched",
    );
    namesNotMatched = true;
  }

  print(
    "filenames after lang removed, matched>>> $htmlENFileNameMod, $htmlSKFileNameMod, $htmlCZFileNameMod",
  );

  var documentEN = html_parser.parse(htmlEN);
  var documentSK = html_parser.parse(htmlSK);
  var documentCZ = html_parser.parse(htmlCZ);
  var paragraphsEN = documentEN.getElementsByTagName('p');
  var paragraphsSK = documentSK.getElementsByTagName('p');
  var paragraphsCZ = documentCZ.getElementsByTagName('p');

  var dateElements = documentEN.getElementsByClassName('oj-hd-date');
  String date =
      dateElements.isNotEmpty
          ? (dateElements.first.nodes.isNotEmpty &&
                  dateElements.first.nodes.first.nodeType == 3
              ? dateElements.first.nodes.first.text?.trim() ?? ''
              : dateElements.first.text.trim())
          : 'unknown';

  print('date: $date');

  //check if paragraps in SK and EN are the same length
  if (paragraphsEN.length != paragraphsSK.length) {
    print(
      'Paragraphs in EN and SK do not match in length, files not identical! $dirPointer, $dirID',
    );

    logger.log(
      "$dirPointer, $dirID, Processed, Celex: $celex, parNotMatched, EN $htmlENFileNameMod ${paragraphsEN.length} SK $htmlSKFileNameMod ${paragraphsSK.length}",
    );

    paragraphsNotMatched = true;
  }

  int sequenceID = 0;

  List<Map<String, dynamic>> jsonData = [];

  for (
    var i = 0;
    i < paragraphsEN.length &&
        i < paragraphsSK.length &&
        i < paragraphsCZ.length;
    i++
  ) {
    var enText = paragraphsEN[i].text.trim();
    var skText = paragraphsSK[i].text.trim();
    var czText = paragraphsCZ[i].text.trim();

    if (enText.isNotEmpty && skText.isNotEmpty && czText.isNotEmpty) {
      Map<String, dynamic> jsonEntry = {
        "sequence_id": sequenceID++,
        "date": date,
        "en_text": enText,
        "sk_text": skText,
        "cz_text": czText,
        "language": {"en": "English", "sk": "Slovak", "cz": "Czech"},
        "celex": celex,
        "dir_id": dirID, // Directory ID for logging purposes
        "filename": htmlENFileName,
        "paragraphsNotMatched": paragraphsNotMatched,
        "namesNotMatched": namesNotMatched,
        "class":
            paragraphsEN[i].classes.isNotEmpty
                ? paragraphsEN[i].classes.first
                : "unknown",
      };
      jsonData.add(jsonEntry);
    }
  }
  jsonOutput = jsonEncode(jsonData);
  openSearchUpload(jsonData, indexName);

  logger.log(
    "$dirPointer, $dirID, Processed, Celex: $celex, status_ok, $htmlENFileName",
  );
  //JSOn ready, now turning in into NDJSON + action part
  print("Extract paragraphs uploaded to Open Search>COMPLETED");
  return jsonData;
}

//https://eur-lex.europa.eu/legal-content/EN-SK/TXT/?uri=CELEX:32022D2391

void openSearchUpload(json, indexName) {
  // Your regular JSON data (similar to the data you uploaded)
  var bilingualData = json;

  // OpenSearch URL (adjust to your OpenSearch server)
  String opensearchUrl = 'https://$osServer/opensearch/_bulk';

  // Prepare the NDJSON data
  List<String> bulkData = [];

  for (var sentence in bilingualData) {
    var action = {
      "index": {
        "_index": indexName, // Your OpenSearch index name
        // Let OpenSearch generate a unique _id
        // _id is omitted, so OpenSearch generates it automatically
      },
    };

    // Convert the action and data into JSON and add them to the bulk data
    bulkData.add(jsonEncode(action)); // Add the action line
    bulkData.add(jsonEncode(sentence)); // Add the data line
  }

  // Send the NDJSON data to OpenSearch

  print("Sending data to OpenSearch at $opensearchUrl");
  print("******************************************************************");
  print(bulkData.sublist(0, bulkData.length < 10 ? bulkData.length : 9));
  print("******************************************************************");

  sendToOpenSearch(opensearchUrl, bulkData);
}

// Function to send the NDJSON data to OpenSearch
Future<String> sendToOpenSearch(String url, List<String> bulkData) async {
  try {
    //return; //temporary disable for testing
    final response = await http.post(
      Uri.parse(url),
      headers: {"Content-Type": "application/x-ndjson", 'x-api-key': '1234'},
      body: bulkData.join("\n") + "\n", // Join the bulk data with newlines
    );

    if (response.statusCode == 200) {
      print("Data successfully processed!");
      print(response.body);
      return response.body; // Return the response body
    } else {
      print("Error: ${response.statusCode} - ${response.body}");
      return response.body;
    }
  } on Exception catch (e) {
    print("Error sending data to OpenSearch: $e");
    return "Error with OpenSearch: $e";
  }
}

String getmetadata(metadataRDF) //get celex and cellar info from RDF metadata
// find rdf:resource="http://publications.europa.eu/resource/celex/  data follows
{
  if (metadataRDF.contains('%%%#')) {
    metadataRDF = metadataRDF.split('%%%#')[1];
    print('Celex Overide for Reference Upload: $metadataRDF');
    return metadataRDF;
  }

  final regex = RegExp(
    r'owl:sameAs rdf:resource="http://publications\.europa\.eu/resource/celex/([^"/]+)',
  );
  final match = regex.firstMatch(metadataRDF);
  if (match != null && match.groupCount >= 1) {
    return match.group(1)!; // This is the CELEX number
  }
  return 'not found';
}

//var outputList = paragraphs.map((p) => p.text.trim()).toList();
