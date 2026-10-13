import 'package:material_ui/material_ui.dart';

mixin UserNameWidgetMixin on StatelessWidget {
  String initial(String name) =>
      name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();

  String greeting() {
    final hour = DateTime.now().hour;

    if (hour >= 5 && hour < 12) return 'Bom dia';
    if (hour >= 12 && hour < 18) return 'Boa tarde';
    if (hour >= 18) return 'Boa noite';

    return 'Isso são horas?';
  }
}
