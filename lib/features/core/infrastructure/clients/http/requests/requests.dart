import 'package:cordato/features/core/infrastructure/clients/http/enums/http_path_enum.dart';

final class const Requests(
  final String path, {
  final HttpPathEnum? route,
  final Map<String, dynamic>? body,
  final Map<String, dynamic>? query,
  final Map<String, dynamic>? headers,
  final bool logRequest = true,
  final bool followRedirects = true,
}) {
  factory Requests.forPath(
    HttpPathEnum route, {
    Map<String, String> pathParameters = const {},
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
  }) => Requests(
    route.path.replaceAllMapped(RegExp(r'\{([^}]+)\}'), (match) {
      final value = pathParameters[match.group(1)];
      if (value == null || value.isEmpty || value == '.' || value == '..') {
        throw ArgumentError('Invalid path parameter: ${match.group(1)}');
      }
      return Uri.encodeComponent(value);
    }),
    body: body,
    query: query,
    route: route,
    headers: headers,
  );

  Requests copyWith({
    String? path,
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    bool? logRequest,
    HttpPathEnum? route,
    bool? followRedirects,
  }) => Requests(
    path ?? this.path,
    body: body ?? this.body,
    query: query ?? this.query,
    headers: headers ?? this.headers,
    logRequest: logRequest ?? this.logRequest,
    route: path == null ? route ?? this.route : route,
    followRedirects: followRedirects ?? this.followRedirects,
  );
}
