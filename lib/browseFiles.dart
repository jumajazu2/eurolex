import 'dart:ui';

import 'package:eurolex/preparehtml.dart';
import 'package:eurolex/processDOM.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:html/parser.dart' as html_parser;

import 'dart:io';
import 'package:path_provider/path_provider.dart';

import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:eurolex/main.dart';
import 'package:eurolex/logger.dart';
import 'package:path/path.dart' as path;

String pathDirEN =
    r'\\OPENMEDIAVAULT\ExtSSD\EurLexDump\LEG_EN_HTML_20250601_00_00'; // Windows path
String pathDirSK =
    r'\\OPENMEDIAVAULT\ExtSSD\EurLexDump\LEG_SK_HTML_20250601_00_00'; // Windows path
String pathDirCZ =
    r'\\OPENMEDIAVAULT\ExtSSD\EurLexDump\LEG_CS_HTML_20250601_00_00'; // Windows path
String pathDirMTD =
    r'\\OPENMEDIAVAULT\ExtSSD\EurLexDump\LEG_MTD_HTML_20250601_00_00'; // Windows path

final logger = LogManager();

final dirEN = Directory(pathDirEN);
final dirSK = Directory(pathDirSK);
final dirCZ = Directory(pathDirCZ);
final dirMTD = Directory(pathDirMTD);

