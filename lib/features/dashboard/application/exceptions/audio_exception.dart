import 'package:cordato/features/dashboard/application/enums/audio_failure_enum.dart';

final class const AudioException(final AudioFailureEnum failure)
    implements Exception;
