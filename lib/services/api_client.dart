import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ApiResponse {
  final bool ok;
  final int statusCode;
  final Map<String, dynamic>? data;
  final String? rawText;
  final String? error;
  final bool isNetworkError;

  const ApiResponse({
    required this.ok,
    required this.statusCode,
    this.data,
    this.rawText,
    this.error,
    this.isNetworkError = false,
  });
}

class ApiClient {
  final http.Client _client;
  String? runtimeBaseUrlOverride;

  ApiClient({http.Client? client, this.runtimeBaseUrlOverride})
      : _client = client ?? http.Client();

  bool get hasEndpoint => ApiConfig.resolveBaseUrl(runtimeBaseUrlOverride) != null;

  Future<ApiResponse> request(
    String method,
    String path, {
    String? token,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
  }) async {
    final uri = ApiConfig.buildUri(
      path,
      runtimeOverride: runtimeBaseUrlOverride,
      queryParameters: queryParameters,
    );
    if (uri == null) {
      return const ApiResponse(
        ok: false,
        statusCode: 0,
        isNetworkError: true,
        error: 'Cloud server URL not configured for this device.',
      );
    }

    final reqHeaders = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      ...?headers,
    };

    try {
      final encodedBody = body != null ? json.encode(body) : null;
      const reqTimeout = Duration(seconds: 15);
      late final http.Response resp;

      switch (method.toUpperCase()) {
        case 'GET':
          resp = await _client
              .get(uri, headers: reqHeaders)
              .timeout(reqTimeout);
          break;
        case 'POST':
          resp = await _client
              .post(uri, headers: reqHeaders, body: encodedBody)
              .timeout(reqTimeout);
          break;
        case 'PUT':
          resp = await _client
              .put(uri, headers: reqHeaders, body: encodedBody)
              .timeout(reqTimeout);
          break;
        case 'PATCH':
          resp = await _client
              .patch(uri, headers: reqHeaders, body: encodedBody)
              .timeout(reqTimeout);
          break;
        case 'DELETE':
          resp = await _client
              .delete(uri, headers: reqHeaders)
              .timeout(reqTimeout);
          break;
        default:
          return ApiResponse(
            ok: false,
            statusCode: 400,
            error: 'Unsupported HTTP method: $method',
          );
      }

      Map<String, dynamic>? parsed;
      try {
        final decoded = json.decode(resp.body);
        if (decoded is Map<String, dynamic>) {
          parsed = decoded;
        }
      } catch (_) {}

      final isOk = resp.statusCode >= 200 && resp.statusCode < 300;
      return ApiResponse(
        ok: isOk,
        statusCode: resp.statusCode,
        data: parsed,
        rawText: resp.body,
        error: isOk
            ? null
            : (parsed?['error']?.toString() ??
                (resp.statusCode >= 500
                    ? 'Server is temporarily busy. Please try again.'
                    : 'Request failed (${resp.statusCode})')),
      );
    } on TimeoutException {
      return const ApiResponse(
        ok: false,
        statusCode: 0,
        isNetworkError: true,
        error: 'Connection timed out. Please try again.',
      );
    } catch (_) {
      return const ApiResponse(
        ok: false,
        statusCode: 0,
        isNetworkError: true,
        error: 'Unable to reach server. Please check your connection and try again.',
      );
    }
  }
}
