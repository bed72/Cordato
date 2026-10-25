import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/storage_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/core/infrastructure/clients/http/enums/http_path_enum.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/enums/storage_key_enum.dart';
import 'package:cordato/features/core/infrastructure/clients/http/exceptions/http_client_exception.dart';

import 'package:cordato/features/user/domain/entities/user_entity.dart';
import 'package:cordato/features/user/infrastructure/responses/user_response.dart';

import 'package:cordato/features/user/application/exceptions/user_exception.dart';
import 'package:cordato/features/user/application/repositories/interface_user_repository.dart';

final class UserRepository({
  required final IHttpClient _httpClient,
  required final IStorageClient _storageClient,
}) implements IUserRepository {
  @override
  Future<UserEntity> getById() async {
    try {
      final id = await _getId();

      final response = await _httpClient.get(
        parameter: Requests(
          path: '${HttpPathEnum.user.path}/${Uri.encodeComponent(id)}',
        ),
      );

      return UserResponse.fromJson(response.body).toEntity();
    } on HttpResponseException catch (exception) {
      throw UserException(errors: exception.errors.toEntity());
    } on HttpClientException {
      throw UserException(errors: .unknown());
    }
  }

  @override
  Future<UserEntity> update({String? name, String? avatar}) async {
    try {
      final id = await _getId();

      final response = await _httpClient.patch(
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
      );

      return UserResponse.fromJson(response.body).toEntity();
    } on HttpResponseException catch (exception) {
      throw UserException(errors: exception.errors.toEntity());
    } on HttpClientException {
      throw UserException(errors: .unknown());
    }
  }

  @override
  Future<void> delete() async {
    try {
      final id = await _getId();
      final response = await _httpClient.delete(
        parameter: Requests(
          path: '${HttpPathEnum.user.path}/${Uri.encodeComponent(id)}',
        ),
      );

      if (response.status != 204) {
        throw UserException(errors: .unknown());
      }
    } on HttpResponseException catch (exception) {
      throw UserException(errors: exception.errors.toEntity());
    } on HttpClientException {
      throw UserException(errors: .unknown());
    }

    await _storageClient.clear();
  }

  Future<String> _getId() async {
    final id = await _storageClient.read(key: StorageKeyEnum.userId.key);
    if (id == null || id.trim().isEmpty) {
      throw UserException(
        errors: const ErrorsEntity(
          errors: [
            ErrorEntity(
              title: 'Usuário não identificado',
              detail: 'Não foi possível identificar o usuário atual.',
            ),
          ],
        ),
      );
    }
    return id;
  }
}
