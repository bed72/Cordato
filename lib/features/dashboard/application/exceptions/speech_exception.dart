import 'package:cordato/features/dashboard/application/enums/speech_failure_enum.dart';

final class const SpeechException(final SpeechFailureEnum failure)
    implements Exception;
