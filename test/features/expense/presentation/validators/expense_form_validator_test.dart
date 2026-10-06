import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/presentation/validators/validation.dart';
import 'package:cordato/features/expense/presentation/validators/expense_cents_validation.dart';
import 'package:cordato/features/expense/presentation/validators/expense_date_validation.dart';
import 'package:cordato/features/expense/presentation/validators/expense_description_validation.dart';
import 'package:cordato/features/expense/presentation/validators/expense_form_validator.dart';

void main() {
  const validator = ExpenseFormValidator(
    centsValidation: ExpenseCentsValidation(),
    dateValidation: ExpenseDateValidation(),
    descriptionValidation: ExpenseDescriptionValidation(),
  );

  test('returns validated data for each field of a complete form', () {
    final date = DateTime(2026, 10, 5);

    final result = validator(
      cents: 300,
      description: '  Game  ',
      occurredOn: date,
    );

    expect(
      result.cents,
      isA<Valid<int>>().having((field) => field.value, 'value', 300),
    );
    expect(
      result.description,
      isA<Valid<String>>().having((field) => field.value, 'value', 'Game'),
    );
    expect(
      result.occurredOn,
      isA<Valid<DateTime?>>().having(
        (field) => field.value,
        'value',
        same(date),
      ),
    );
  });

  test('reports all invalid fields in a single validation', () {
    final result = validator(cents: 0, description: '   ', occurredOn: null);

    expect(
      result.cents,
      isA<Invalid<int>>().having(
        (field) => field.message,
        'message',
        'Informe um valor maior que zero',
      ),
    );
    expect(
      result.description,
      isA<Invalid<String>>().having(
        (field) => field.message,
        'message',
        'Informe uma descrição',
      ),
    );
    expect(
      result.occurredOn,
      isA<Invalid<DateTime?>>().having(
        (field) => field.message,
        'message',
        'Selecione a data',
      ),
    );
  });

  test('keeps valid fields when only the description is invalid', () {
    final result = validator(
      cents: 1,
      description: 'a',
      occurredOn: DateTime(2026, 10, 5),
    );

    expect(result.cents, isA<Valid<int>>());
    expect(result.description, isA<Invalid<String>>());
    expect(result.occurredOn, isA<Valid<DateTime?>>());
  });

  test('allows correcting invalid fields and validating the form again', () {
    final invalid = validator(cents: -1, description: '', occurredOn: null);
    final valid = validator(
      cents: 300,
      description: 'Game',
      occurredOn: DateTime(2026, 10, 5),
    );

    expect(invalid.cents, isA<Invalid<int>>());
    expect(invalid.description, isA<Invalid<String>>());
    expect(invalid.occurredOn, isA<Invalid<DateTime?>>());
    expect(valid.cents, isA<Valid<int>>());
    expect(valid.description, isA<Valid<String>>());
    expect(valid.occurredOn, isA<Valid<DateTime?>>());
  });
}
