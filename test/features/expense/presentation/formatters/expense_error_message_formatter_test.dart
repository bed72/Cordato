import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/expense/presentation/formatters/expense_error_message_formatter.dart';

void main() {
  const fallback = 'Não foi possível salvar a despesa.';

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
