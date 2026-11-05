import 'package:flutter_test/flutter_test.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/authentication/presentation/formatters/change_password_error_message_formatter.dart';

void main() {
  group('Field mapping', () {
    test('maps fields without exposing remote text or losing order', () {
      const errors = ErrorsEntity(
        errors: [
          ErrorEntity(
            status: '400',
            pointer: '/oldPassword',
            code: 'validation_invalid_old_password',
            title: 'remote secret',
            detail: 'remote secret',
          ),
          ErrorEntity(
            status: '400',
            pointer: '/oldPassword',
            code: 'validation_required',
          ),
          ErrorEntity(
            status: '400',
            pointer: '/password',
            code: 'validation_length',
          ),
          ErrorEntity(
            status: '400',
            pointer: '/passwordConfirm',
            code: 'validation_values_mismatch',
          ),
        ],
      );
      final fields = ChangePasswordErrorMessageFormatter.fields(errors);
      expect(
        fields.current,
        'A senha atual está incorreta.\nInforme sua senha atual.',
      );
      expect(fields.password, 'A senha deve ter entre 6 e 16 caracteres.');
      expect(fields.confirmation, 'As senhas não coincidem.');
      expect(fields.toast, isNull);
    });

    test('unknown old password code has safe local fallback', () {
      expect(
        ChangePasswordErrorMessageFormatter.format(
          const ErrorEntity(
            status: '400',
            pointer: '/oldPassword',
            code: 'future',
            detail: 'secret',
          ),
        ),
        'Confira sua senha atual.',
      );
    });
  });

  group('Toast fallback', () {
    for (final errors in [
      const ErrorsEntity(errors: []),
      const ErrorsEntity(
        errors: [ErrorEntity(status: '500', detail: 'secret')],
      ),
      const ErrorsEntity(
        errors: [
          ErrorEntity(status: '400', pointer: '/other', title: 'secret'),
        ],
      ),
    ]) {
      test(
        'returns safe toast for ${errors.errors.map((e) => e.status).join()}',
        () {
          final fields = ChangePasswordErrorMessageFormatter.fields(errors);
          expect(fields.toast, isNotNull);
          expect(fields.toast, isNot(contains('secret')));
          expect(fields.current, isNull);
          expect(fields.password, isNull);
          expect(fields.confirmation, isNull);
        },
      );
    }
  });
}
