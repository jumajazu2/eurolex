import 'package:flutter/material.dart';

import 'package:html/parser.dart' as html_parser;

import 'dart:io';
import 'package:path_provider/path_provider.dart';

import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:eurolex/main.dart';

//purpose: load File 1 containing SK in file name, then load File 2 containing EN in file name

class FilePickerButton extends StatefulWidget {
  @override
  _FilePickerButtonState createState() => _FilePickerButtonState();
}

class _FilePickerButtonState extends State<FilePickerButton> {
  String fileContent = '';

  // Function to open file picker and load the file content
  Future<void> pickAndLoadFile() async {
    // Open file picker dialog
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    print(result);
    if (result != null) {
      // Get the file path
      String filePath = result.files.single.path!;

      // Read the content of the file
      File file = File(filePath);
      if (await file.exists()) {
        String content = await file.readAsString();
        setState(() {
          fileContent = content;
          print(fileContent.substring(0, 100));
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
                  maxHeight: 300, // Limit the maximum height
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      fileContent,
                      style: TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
