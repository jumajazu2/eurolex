import 'dart:ui';

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
        int startIndex = 0;
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

          var skDir = currentDir.replaceFirst(r"_EN_", r"_SK_");
          print(skDir);
          var skFile = await getFile(Directory(skDir));

          var czDir = currentDir.replaceFirst(r"_EN_", r"_CS_");
          print(czDir);
          var czFile = await getFile(Directory(czDir));
          var mtdDir = currentDir.replaceFirst(r"_EN_", r"_MTD_");
          print(mtdDir);
          var mtdFile = await getFile(Directory(mtdDir));

          var enFile = await getFile(Directory(currentDir));
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
          /*

          if (file is Directory) {
            // If the file is a directory, you can call the function recursively
            List<FileSystemEntity> filesInDir = file.listSync();

            for (var subfile in filesInDir) {
              if (subfile is Directory) {
                // Go even deeper
                List<FileSystemEntity> filesInSubDir = subfile.listSync();

                print('is directory and contains these files: $filesInSubDir');

                for (var fileEntity in filesInSubDir) {
                  if (fileEntity is File) {
                    String readFile = await fileEntity.readAsString();
                    print('Reading file: ${readFile.substring(0, 50)}...');
                    // Do something with readFile
                  }
                }
              }

              // You can also call the function to list files in the subdirectory
            }
          }


          */
        }
      }
    } catch (e) {
      print('Error accessing directory: $e');
    }
  } else {
    print('Directory does not exist or is not accessible: ${dirEN.path}');
  }
}

Future<String> getFile(dir) async {
  // Function to get file from directory, first must skip one or more subdirectories then read file from the lowest level
  print('getting file from directory: $dir');

  if (await dir.exists()) {
    try {
      List<FileSystemEntity> files2 = dir.listSync();  //second level of subfolders -html, xhtml 
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

            for (var subfile in filesInDir2) {
              if (subfile is File &&
                  (subfile.path.endsWith('.html') ||
                      subfile.path.endsWith('.rdf'))) {
                // If the subfile is a file, read it
                print(subfile.path);
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
              }

              if (subfile is Directory) {
                // Go even deeper
                List<FileSystemEntity> filesInSubDir = subfile.listSync();

                print('is directory and contains these files: $filesInSubDir');

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
                    // Do something with readFile
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
