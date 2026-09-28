final class const Requests(
  final String path, {
  final Map<String, dynamic>? body,
  final Map<String, dynamic>? query,
  final Map<String, dynamic>? headers,
}) {
  Requests copyWith({
    String? path,
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
  }) => Requests(
    path ?? this.path,
    body: body ?? this.body,
    query: query ?? this.query,
    headers: headers ?? this.headers,
  );
}
