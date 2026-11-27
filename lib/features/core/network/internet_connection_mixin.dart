import 'dart:async';

import 'package:http/http.dart' as http;

const noInternetConnectionMessage = 'لا يتوفر اتصال بالإنترنت';

class NoInternetConnectionException implements Exception {
  const NoInternetConnectionException();

  @override
  String toString() => noInternetConnectionMessage;
}

/// Performs an active request to the internet instead of relying on whether
/// the device is merely attached to Wi-Fi or mobile data.
mixin InternetConnectionMixin {
  static const _successfulCheckLifetime = Duration(seconds: 3);
  static const _probeTimeout = Duration(seconds: 4);
  static const _probeUris = <String>[
    'https://www.google.com/generate_204',
    'https://1.1.1.1/cdn-cgi/trace',
  ];

  static DateTime? _lastSuccessfulCheck;
  static Future<bool>? _pendingCheck;

  Future<bool> hasRealInternetConnection({bool forceCheck = false}) async {
    final lastCheck = _lastSuccessfulCheck;
    if (!forceCheck &&
        lastCheck != null &&
        DateTime.now().difference(lastCheck) < _successfulCheckLifetime) {
      return true;
    }

    final pending = _pendingCheck;
    if (pending != null) return pending;

    final check = _runActiveCheck();
    _pendingCheck = check;
    try {
      final connected = await check;
      if (connected) _lastSuccessfulCheck = DateTime.now();
      return connected;
    } finally {
      if (identical(_pendingCheck, check)) _pendingCheck = null;
    }
  }

  Future<void> ensureInternetConnection({bool forceCheck = false}) async {
    if (!await hasRealInternetConnection(forceCheck: forceCheck)) {
      throw const NoInternetConnectionException();
    }
  }

  Future<T> runWithInternetConnection<T>(Future<T> Function() request) async {
    await ensureInternetConnection();
    try {
      return await request();
    } catch (error) {
      if (!_looksLikeNetworkFailure(error)) rethrow;
      _lastSuccessfulCheck = null;
      if (!await hasRealInternetConnection(forceCheck: true)) {
        throw const NoInternetConnectionException();
      }
      rethrow;
    }
  }

  Future<bool> _runActiveCheck() async {
    final client = http.Client();
    try {
      final results = await Future.wait(
        _probeUris.map((value) async {
          try {
            final response = await client
                .get(
                  Uri.parse(value),
                  headers: const {'cache-control': 'no-cache'},
                )
                .timeout(_probeTimeout);
            if (value.contains('generate_204')) {
              return response.statusCode == 204;
            }
            return response.statusCode == 200 &&
                response.body.contains(RegExp(r'(^|\n)fl='));
          } catch (_) {
            return false;
          }
        }),
      );
      return results.any((connected) => connected);
    } finally {
      client.close();
    }
  }

  bool _looksLikeNetworkFailure(Object error) {
    if (error is TimeoutException || error is http.ClientException) return true;
    final message = error.toString().toLowerCase();
    return message.contains('socket') ||
        message.contains('network') ||
        message.contains('connection') ||
        message.contains('failed host lookup') ||
        message.contains('timed out') ||
        message.contains('timeout') ||
        message.contains('handshake') ||
        message.contains('errno') ||
        message.contains('لا يتوفر اتصال');
  }
}

/// A shared HTTP client for Supabase. This makes all database, auth, storage,
/// and edge-function calls fail with the same user-friendly offline error.
class InternetCheckedHttpClient extends http.BaseClient
    with InternetConnectionMixin {
  InternetCheckedHttpClient([http.Client? inner])
    : _inner = inner ?? http.Client();

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      runWithInternetConnection(() => _inner.send(request));

  @override
  void close() => _inner.close();
}
