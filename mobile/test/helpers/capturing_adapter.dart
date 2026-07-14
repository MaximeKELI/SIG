import 'dart:convert';

import 'package:dio/dio.dart';

/// HttpClientAdapter de test qui capture path/méthode/body JSON.
class CapturingAdapter implements HttpClientAdapter {
  CapturingAdapter({this.response = const {}});

  final Map<String, dynamic> response;
  final List<CapturedRequest> requests = [];

  CapturedRequest? get last => requests.isEmpty ? null : requests.last;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    Object? body;
    if (requestStream != null) {
      final chunks = <int>[];
      await for (final chunk in requestStream) {
        chunks.addAll(chunk);
      }
      if (chunks.isNotEmpty) {
        body = jsonDecode(utf8.decode(chunks));
      }
    }
    requests.add(
      CapturedRequest(
        method: options.method,
        path: options.path,
        query: Map<String, dynamic>.from(options.queryParameters),
        body: body,
      ),
    );
    return ResponseBody.fromString(
      jsonEncode(response),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

class CapturedRequest {
  CapturedRequest({
    required this.method,
    required this.path,
    required this.query,
    required this.body,
  });

  final String method;
  final String path;
  final Map<String, dynamic> query;
  final Object? body;
}
