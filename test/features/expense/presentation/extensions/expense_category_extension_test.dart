import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/expense/domain/enums/expense_category_enum.dart';
import 'package:cordato/features/expense/presentation/extensions/expense_category_extension.dart';

void main() {
  group('ExpenseCategoryExtension', () {
    final labels = <ExpenseCategoryEnum, String>{
      .food: 'Alimentação',
      .health: 'Saúde',
      .housing: 'Moradia',
      .leisure: 'Lazer',
      .shopping: 'Compras',
      .services: 'Serviços',
      .transport: 'Transporte',
      .education: 'Educação',
      .subscriptions: 'Assinaturas',
      .other: 'Outros',
    };

    for (final category in ExpenseCategoryEnum.values) {
      test('displays ${category.name} in Brazilian Portuguese', () {
        expect(category.label, labels[category]);
      });
    }
  });
}
