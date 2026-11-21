import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/user/domain/entities/user_entity.dart';

import 'package:cordato/features/user/presentation/screens/user/bloc/user_event.dart';
import 'package:cordato/features/user/presentation/screens/user/bloc/user_state.dart';

import 'package:cordato/features/user/application/exceptions/user_exception.dart';
import 'package:cordato/features/user/application/repositories/interface_user_repository.dart';

final class UserBloc({required final IUserRepository repository})
    extends Bloc<UserEvent, UserState> {
  this : super(const UserInitial()) {
    on<UserEvent>(_execute, transformer: droppable());
  }

  Future<void> _execute(UserEvent event, Emitter<UserState> emit) async {
    final user = state.user;
    if (!state.canLoad) return;
    if (event is UserAvatarSubmittedEvent && user == null) return;

    try {
      switch (event) {
        case UserRequestedEvent():
          emit(const UserLoading());

          final data = await repository.get();
          if (isClosed || emit.isDone) return;

          emit(UserReady(data: data));
        case UserAvatarSubmittedEvent(:final seed):
          emit(UserAvatarSaving(data: user!));

          final data = await repository.update(avatar: seed);
          if (isClosed || emit.isDone) return;

          if (data.avatar != seed) {
            emit(UserAvatarFailure(data: user, errors: .unknown()));
            return;
          }

          emit(UserAvatarSuccess(data: data));
      }
    } on UserException catch (error) {
      _fail(event, user, error.errors, emit);
    } catch (error, stackTrace) {
      if (isClosed || emit.isDone) return;

      addError(error, stackTrace);

      _fail(event, user, .unknown(), emit);
    }
  }

  void _fail(
    UserEvent event,
    UserEntity? user,
    ErrorsEntity errors,
    Emitter<UserState> emit,
  ) {
    if (isClosed || emit.isDone) return;

    emit(switch (event) {
      UserRequestedEvent() => UserFailure(errors: errors),
      UserAvatarSubmittedEvent() => UserAvatarFailure(
        data: user!,
        errors: errors,
      ),
    });
  }
}
