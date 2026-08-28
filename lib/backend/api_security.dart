import 'dart:convert';
import 'dart:math';

import 'package:shelf/shelf.dart';

/// Guards the loopback API.
///
/// Binding to 127.0.0.1 is not protection on its own: any page open in the
/// same browser can issue requests to localhost. Without these checks an
/// unrelated site could print receipts and open the cash drawer.
class ApiSecurity {
  ApiSecurity({required this.allowedOrigin}) : token = _mintToken();

  /// Minted per process. Handed to the frontend when the backend serves it,
  /// never baked into the bundle.
  final String token;

  /// The one origin the backend serves its own frontend from.
  final String allowedOrigin;

  static String _mintToken() {
    final rng = Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Rejects anything that is not the frontend this backend serves.
  Middleware get middleware => (Handler inner) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: _corsHeaders);
      }

      // Static assets and the bootstrap are open: the browser fetches them
      // before it has been given a token.
      if (!request.url.path.startsWith('api/')) {
        return inner(request);
      }

      final origin = request.headers['origin'];
      if (origin != null && origin != allowedOrigin) {
        return Response.forbidden(
          jsonEncode({'error': 'origin_not_allowed', 'origin': origin}),
          headers: _jsonHeaders,
        );
      }

      final auth = request.headers['authorization'];
      if (auth != 'Bearer $token') {
        return Response.forbidden(
          jsonEncode({'error': 'bad_token'}),
          headers: _jsonHeaders,
        );
      }

      final response = await inner(request);
      return response.change(headers: _corsHeaders);
    };
  };

  Map<String, String> get _corsHeaders => {
    'Access-Control-Allow-Origin': allowedOrigin,
    'Access-Control-Allow-Headers': 'authorization, content-type',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  };

  static const _jsonHeaders = {'content-type': 'application/json'};
}
