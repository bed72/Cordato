import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/session/presentation/bloc/session_bloc.dart';

final sessionModule = createModule(
  register: (context) => context.add<SessionBloc>(SessionBloc.new),
);
