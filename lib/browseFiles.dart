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
    r'\\OPENMEDIAVAULT\ExtSSD\EurLexDump\SmallSample\EN'; // Windows path
String pathDirSK =
    r'\\OPENMEDIAVAULT\ExtSSD\EurLexDump\SmallSample\SK'; // Windows path
String pathDirCZ =
    r'\\OPENMEDIAVAULT\ExtSSD\EurLexDump\SmallSample\CZ'; // Windows path
String pathDirMTD =
    r'\\OPENMEDIAVAULT\ExtSSD\EurLexDump\SmallSample\MTD'; // Windows path

final logger = LogManager();

final dirEN = Directory(pathDirEN);
final dirSK = Directory(pathDirSK);
final dirCZ = Directory(pathDirCZ);
final dirMTD = Directory(pathDirMTD);

void listFilesInDirEN() async {
  print('Checking directory: ${dirEN.path}');

  if (await dirEN.exists()) {
    try {
      List<FileSystemEntity> files = dirEN.listSync();
      if (files.isEmpty) {
        print('Directory is accessible but contains no files.');
      } else {
        for (var file in files) {
          print(file.path);

          var currentDir = file.path;
          print('Current directory: $currentDir');

          //create localised directory paths

          var skDir = currentDir.replaceFirst(r"\EN", r"\SK");
          print(skDir);
          var skFile = await getFile(Directory(skDir));

          var czDir = currentDir.replaceFirst(r"\EN", r"\CZ");
          print(czDir);
          var czFile = await getFile(Directory(czDir));
          var mtdDir = currentDir.replaceFirst(r"\EN", r"\MTD");
          print(mtdDir);
          var mtdFile = await getFile(Directory(mtdDir));

          var enFile = await getFile(Directory(currentDir));

          var paragraphs = extractParagraphs(enFile, skFile, czFile, mtdFile);

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
      List<FileSystemEntity> files2 = dir.listSync();
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
            print('Reading file: ${readFile.substring(0, 50)}...');

            if (readFile.isNotEmpty) {
              var fileName = path.basename(file.path);
              print('File name: $fileName');
              readFile = '$fileName@@@$readFile';
              print('File: ${readFile.substring(0, 50)}');
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
                print('Reading file: ${readFile.substring(0, 50)}...');

                if (readFile.isNotEmpty) {
                  var fileName = path.basename(subfile.path);
                  print('File name: $fileName');
                  readFile = '$fileName@@@$readFile';
                  print('File: ${readFile.substring(0, 50)}...');

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
                      print('File: ${readFile.substring(0, 50)}...');

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
