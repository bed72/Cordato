import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_lucide_animated/flutter_lucide_animated.dart';

import 'package:cordato/features/expense/domain/enums/expense_category_enum.dart';
import 'package:cordato/features/expense/presentation/extensions/expense_category_extension.dart';

void main() {
  group('ExpenseCategoryExtension', () {
    final labels = <ExpenseCategoryEnum, String>{
      .health: 'Saúde',
      .leisure: 'Lazer',
      .taxes: 'Impostos',
      .travel: 'Viagens',
      .housing: 'Moradia',
      .shopping: 'Compras',
      .food: 'Alimentação',
      .insurance: 'Seguros',
      .services: 'Serviços',
      .education: 'Educação',
      .transport: 'Transporte',
      .financing: 'Financiamentos',
      .subscriptions: 'Assinaturas',
      .pets: 'Animais de estimação',
      .investments: 'Investimentos',
      .personalCare: 'Cuidados pessoais',
      .giftsAndDonations: 'Presentes e doações',
      .other: 'Outros',
    };

    for (final category in ExpenseCategoryEnum.values) {
      test('displays ${category.name} in Brazilian Portuguese', () {
        expect(category.label, labels[category]);
      });
    }
  });

  group('Expense category animated icons', () {
    const icons = {
      ExpenseCategoryEnum.pets: rabbit,
      ExpenseCategoryEnum.housing: home,
      ExpenseCategoryEnum.leisure: play,
      ExpenseCategoryEnum.travel: airplane,
      ExpenseCategoryEnum.health: heart,
      ExpenseCategoryEnum.food: cooking_pot,
      ExpenseCategoryEnum.insurance: shield_check,
      ExpenseCategoryEnum.education: book_text,
      ExpenseCategoryEnum.personalCare: sparkles,
      ExpenseCategoryEnum.services: wrench,
      ExpenseCategoryEnum.financing: hand_coins,
      ExpenseCategoryEnum.taxes: file_check,
      ExpenseCategoryEnum.shopping: cart,
      ExpenseCategoryEnum.subscriptions: refresh_cw,
      ExpenseCategoryEnum.investments: trending_up,
      ExpenseCategoryEnum.transport: truck,
      ExpenseCategoryEnum.giftsAndDonations: hand_heart,
      ExpenseCategoryEnum.other: file_text,
    };

    test('covers every expense category', () {
      expect(icons.keys, unorderedEquals(ExpenseCategoryEnum.values));
    });

    for (final entry in icons.entries) {
      test('maps ${entry.key.name} to an animated Lucide icon', () {
        final icon = entry.key.icon;

        expect(icon, same(entry.value));
        expect(icon.elements, isNotEmpty);
        expect(
          icon.animation != null ||
              icon.elements.any((element) => element.animation != null),
          isTrue,
        );
      });
    }
  });

  group('Category selection catalog', () {
    test('includes each domain category exactly once with Others last', () {
      final categories = ExpenseCategoryExtension.orderedValues;

      expect(categories, hasLength(ExpenseCategoryEnum.values.length));
      expect(categories.toSet(), ExpenseCategoryEnum.values.toSet());
      expect(categories.last, ExpenseCategoryEnum.other);
      expect(() => categories.add(.food), throwsUnsupportedError);
    });

    test('uses Portuguese alphabetical labels before Others', () {
      expect(
        ExpenseCategoryExtension.orderedValues.map(
          (category) => category.label,
        ),
        [
          'Alimentação',
          'Animais de estimação',
          'Assinaturas',
          'Compras',
          'Cuidados pessoais',
          'Educação',
          'Financiamentos',
          'Impostos',
          'Investimentos',
          'Lazer',
          'Moradia',
          'Presentes e doações',
          'Saúde',
          'Seguros',
          'Serviços',
          'Transporte',
          'Viagens',
          'Outros',
        ],
      );
    });

    for (final category in ExpenseCategoryEnum.values) {
      test('${category.value} has a description of five or six words', () {
        final description = category.description;

        expect(description, description.trim());
        expect(description, isNot(contains('\n')));
        expect(
          description.split(RegExp(r'\s+')).length,
          inInclusiveRange(5, 6),
        );
      });
    }
  });
}
