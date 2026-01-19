import 'package:sqlite3/sqlite3.dart';
import 'dart:io';

void main() {
  try {
    final db = sqlite3.open('C:\\Users\\Juraj\\scriptus2\\scriptus\\build\\windows\\x64\\runner\\Release\\versei_mengeAdd.db', mode: OpenMode.readOnly);

    print('Tables in versei_mengeAdd.db:');
    print('=' * 40);

    final tables = db.select(
      'SELECT name FROM sqlite_master WHERE type="table" ORDER BY name',
    );

    if (tables.isEmpty) {
      print('No tables found in database.');
      db.dispose();
      return;
    }

    for (var table in tables) {
      final tableName = table['name'] as String;
      print('\nTable: $tableName');

      // Get row count
      try {
        final countResult = db.select(
          'SELECT COUNT(*) as count FROM `$tableName`',
        );
        final count = countResult.first['count'];
        print('  Rows: $count');
      } catch (e) {
        print('  Rows: Error reading count - $e');
      }

      // Get columns
      try {
        final columns = db.select('PRAGMA table_info(`$tableName`)');
        print('  Columns:');
        for (var col in columns) {
          print('    - ${col['name']} (${col['type']})');
        }
      } catch (e) {
        print('  Columns: Error reading schema - $e');
      }
    }

    db.dispose();
  } catch (e, stackTrace) {
    print('Error: $e');
    print(stackTrace);
    exit(1);
  }
}
