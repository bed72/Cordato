import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/expense/presentation/formatters/expense_error_message_formatter.dart';

void main() {
  const fallback = 'Não foi possível salvar a despesa.';

  group('Expense form error classification', () {
    for (final source in [
      (status: '400', prefix: ''),
      (status: '422', prefix: '/data/attributes'),
    ]) {
      test('${source.status} maps all form fields and preserves order', () {
        final errors = ErrorsEntity(
          errors: [
            ErrorEntity(
              status: source.status,
              pointer: '${source.prefix}/amount',
              code: 'validation_required',
            ),
            ErrorEntity(
              status: source.status,
              pointer: '${source.prefix}/description',
              code: 'validation_required',
            ),
            ErrorEntity(
              status: source.status,
              pointer: '${source.prefix}/description',
              code: 'validation_length',
            ),
            ErrorEntity(
              status: source.status,
              pointer: '${source.prefix}/occurred_on',
            ),
          ],
        );

        final fields = ExpenseErrorMessageFormatter.fields(
          errors,
          isEditing: false,
        );

        expect(fields.cents, 'Informe um valor maior que zero.');
        expect(
          fields.description,
          'Informe uma descrição.\nA descrição deve ter entre 2 e 128 caracteres.',
        );
        expect(fields.date, 'Informe uma data válida.');
        expect(fields.toast, isNull);
      });
    }

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
      test('empty errors use fallback for editing=${operation.isEditing}', () {
        final fields = ExpenseErrorMessageFormatter.fields(
          const ErrorsEntity(errors: []),
          isEditing: operation.isEditing,
        );

        expect(fields.cents, isNull);
        expect(fields.description, isNull);
        expect(fields.date, isNull);
        expect(fields.toast, operation.message);
      });
    }

    test('non-field errors use safe deduplicated toast messages', () {
      const errors = ErrorsEntity(
        errors: [
          ErrorEntity(status: '403', pointer: '/amount', detail: 'secret'),
          ErrorEntity(status: '403', pointer: '/amount', detail: 'secret'),
          ErrorEntity(
            status: '400',
            pointer: '/description',
            code: 'validation_required',
          ),
        ],
      );

      final fields = ExpenseErrorMessageFormatter.fields(
        errors,
        isEditing: false,
      );

      expect(fields.cents, isNull);
      expect(fields.description, 'Informe uma descrição.');
      expect(fields.toast, 'Você não tem permissão para realizar esta ação.');
    });
  });

  group('Expense field messages', () {
    const scenarios = [
      (
        field: 'amount',
        code: 'validation_required',
        message: 'Informe um valor maior que zero.',
      ),
      (
        field: 'amount',
        code: 'validation_min_greater_equal_than_required',
        message: 'Informe um valor maior que zero.',
      ),
      (field: 'amount', code: 'unknown', message: 'Confira o valor informado.'),
      (
        field: 'description',
        code: 'validation_required',
        message: 'Informe uma descrição.',
      ),
      (
        field: 'description',
        code: 'validation_length',
        message: 'A descrição deve ter entre 2 e 128 caracteres.',
      ),
      (
        field: 'description',
        code: 'validation_length_out_of_range',
        message: 'A descrição deve ter entre 2 e 128 caracteres.',
      ),
      (
        field: 'description',
        code: 'unknown',
        message: 'Confira a descrição informada.',
      ),
      (
        field: 'occurred_on',
        code: 'validation_date',
        message: 'Informe uma data válida.',
      ),
      (
        field: 'category',
        code: 'validation_in_invalid',
        message: 'Selecione uma categoria válida.',
      ),
    ];

    for (final scenario in scenarios) {
      for (final source in [
        (status: '400', prefix: ''),
        (status: '422', prefix: '/data/attributes'),
      ]) {
        test('${source.status} ${scenario.field}: ${scenario.code}', () {
          final error = ErrorEntity(
            status: source.status,
            pointer: '${source.prefix}/${scenario.field}',
            code: scenario.code,
            title: 'Failed to save record.',
            detail: 'English field validation.',
          );

          expect(
            ExpenseErrorMessageFormatter.format(error, fallback: fallback),
            scenario.message,
          );
        });
      }
    }

    test('missing remote detail still has a field message', () {
      expect(
        ExpenseErrorMessageFormatter.format(
          const ErrorEntity(status: '400', pointer: '/occurred_on'),
          fallback: fallback,
        ),
        'Informe uma data válida.',
      );
    });

    test('unknown fields and codes use the operation fallback', () {
      expect(
        ExpenseErrorMessageFormatter.format(
          const ErrorEntity(
            status: '400',
            pointer: '/owner',
            code: 'unknown',
            detail: 'Private data.',
          ),
          fallback: fallback,
        ),
        fallback,
      );
    });

    test('access errors do not become amount validation failures', () {
      expect(
        ExpenseErrorMessageFormatter.format(
          const ErrorEntity(status: '403', pointer: '/amount'),
          fallback: fallback,
        ),
        'Você não tem permissão para realizar esta ação.',
      );
    });
  });
}
