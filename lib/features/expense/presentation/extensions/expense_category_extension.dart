import 'package:cordato/features/expense/domain/enums/expense_category_enum.dart';

extension ExpenseCategoryExtension on ExpenseCategoryEnum {
  String get label => switch (this) {
    .health => 'Saúde',
    .leisure => 'Lazer',
    .housing => 'Moradia',
    .food => 'Alimentação',
    .shopping => 'Compras',
    .services => 'Serviços',
    .education => 'Educação',
    .transport => 'Transporte',
    .subscriptions => 'Assinaturas',
    .other => 'Outros',
  };
}
