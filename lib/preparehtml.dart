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
String fileName = '...';
String jsonOutput = '';
var fileSK_DOM;
var fileEN_DOM;

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

        setState(()
        // Update the state with the file content
        {
          fileContent = content;

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
            print("File does not match SK, EN, CZ or MTD criteria.")
            ;
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
                              "dir", // Directory ID for logging purposes
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

class parseHtml {
  // Function to parse HTML content and extract text
  static String parseHtmlString(String htmlString) {
    // Parse the HTML string
    var document = html_parser.parse(htmlString);
    // Extract text from the parsed document
    return document.body?.text ?? '';
  }
}
