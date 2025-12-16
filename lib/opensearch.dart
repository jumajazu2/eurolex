import 'package:LegisTracerEU/preparehtml.dart';
import 'package:LegisTracerEU/setup.dart';
import 'package:http/http.dart' as http;

Future deleteOpenSearchIndex(index) async {
  String indicesBefore = await getListIndices(server);
  print('Remaining indices before delete: $indicesBefore');
  final resp = await http.delete(
    Uri.parse('https://search.pts-translation.sk/$index'),
    headers: {'x-api-key': userPasskey},
  );

  print('DELETE: ${resp.statusCode}');
  if (resp.statusCode != 200) {
    throw Exception('Delete failed ${resp.statusCode}: ${resp.body}');
  }
  String indicesAfter = await getListIndices(server);
  print('Remaining indices after delete: $indicesAfter');
}
