import 'package:material_ui/material_ui.dart';

final class AutocompleteTextController(super.value)
    extends TextEditingController {
  this : super.fromValue();

  void refreshOptions() => notifyListeners();
}
