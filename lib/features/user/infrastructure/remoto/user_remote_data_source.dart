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

  Future<UpdateDataSourceType> update({
    required String id,
    String? name,
    String? avatar,
  });
}

final class UserRemoteDataSource({required final IHttpClient _client})
    implements IUserRemoteDataSource {
  @override
  Future<DeleteDataSourceType> delete({required String id}) => response(
    from: (response) => response.statusCode == 204,
    execute: () => _client.delete(
      parameter: Requests(
        path: '${HttpPathEnum.user.path}/${Uri.encodeComponent(id)}',
      ),
    ),
  );

  @override
  Future<GetByIdDataSourceType> getById({required String id}) => response(
    from: (response) => .fromJson(response.body),
    execute: () => _client.get(
      parameter: Requests(
        path: '${HttpPathEnum.user.path}/${Uri.encodeComponent(id)}',
      ),
    ),
  );

  @override
  Future<UpdateDataSourceType> update({
    required String id,
    String? name,
    String? avatar,
  }) => response(
    from: (response) => .fromJson(response.body),
    execute: () => _client.patch(
      parameter: Requests(
        path: '${HttpPathEnum.user.path}/${Uri.encodeComponent(id)}',
        body: {
          'data': {
            'id': id,
            'type': 'users',
            'attributes': {'name': ?name, 'avatar': ?avatar},
          },
        },
      ),
    ),
  );
}
