import 'package:cordato/features/core/infrastructure/clients/storage/storage_client.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/enums/storage_key_enum.dart';

import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/core/infrastructure/clients/http/enums/http_path_enum.dart';
import 'package:cordato/features/core/infrastructure/clients/http/exceptions/http_client_exception.dart';

import 'package:cordato/features/session/infrastructure/responses/session_response.dart';
import 'package:cordato/features/session/application/exceptions/session_exception.dart';
import 'package:cordato/features/session/application/repositories/interface_session_repository.dart';

final class SessionRepository({
  required final IHttpClient _httpClient,
  required final IStorageClient _storageClient,
}) implements ISessionRepository {
  Future<bool>? _pending;

  @override
  Future<bool> loadSession() =>
      _pending ??= _refresh().whenComplete(() => _pending = null);

  Future<bool> _refresh() async {
    final token = await _storageClient.read(key: StorageKeyEnum.token.key);
    if (token == null || token.isEmpty) return false;

    Responses response;
    try {
      response = await _httpClient.post(
        parameter: Requests(path: HttpPathEnum.authRefresh.path),
      );
    } on HttpResponseException catch (exception) {
      final current = await _storageClient.read(key: StorageKeyEnum.token.key);
      if (current != token) return current != null && current.isNotEmpty;
      if (exception.status == 401) return false;

      throw SessionException(errors: exception.errors.toEntity());
    } on HttpClientException {
      final current = await _storageClient.read(key: StorageKeyEnum.token.key);
      if (current != token) return current != null && current.isNotEmpty;

      throw SessionException(errors: .unknown());
    }

    final current = await _storageClient.read(key: StorageKeyEnum.token.key);
    if (current != token) return current != null && current.isNotEmpty;

    final data = SessionResponse.fromJson(response.body);
    await _storageClient.write(
      key: StorageKeyEnum.userId.key,
      value: data.userId,
    );

    final latest = await _storageClient.read(key: StorageKeyEnum.token.key);
    if (latest != token) return latest != null && latest.isNotEmpty;
    await _storageClient.write(
      key: StorageKeyEnum.token.key,
      value: data.token,
    );

    return true;
  }

  @override
  Stream<bool> get sessionChanges => _storageClient
      .watch(key: StorageKeyEnum.token.key)
      .map((token) => token != null && token.isNotEmpty);
}
