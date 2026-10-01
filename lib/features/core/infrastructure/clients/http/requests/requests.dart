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
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
  }) => Requests(
    route.path,
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
    HttpPathEnum? route,
    bool? logRequest,
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
