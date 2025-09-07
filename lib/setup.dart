import 'dart:convert';
import 'dart:math';

import 'package:eurolex/main.dart';
import 'package:flutter/material.dart';
import 'package:eurolex/processDOM.dart';
import 'package:eurolex/display.dart';
import 'package:eurolex/preparehtml.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class indicesMaintenance extends StatefulWidget {
  @override
  _indicesMaintenanceState createState() => _indicesMaintenanceState();
}

class _indicesMaintenanceState extends State<indicesMaintenance> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Indices Maintenance')),
      body: Center(
        child: ListView.builder(
          itemCount: indices.length,
          itemBuilder: (BuildContext context, int index) {
            return ListTile(
              title: Text(indices[index]),
              trailing: IconButton(
                icon: Icon(Icons.delete),
                onPressed: () {
                  setState(() {
                    indices.removeAt(index);
                  });
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
