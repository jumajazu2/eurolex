import 'dart:async';
import 'dart:convert';
import 'dart:io';

class LocalIngestServer {
  final int port;
  HttpServer? _server;

  // Broadcast so multiple listeners can subscribe.
  final StreamController<Map<String, dynamic>> _controller =
      StreamController<Map<String, dynamic>>.broadcast();

  LocalIngestServer({this.port = 6175});

  Stream<Map<String, dynamic>> get stream => _controller.stream;

  Future<void> start() async {
    if (_server != null) return;
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _listen();
    print('Local ingest server listening on http://127.0.0.1:$port');
  }

  void _listen() {
    _server!.listen((HttpRequest req) async {
      if (req.method == 'POST' && req.uri.path == '/ingest') {
        try {
          final body = await utf8.decoder.bind(req).join();
          final Map<String, dynamic> data =
              body.isEmpty ? <String, dynamic>{} : jsonDecode(body);
          _controller.add(data); // notify listeners
          _reply(req, 200, {'status': 'ok'});
        } catch (e) {
          _reply(req, 400, {'error': 'bad request', 'detail': e.toString()});
        }
      } else if (req.method == 'GET' && req.uri.path == '/health') {
        _reply(req, 200, {'status': 'up'});
      } else {
        _reply(req, 404, {'error': 'not found'});
      }
    });
  }

  void _reply(HttpRequest req, int code, Map<String, dynamic> obj) {
    req.response.statusCode = code;
    req.response.headers.set('Content-Type', 'application/json');
    req.response.write(jsonEncode(obj));
    req.response.close();
  }

  Future<void> stop() async {
    final s = _server;
    _server = null;
    if (s != null) {
      await s.close(force: true);
      print('Local ingest server stopped');
    }
    await _controller.close();
  }

  bool get isRunning => _server != null;
}