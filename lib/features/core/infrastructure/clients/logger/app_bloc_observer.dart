import 'package:bloc/bloc.dart';
import 'package:talker/talker.dart';
import 'package:talker_bloc_logger/talker_bloc_logger.dart';

final class AppBlocObserver({required Talker talker})
    extends TalkerBlocObserver {
  this
    : super(
        talker: talker,
        settings: const TalkerBlocLoggerSettings(
          printEventFullData: false,
          printStateFullData: false,
          printCreations: true,
          printClosings: true,
        ),
      );

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) =>
      super.onError(bloc, error.runtimeType, stackTrace);
}
