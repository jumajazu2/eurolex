import 'dart:ui';

import 'package:eurolex/browseFiles.dart';
import 'package:eurolex/processDOM.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:html/parser.dart' as html_parser;

import 'dart:io';
import 'package:path_provider/path_provider.dart';

import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:eurolex/main.dart';
import 'package:path/path.dart' as path;

String fileContentSK = '';
String fileContentEN = '';
String fileContentCZ = '';
String metadata = '';
String fileContent = '';
String fileContent2 = '';
String fileName = '...';
String jsonOutput = '';
var fileSK_DOM;
var fileEN_DOM;
var fileCZ_DOM;
var fileDOM2;
var celexNumbersExtracted = [];
var extractedCelex = ['------'];

//purpose: load File 1 containing SK in file name, then load File 2 containing EN in file name

class FilePickerButton extends StatefulWidget {
  @override
  _FilePickerButtonState createState() => _FilePickerButtonState();
}

class _FilePickerButtonState extends State<FilePickerButton> {
  // Function to open file picker and load the file content
  Future<void> pickAndLoadFile() async {
    // Open file picker dialog
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    print(result);

    if (result != null) {
      // Get the file path
      String filePath = result.files.single.path!;
      fileName = path.basename(filePath);

      // Read the content of the file
      File file = File(filePath);
      if (await file.exists()) {
        String content = await file.readAsString();
        print('File content loaded successfully: $content');
        setState(()
        // Update the state with the file content
        {
          fileContent = content;
          print('File content loaded successfully: $fileContent');

          if (fileName.contains('SK')) {
            // If the file name contains 'SK', save it to a specific location
            fileContentSK = "$fileName + @@@ + $content";
            // Store the content for SK files
          } else if (fileName.contains('EN')) {
            // If the file name contains 'EN', save it to a specific location
            fileContentEN = "$fileName + @@@ + $content";
          } else if (fileName.contains('CZ')) {
            // If the file name contains 'CZ', save it to a specific location
            fileContentCZ = "$fileName + @@@ + $content";
          } else if (fileName.contains('.rdf')) {
            // If the file name contains 'CZ', save it to a specific location
            metadata = content;
          } else {
            print("File does not match SK, EN, CZ or MTD criteria.");
          }

          if (fileContentSK.isNotEmpty && fileContentEN.isNotEmpty) {
            // If both SK and EN files are loaded, parse the HTML content
            fileEN_DOM = html_parser.parse(fileContentEN);
            fileSK_DOM = html_parser.parse(fileContentSK);
            print('Files EN SK parsed successfully.');

            var paragraphsEN = fileEN_DOM.getElementsByTagName('p');
            /*
            for (var index = 0; index < paragraphsEN.length; index++) {
              print(paragraphsEN[index].text);
            }
            var resultPen = paragraphsEN[9].attributes;
            print("resultPen: $resultPen");
*/
            //insert button that starts processing of DOM on press
          } else {
            fileContent = 'No valid SK or EN file content loaded.';
          }
        });
      } else {
        print("File does not exist!");
      }
    } else {
      print("No file selected.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Button to open file picker
          ElevatedButton(onPressed: pickAndLoadFile, child: Text('Pick File')),
          SizedBox(height: 20), // Space between the button and content box
          // Box to display file content
          fileContent.isEmpty
              ? Text('No file loaded.')
              : Container(
                constraints: BoxConstraints(
                  maxHeight: 200,
                  maxWidth: 200, // Limit the maximum height
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        Text(
                          fileName,
                          style: TextStyle(fontFamily: 'monospace'),
                        ),

                        SizedBox(height: 10),

                        ElevatedButton(
                          onPressed: () {
                            var paragraphs = extractParagraphs(
                              fileContentEN,
                              fileContentSK,
                              fileContentCZ,
                              metadata,
                              "dir",
                              indexName, // Directory ID for logging purposes
                            );
                            // print(jsonOutput);
                          },
                          child: Text('Extract Paragraphs'),
                        ),
                      ],
                    ),
                    // Space between file name and content
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class FilePickerButton2 extends StatefulWidget {
  @override
  _FilePickerButtonState2 createState() => _FilePickerButtonState2();
}

class _FilePickerButtonState2 extends State<FilePickerButton2> {
  // Function to open file picker and load the file content
  Future<void> pickAndLoadFile2() async {
    // Open file picker dialog
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    print(result);

    if (result != null) {
      // Get the file path
      String filePath = result.files.single.path!;
      fileName = path.basename(filePath);

      // Read the content of the file
      File file = File(filePath);
      if (await file.exists()) {
        String content = await file.readAsString();

        // Update the state with the file content
        {
          fileContent2 = content;
          print('File content loaded successfully: $fileContent2');

          if (fileContent2.isNotEmpty) {
            setState(() {
              fileDOM2 = html_parser.parse(fileContent2);
              var tdElements = fileDOM2.getElementsByTagName('td');
              for (var td in tdElements) {
                if (td.text.contains('Celex number:')) {
                  var celexNumberTd =
                      td.nextElementSibling; // Get the next TD element
                  var celexNumber = celexNumberTd.text.trim();
                  print('Celex number: $celexNumber');
                  celexNumbersExtracted.add(celexNumber); // Store the number
                }

                print(celexNumbersExtracted);
              }
            });
          } else {
            print('File content is empty.');
          }
          //manual overide of celex number extracted
          celexNumbersExtracted = [
            '32018D0859', //COMMISSION DECISION (EU) 2018/859
            '62021CJ0457', // JUDGMENT OF THE COURT (Second Chamber) Case C‑457/21
            '62017TJ0816', //  JUDGMENT OF THE GENERAL COURT  Cases T‑816/17 and T‑318/18,
          ]; // Example manual override
          print('Manual override of celex numbers: $celexNumbersExtracted');

          //end of manual override
          for (var i in celexNumbersExtracted) {
            print('Processing Celex number: $i');

            var fileEN = await loadHtmtFromCelex(i, 'EN');
            fileEN_DOM = i + '.celex@@@' + fileEN;
            print('Loaded EN HTML for Celex: $i');
            var fileCZ = await loadHtmtFromCelex(i, 'CS');
            fileCZ_DOM = i + '.celex@@@' + fileCZ;
            print('Loaded CS HTML for Celex: $i');

            var fileSK = await loadHtmtFromCelex(i, 'SK');
            fileSK_DOM = i + '.celex@@@' + fileSK;
            print('Loaded SK HTML for Celex: $i');

            metadata = "%%%#$i"; // Placeholder for metadata
            extractParagraphs(
              fileEN_DOM,
              fileSK_DOM,
              fileCZ_DOM,
              metadata,
              i,
              "imported",
            );

            setState(() {
              extractedCelex.add(
                i,
              ); // Add the processed Celex number to the list
              print('Processed Celex number: $i');
            });
          }
          // Process the HTML content as needed
          // For example, you can extract specific elements or text from the HTML
        }
      } else {
        print("File does not exist!");
      }
    } else {
      print("No file selected.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(child: manualCelexList()),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Button to open file picker
                  ElevatedButton(
                    onPressed: pickAndLoadFile2,
                    child: Text('Pick File with References'),
                  ),
                  SizedBox(
                    height: 20,
                  ), // Space between the button and content box
                  // Box to display file content
                  fileContent2.isEmpty
                      ? Text('No file loaded.')
                      : Container(
                        constraints: BoxConstraints(
                          maxHeight: 200,
                          maxWidth: 200, // Limit the maximum height
                        ),
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              children: [
                                Text(
                                  extractedCelex.isEmpty
                                      ? 'No Celex Numbers Processed.' // If the list is empty
                                      : extractedCelex.length == 1
                                      ? 'Processed Celex Number: ${extractedCelex.first}' // If the list has one value
                                      : 'Processed Celex Numbers: ${extractedCelex.join(', ')}', // If the list has multiple values
                                  style: TextStyle(fontFamily: 'monospace'),
                                ),
                                SizedBox(height: 10),
                                ElevatedButton(
                                  onPressed: () {
                                    var paragraphs = extractParagraphs(
                                      fileContentEN,
                                      fileContentSK,
                                      fileContentCZ,
                                      metadata,
                                      "dir",
                                      indexName, // Directory ID for logging purposes
                                    );
                                  },
                                  child: Text('Extract Paragraphs'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class manualCelexList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('This is a placeholder for manual Celex list functionality.'),
      ],
    );
  }
}

Future<String> loadHtmtFromCelex(
  celex,
  lang,
) async //based on Celex, language create a link and download any lang file, //eur-lex.europa.eu/legal-content/SK/TXT/HTML/?uri=CELEX:32017D0502
{
  String url =
      'http://eur-lex.europa.eu/legal-content/$lang/TXT/HTML/?uri=CELEX:$celex';
  print('Loading HTML from URL: $url');

  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      String htmlContent = response.body;
      print('HTML content loaded successfully: celex: $celex, lang: $lang');

      return htmlContent; // Return the HTML content as a string
      // Process the HTML content as needed
    } else {
      print('Failed to load HTML. Status code: ${response.statusCode}');
      return 'Error loading HTML: ${response.statusCode}';
    }
  } catch (e) {
    print('Error loading HTML: $e');
    return 'Error loading HTML: $e';
  }
}

class parseHtml {
  // Function to parse HTML content and extract text
  static String parseHtmlString(String htmlString) {
    // Parse the HTML string
    var document = html_parser.parse(htmlString);
    // Extract text from the parsed document
    return document.body?.text ?? '';
  }
}
