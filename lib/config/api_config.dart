import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String compileTimeBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get platformLabel {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name.toLowerCase();
  }

  static String? resolveBaseUrl([String? runtimeOverride]) {
    final overrideTrim = runtimeOverride?.trim() ?? '';
    final raw = overrideTrim.isNotEmpty ? overrideTrim : compileTimeBaseUrl.trim();

    if (raw.isNotEmpty) {
      final noTrailing = raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
      return noTrailing.endsWith('/api') ? noTrailing : '$noTrailing/api';
    }

    if (kIsWeb) {
      return '/api';
    }

    return null;
  }

  static Uri? buildUri(
    String path, {
    String? runtimeOverride,
    Map<String, String>? queryParameters,
  }) {
    final base = resolveBaseUrl(runtimeOverride);
    if (base == null) return null;

    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final full = '$base$normalizedPath';
    final uri = Uri.parse(full);
    if (queryParameters == null || queryParameters.isEmpty) return uri;
    return uri.replace(queryParameters: queryParameters);
  }
}
