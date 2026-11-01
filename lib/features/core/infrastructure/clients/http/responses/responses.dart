import 'package:cordato/features/core/domain/entities/errors_entity.dart';

final class const Responses({
  required final int status,
  required final Map<String, dynamic> body,
});

final class const ErrorsResponse({required final List<ErrorResponse> errors}) {
  factory ErrorsResponse.fromJson(Map<String, dynamic> json) {
    final errors = (json['errors'] as List<dynamic>)
        .map((error) => ErrorResponse.fromJson(error as Map<String, dynamic>))
        .toList();

    return errors.isEmpty ? .unknown() : ErrorsResponse(errors: errors);
  }

  factory ErrorsResponse.unknown() => const ErrorsResponse(
    errors: [
      ErrorResponse(
        title: 'Erro desconhecido',
        detail: 'Não foi possível processar a resposta.',
      ),
    ],
  );

  factory ErrorsResponse.fromPocketBaseJson(
    Map<String, dynamic> json, {
    required int status,
  }) {
    final message = json['message'] as String;
    final data = json['data'] as Map<String, dynamic>;
    final errors = data.entries.map((entry) {
      final error = entry.value as Map<String, dynamic>;
      final field = entry.key.replaceAll('~', '~0').replaceAll('/', '~1');
      return ErrorResponse(
        code: error['code'] as String,
        title: message,
        detail: error['message'] as String,
        status: status.toString(),
        pointer: '/$field',
        parameter: entry.key,
      );
    }).toList();

    return ErrorsResponse(
      errors: errors.isEmpty
          ? [ErrorResponse(status: status.toString(), detail: message)]
          : errors,
    );
  }
}

final class const ErrorResponse({
  final String? code,
  final String? title,
  final String? detail,
  final String? status,
  final String? pointer,
  final String? parameter,
}) {
  factory ErrorResponse.fromJson(Map<String, dynamic> json) => ErrorResponse(
    title: json['title'] as String?,
    status: json['status'] as String?,
    detail: json['detail'] as String?,
    pointer: (json['source'] as Map<String, dynamic>?)?['pointer'] as String?,
    parameter:
        (json['source'] as Map<String, dynamic>?)?['parameter'] as String?,
  );
}

extension ErrorsResponseToEntity on ErrorsResponse {
  ErrorsEntity toEntity() => errors.isEmpty
      ? .unknown()
      : ErrorsEntity(
          errors: errors
              .map(
                (error) => ErrorEntity(
                  code: error.code,
                  title: error.title,
                  detail: error.detail,
                  status: error.status,
                  pointer: error.pointer,
                  parameter: error.parameter,
                ),
              )
              .toList(),
        );
}
