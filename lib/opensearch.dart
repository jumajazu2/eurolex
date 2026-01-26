import 'package:LegisTracerEU/preparehtml.dart';
import 'package:LegisTracerEU/setup.dart';
import 'package:LegisTracerEU/main.dart';
import 'package:http/http.dart' as http;

Future<bool> deleteOpenSearchIndex(index) async {
  try {
    var indicesBefore = await getListIndicesFull(server, isAdmin);
    print(
      'Remaining indices before delete: ${indicesBefore.map((i) => i[0]).join(', ')}',
    );

    // SECURE: Use server endpoint which validates admin status
    final resp = await http.delete(
      Uri.parse('$server/$index'),
      headers: {
        'x-api-key': userPasskey,
        'x-email': jsonSettings['user_email'],
      },
    );

    print('DELETE: ${resp.statusCode}');

    if (resp.statusCode == 200) {
      var indicesAfter = await getListIndicesFull(server, isAdmin);
      print(
        'Remaining indices after delete: ${indicesAfter.map((i) => i[0]).join(', ')}',
      );
      return true;
    } else {
      print('Delete failed ${resp.statusCode}: ${resp.body}');
      return false;
    }
  } catch (e) {
    print('Error deleting index: $e');
    return false;
  }
}
