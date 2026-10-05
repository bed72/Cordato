import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/core/infrastructure/clients/http/enums/http_path_enum.dart';

import 'package:cordato/features/user/infrastructure/responses/user_response.dart';

typedef DeleteDataSourceType = Either<ErrorsResponse, bool>;
typedef UpdateDataSourceType = Either<ErrorsResponse, UserResponse>;
typedef GetByIdDataSourceType = Either<ErrorsResponse, UserResponse>;

abstract interface class IUserRemoteDataSource {
  Future<DeleteDataSourceType> delete({required String id});

  Future<GetByIdDataSourceType> getById({required String id});

  Future<UpdateDataSourceType> update({required String id, String? name});
}

final class UserRemoteDataSource({required final IHttpClient _client})
    implements IUserRemoteDataSource {
  @override
  Future<DeleteDataSourceType> delete({required String id}) => _response(
    execute: () => _client.delete(
      parameter: Requests.forPath(
        HttpPathEnum.user,
        pathParameters: {'id': id},
      ),
    ),
    fromResponse: (response) {
      if (response.statusCode != 204) {
        throw const FormatException('Expected a 204 response');
      }
      return true;
    },
  );

  @override
  Future<GetByIdDataSourceType> getById({required String id}) => _response(
    execute: () => _client.get(
      parameter: Requests.forPath(
        HttpPathEnum.user,
        pathParameters: {'id': id},
      ),
    ),
    fromResponse: (response) => UserResponse.fromJson(response.body),
  );

  @override
  Future<UpdateDataSourceType> update({required String id, String? name}) =>
      _response(
        execute: () => _client.patch(
          parameter: Requests.forPath(
            HttpPathEnum.user,
            pathParameters: {'id': id},
            body: {
              'data': {
                'type': 'users',
                'id': id,
                'attributes': {'name': ?name},
              },
            },
          ),
        ),
        fromResponse: (response) => UserResponse.fromJson(response.body),
      );

  Future<Either<ErrorsResponse, T>> _response<T>({
    required Future<Responses> Function() execute,
    required T Function(HttpResponse) fromResponse,
  }) async {
    try {
      final response = await execute();
      return response.fold<Either<ErrorsResponse, T>>(
        (error) => Left(.fromJson(error.body)),
        (success) => Right(fromResponse(success)),
      );
    } catch (_) {
      return Left(.unknown());
    }
  }
}
