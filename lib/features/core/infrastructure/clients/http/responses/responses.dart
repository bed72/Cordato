import 'package:cordato/features/core/domain/either.dart';

typedef Responses = Either<Map<String, dynamic>, Map<String, dynamic>>;

final class const ErrorsResponse({required final List<ErrorResponse> errors}) {
  factory ErrorsResponse.fromJson(Map<String, dynamic> json) => ErrorsResponse(
    errors: (json['errors'] as List<dynamic>)
        .map((error) => ErrorResponse.fromJson(error as Map<String, dynamic>))
        .toList(),
  );
}

final class const ErrorResponse({
  final String? title,
  final String? detail,
  final String? status,
  final String? pointer,
}) {
  factory ErrorResponse.fromJson(Map<String, dynamic> json) => ErrorResponse(
    title: json['title'] as String?,
    status: json['status'] as String?,
    detail: json['detail'] as String?,
    pointer: (json['source'] as Map<String, dynamic>?)?['pointer'] as String?,
  );
}
