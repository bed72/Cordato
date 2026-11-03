import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_lucide_animated/flutter_lucide_animated.dart' as lucide;

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
      ExpenseCategoryEnum.pets: lucide.rabbit,
      ExpenseCategoryEnum.housing: lucide.home,
      ExpenseCategoryEnum.leisure: lucide.play,
      ExpenseCategoryEnum.travel: lucide.airplane,
      ExpenseCategoryEnum.health: lucide.heart,
      ExpenseCategoryEnum.food: lucide.cooking_pot,
      ExpenseCategoryEnum.insurance: lucide.shield_check,
      ExpenseCategoryEnum.education: lucide.book_text,
      ExpenseCategoryEnum.personalCare: lucide.sparkles,
      ExpenseCategoryEnum.services: lucide.wrench,
      ExpenseCategoryEnum.financing: lucide.hand_coins,
      ExpenseCategoryEnum.taxes: lucide.file_check,
      ExpenseCategoryEnum.shopping: lucide.cart,
      ExpenseCategoryEnum.subscriptions: lucide.refresh_cw,
      ExpenseCategoryEnum.investments: lucide.trending_up,
      ExpenseCategoryEnum.transport: lucide.truck,
      ExpenseCategoryEnum.giftsAndDonations: lucide.hand_heart,
      ExpenseCategoryEnum.other: lucide.file_text,
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
}
