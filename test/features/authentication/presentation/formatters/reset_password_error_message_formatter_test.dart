import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/authentication/presentation/formatters/reset_password_error_message_formatter.dart';

void main() {
  group('Reset password field messages', () {
    test('preserves field message order without exposing remote text', () {
      const errors = ErrorsEntity(
        errors: [
          ErrorEntity(
            status: '400',
            pointer: '/password',
            code: 'validation_required',
            detail: 'remote secret',
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

      final fields = ResetPasswordErrorMessageFormatter.fields(errors);

      expect(
        fields.password,
        'Informe sua senha.\nA senha deve ter entre 6 e 16 caracteres.',
      );
      expect(fields.confirmation, 'As senhas não coincidem.');
      expect(fields.toast, isNull);
    });

    test('unknown field codes use local field fallbacks', () {
      const errors = ErrorsEntity(
        errors: [
          ErrorEntity(status: '400', pointer: '/password', detail: 'secret'),
          ErrorEntity(
            status: '400',
            pointer: '/passwordConfirm',
            detail: 'secret',
          ),
        ],
      );

      final fields = ResetPasswordErrorMessageFormatter.fields(errors);

      expect(fields.password, 'Confira a senha informada.');
      expect(fields.confirmation, 'Confira a confirmação da senha.');
      expect(fields.toast, isNull);
    });
  });

  group('Reset password toast messages', () {
    test('empty errors use the operation fallback', () {
      final fields = ResetPasswordErrorMessageFormatter.fields(
        const ErrorsEntity(errors: []),
      );

      expect(fields.password, isNull);
      expect(fields.confirmation, isNull);
      expect(
        fields.toast,
        'Não foi possível redefinir a senha. Tente novamente.',
      );
    });

    test('non-field errors remain in the toast alongside field errors', () {
      const errors = ErrorsEntity(
        errors: [
          ErrorEntity(
            status: '400',
            pointer: '/password',
            code: 'validation_required',
          ),
          ErrorEntity(status: '403', pointer: '/password', detail: 'secret'),
          ErrorEntity(status: '400', pointer: '/other', detail: 'secret'),
        ],
      );

      final fields = ResetPasswordErrorMessageFormatter.fields(errors);

      expect(fields.password, 'Informe sua senha.');
      expect(fields.confirmation, isNull);
      expect(fields.toast, contains('Você não tem permissão'));
      expect(fields.toast, isNot(contains('secret')));
    });
  });
}
