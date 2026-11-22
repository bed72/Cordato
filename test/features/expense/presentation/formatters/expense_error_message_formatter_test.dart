import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/expense/presentation/formatters/expense_error_message_formatter.dart';

void main() {
  group('Local expense error messages', () {
    const messages = {
      'invalid_amount': 'Informe um valor maior que zero.',
      'expense_not_found': 'Não foi possível encontrar a despesa.',
    };

    for (final entry in messages.entries) {
      test('formats ${entry.key} without exposing storage diagnostics', () {
        final error = ErrorEntity(
          code: entry.key,
          detail: 'private storage diagnostic',
        );

        expect(
          ExpenseErrorMessageFormatter.format(error, fallback: 'Falha local.'),
          entry.value,
        );
      });
    }

    test('unknown errors use the operation fallback', () {
      expect(
        ExpenseErrorMessageFormatter.format(
          const ErrorEntity(detail: 'private storage diagnostic'),
          fallback: 'Não foi possível salvar a despesa.',
        ),
        'Não foi possível salvar a despesa.',
      );
    });
  });

  group('Expense form error classification', () {
    test(
      'classifies local amount errors and preserves the original metadata',
      () {
        const error = ErrorEntity(
          code: 'invalid_amount',
          parameter: 'amount',
          detail: 'private diagnostic',
        );
        const errors = ErrorsEntity(errors: [error, error]);

        final fields = ExpenseErrorMessageFormatter.fields(
          errors,
          isEditing: false,
        );

        expect(fields.cents, 'Informe um valor maior que zero.');
        expect(fields.toast, isNull);
        expect(errors.errors, [same(error), same(error)]);
        expect(error.parameter, 'amount');
        expect(error.detail, 'private diagnostic');
      },
    );

    test('does not classify an amount error without its field parameter', () {
      final fields = ExpenseErrorMessageFormatter.fields(
        const ErrorsEntity(errors: [ErrorEntity(code: 'invalid_amount')]),
        isEditing: false,
      );

      expect(fields.cents, isNull);
      expect(fields.toast, 'Informe um valor maior que zero.');
    });

    test('keeps field errors alongside deduplicated operation failures', () {
      final fields = ExpenseErrorMessageFormatter.fields(
        const ErrorsEntity(
          errors: [
            ErrorEntity(code: 'invalid_amount', parameter: 'amount'),
            ErrorEntity(code: 'expense_not_found'),
            ErrorEntity(code: 'expense_not_found'),
            ErrorEntity(detail: 'private diagnostic'),
          ],
        ),
        isEditing: true,
      );

      expect(fields.cents, 'Informe um valor maior que zero.');
      expect(
        fields.toast,
        'Não foi possível encontrar a despesa.\n'
        'Não foi possível atualizar o gasto. Tente novamente.',
      );
    });

    for (final operation in [
      (
        isEditing: false,
        message: 'Não foi possível cadastrar o gasto. Tente novamente.',
      ),
      (
        isEditing: true,
        message: 'Não foi possível atualizar o gasto. Tente novamente.',
      ),
    ]) {
      test(
        'empty errors use the fallback for editing=${operation.isEditing}',
        () {
          final fields = ExpenseErrorMessageFormatter.fields(
            const ErrorsEntity(errors: []),
            isEditing: operation.isEditing,
          );

          expect(fields.cents, isNull);
          expect(fields.toast, operation.message);
        },
      );
    }
  });

  group('Reregistration feedback', () {
    test('uses the local fallback for an empty error collection', () {
      expect(
        ExpenseErrorMessageFormatter.reregistration(
          const ErrorsEntity(errors: []),
        ),
        'Tente novamente em instantes.',
      );
    });

    test('deduplicates local messages in their original order', () {
      expect(
        ExpenseErrorMessageFormatter.reregistration(
          const ErrorsEntity(
            errors: [
              ErrorEntity(code: 'expense_not_found'),
              ErrorEntity(code: 'expense_not_found'),
              ErrorEntity(detail: 'private diagnostic'),
            ],
          ),
        ),
        'Não foi possível encontrar a despesa.\nTente novamente em instantes.',
      );
    });
  });
}