void listFilesInDirEN() async {
  print('Checking directory: ${dirEN.path}');

  logger.log("******Process started for directory: ${dirEN.path}");

  int pointer = 0;

  if (await dirEN.exists()) {
    try {
      List<FileSystemEntity> files = dirEN.listSync();
      files.sort((a, b) => a.path.compareTo(b.path));

      if (files.isEmpty) {
        print('Directory is accessible but contains no files.');
      } else {
        int startIndex =
            18410; //to restart data processing into OS after a failure
        for (int i = startIndex; i < files.length; i++) {
          dirPointer = i; // Update the global pointer for directory processing
          var file = files[i]; //first level of subfolders
          print(file.path);

          print(
            'PROGRESS: Total folders: ${files.length}, processed folders: $pointer',
          );
          pointer++;
          var currentDir = file.path;
          print('Current directory: $currentDir');

          //create localised directory paths

          var checkEnDir = await checkDir(
            Directory(currentDir),
          ); //return the list of accessible directories for EN

          String enDir = currentDir;

          var skDir = currentDir.replaceFirst(r"_EN_", r"_SK_");
          var czDir = currentDir.replaceFirst(r"_EN_", r"_CS_");

          var checkSkDir = await checkDir(Directory(skDir));
          print(
            "dirpointer $i, checkSkDir.length = ${checkSkDir?.length ?? "null"},  checkSkDir = $checkSkDir",
          ); //return the list of accessible directories for EN

          var checkCzDir = await checkDir(
            Directory(czDir),
          ); //return the list of accessible directories for EN
          print(
            "dirpointer $i, checkCzDir.length = ${checkCzDir?.length ?? "null"}, checkCzDir = $checkCzDir",
          );
          print(
            "dirpointer $i, checkEnDir.length = ${checkEnDir?.length ?? "null"}, checkEnDir = $checkEnDir",
          );
          if ((checkSkDir == null) || (checkCzDir == null))
          //for now, later if at least one file is avaible add it and use some placeholder for the unavailable language
          {
            print(
              "Directory does not exist or is not accessible for SK or CZ, skipping",
            );

            logger.log(
              "$dirPointer, ${currentDir.split(r"\").last}, NotProcessed, Files for SK and/or CZ do not exist",
            );
            continue; //this is why not logging
          }

          if (checkEnDir.length == 1 &&
              checkSkDir.length == 1 &&
              checkCzDir.length == 1) {
            print(
              "dirpointer $i EN, SK and CZ directories -one for each language- are accessible and contain files, no change in paths.",
            );
          } else if (checkEnDir.length == 2 &&
              (checkSkDir.length == 1 || checkCzDir.length == 1)) {
            print(
              "dirpointer $i EN, SK and CZ directories differ - 2 for EN, 1 for SK or CZ, EN $checkEnDir, SK $checkSkDir, CZ $checkCzDir.",
            );
            if (checkSkDir[0].contains(r'\html') &&
                checkEnDir[0].contains(r'\html') == "html") {
              enDir = checkEnDir[0];
              print(
                "dirpointer $i SK contains only html $skDir, EN dir will read the file from html dir: $enDir",
              );
            } else if (checkSkDir[0].contains(r'\html') &&
                checkEnDir[1].contains(r'\html')) {
              enDir = checkEnDir[1];

              print(
                "dirpointer $i SK contains only html $skDir, EN dir will read the file from html dir: $enDir",
              );
            }
          }

          if (checkSkDir[0].contains(r'\xhtml') &&
              checkEnDir[0].contains(r'\xhtml')) {
            enDir = checkEnDir[0];
            print(
              "dirpointer $i SK contains only xhtml $skDir, EN dir will read the file from xhtml dir: $enDir",
            );
          } else if (checkSkDir.isNotEmpty &&
              checkEnDir.length > 1 &&
              checkSkDir[0].contains(r'\xhtml') &&
              checkEnDir[1].contains(r'\xhtml')) {
            enDir = checkEnDir[1];

            print(
              "dirpointer $i SK contains only xhtml $skDir, EN dir will read the file from xhtml dir: $enDir",
            );
          }

          var enFile = await getFile(Directory(enDir));
          var skFile = await getFile(Directory(skDir));
          var czFile = await getFile(Directory(czDir));
          var mtdDir = currentDir.replaceFirst(r"_EN_", r"_MTD_");

          var mtdFile = await getFile(Directory(mtdDir));
          print(
            "dirpointer $i Files before passing to extractParagraphs ${enFile.length}, ${skFile.length}, ${czFile.length}, ${mtdFile.length}",
          );
          var dirID = currentDir.split(r"\").last;
          print('Directory ID: $dirID');

          var paragraphs = extractParagraphs(
            enFile,
            skFile,
            czFile,
            mtdFile,
            dirID,
          );

          print(
            "|*********************************************************************************************",
          );
        }
      }
    } catch (e) {
      print('Error accessing directory: $e');
    }
  } else {
    print('Directory does not exist or is not accessible: ${dirEN.path}');
  }
}

//checks if the Cellar ID directory contains one or two subdirectories html and xhtml
Future checkDir(Directory dir) async {
  List accessibleDirs = [];

  if (await dir.exists()) {
    try {
      List<FileSystemEntity> files2 =
          dir.listSync(); //second level of subfolders -html, xhtml

      print(
        "checking where files are: $files2, number of items: ${files2.length}",
      );

      if (files2.isEmpty) {
        print('Directory is accessible but contains no files.');
        return dir;
      } else {
        for (var file
            in files2) //looping through accessible directories html or xhtml
        {
          print('File path in level 2: $file');

          if (file is Directory) {
            // If the file is a directory, you can call the function recursively

            accessibleDirs.add(file.path);

            print(
              "YYY accessible director ${file.path} in $dir",
            ); //file is html or xhtml
          }

          // You can also call the function to list files in the subdirectory
        }

        print("returning accessible directories: $accessibleDirs");
        return accessibleDirs; // Return the list of accessible directories
      }
    } catch (e) {
      print('Error accessing directory: $e');
    }
  } else {
    print('Directory does not exist or is not accessible: ${dir.path}');
  }
}

Future<String> getFile(dir) async {
  // Function to get file from directory, first must skip one or more subdirectories then read file from the lowest level
  print('getting file from directory: $dir');

  if (await dir.exists()) {
    try {
      List<FileSystemEntity> files2 =
          dir.listSync(); //second level of subfolders -html, xhtml

      print("second level files: $files2, number of items: ${files2.length}");

      if (files2.isEmpty) {
        print('Directory is accessible but contains no files.');
      } else {
        for (var file in files2) {
          print('File path in level 2: $file');

          if (file is File &&
              (file.path.endsWith('.html') || file.path.endsWith('.rdf'))) {
            // If the subfile is a file, read it
            print(file.path);
            String readFile = await file.readAsString();
            // print('Reading file: ${readFile.substring(0, 50)}...');

            if (readFile.isNotEmpty) {
              var fileName = path.basename(file.path);
              print('File name: $fileName');
              readFile = '$fileName@@@$readFile';
              //   print('File: ${readFile.substring(0, 50)}');
              return readFile; // Return the read file content
            } else {
              print('File is empty, skipping...');
              return '';
            }
          }

          if (file is Directory) {
            // If the file is a directory, you can call the function recursively
            List<FileSystemEntity> filesInDir2 = file.listSync();

            print(
              "YYY Files inDir2: $filesInDir2, file $file",
            ); //file is html or xhtml

            for (var subfile in filesInDir2) {
              if (subfile is File &&
                  (subfile.path.endsWith('.html') ||
                      subfile.path.endsWith('.rdf'))) {
                // If the subfile is a file, read it
                print(subfile.path);

                try {
                  String readFile = await subfile.readAsString();
                  //  print('Reading file: ${readFile.substring(0, 50)}...');

                  if (readFile.isNotEmpty) {
                    var fileName = path.basename(subfile.path);
                    print('File name: $fileName');
                    readFile = '$fileName@@@$readFile';
                    //  print('File: ${readFile.substring(0, 50)}...');

                    return readFile; // Return the read file content
                  } else {
                    print('File is empty, skipping...');
                    return '';
                  }
                } catch (e) {
                  print('Error reading file as UTF-8: ${subfile.path} - $e');
                  continue;
                }
              }

              if (subfile is Directory) {
                // Go even deeper...
                List<FileSystemEntity> filesInSubDir = subfile.listSync();

                print('is directory and contains these files: $filesInSubDir');

                print(
                  "Only one low level directory detected, the output will contain only one file",
                );

                for (var fileEntity in filesInSubDir) {
                  if (fileEntity is File) {
                    String readFile = await fileEntity.readAsString();
                    print('Reading file: ${readFile.substring(0, 50)}...');

                    if (readFile.isNotEmpty) {
                      var fileName = path.basename(readFile);
                      print('File name: $fileName');
                      readFile = '$fileName@@@$readFile';
                      //   print('File: ${readFile.substring(0, 50)}...');

                      return readFile;
                    } // Return the read file content
                    if (readFile.isEmpty) {
                      print('File is empty, skipping...');
                      return '';
                    }
                  }
                }
              }

              // You can also call the function to list files in the subdirectory
            }
          }
        }
      }
    } catch (e) {
      print('Error accessing directory: $e');
    }
  } else {
    print('Directory does not exist or is not accessible: ${dir.path}');
  }

  return ''; // Return empty string if no file found
}

class BrowseFilesWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: listFilesInDirEN,
          child: Text('Start Batch Processing'),
        ),
        VerticalDivider(
          color: Colors.grey,
          thickness: 1,
          indent: 20,
          endIndent: 20,
        ),
        FilePickerButton(),
      ],

      // Replace with your actual UI for data processing
    );
  }
}
