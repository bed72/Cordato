import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';

final class const Reponse({
  required final int status,
  required final Map<String, dynamic> body,
});

typedef Responses = Either<Reponse, Reponse>;

Future<Either<ErrorsResponse, T>> response<T>({
  required T Function(Reponse) from,
  required Future<Responses> Function() execute,
}) async {
  try {
    final response = await execute();

    return response.fold<Either<ErrorsResponse, T>>(
      (error) => Left(.fromJson(error.body)),
      (success) => Right(from(success)),
    );
  } catch (_) {
    return Left(.unknown());
  }
}

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
}

final class const ErrorResponse({
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
