import 'dart:async';
import 'dart:convert';
import 'dart:io';
// UI notifications should be provided via callbacks; avoid direct UI imports here.

// 1. Define the handler type (Function signature)
typedef RequestHandler =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> payload);

class LocalIngestServer {
  final int port;
  HttpServer? _server;

  // 2. Add the callback property here
  RequestHandler? onRequest;
  // Optional UI notifier (e.g., to show SnackBars)
  void Function(String message)? onNotify;

  // Broadcast so multiple listeners can subscribe.
  final StreamController<Map<String, dynamic>> _controller =
      StreamController<Map<String, dynamic>>.broadcast();

  LocalIngestServer({this.port = 6175});

  Stream<Map<String, dynamic>> get stream => _controller.stream;

  Future<void> start() async {
    if (_server != null) return;
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    } on SocketException catch (e) {
      final code = e.osError?.errorCode;
      final msg = 'Local ingest server not started: port $port is in use';
      //TODO Show this error message in the UI snackbar, now not working, context missing

      // Notify UI if provided, otherwise log only
      onNotify?.call(msg);

      print('$msg${code != null ? ' (OS error $code)' : ''}');

      _server = null;
      return; // Gracefully continue app without the local server
    } catch (e) {
      final msg = 'Local ingest server failed to start: $e';
      onNotify?.call(msg);
      print(msg);
      _server = null;
      return;
    }
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

          // RESTORED LOGIC: Always notify the UI stream first
          //    _controller.add(data);

          Map<String, dynamic> responseData;

          if (onRequest != null) {
            // New Logic: Wait for search results from main.dart
            responseData = await onRequest!(data);
            print("Sending HTTP response: $responseData");
          } else {
            // Fallback: Just say OK
            responseData = {'status': 'ok'};
          }

          // Send response (either search results or just 'ok')

          _reply(req, 200, responseData);
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
    req.response.headers.set('Content-Type', 'application/json; charset=utf-8');
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
