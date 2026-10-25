import 'package:bloc/bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

extension BlocScopedExtension on Scoped {
  void addBloc<B extends BlocBase<Object?>>(Function constructor) =>
      addStreamable<B>(
        constructor,
        (bloc) => bloc.stream,
        (bloc) => bloc.close(),
      );
}
