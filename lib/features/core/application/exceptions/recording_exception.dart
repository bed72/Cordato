import 'package:cordato/features/core/application/enums/recording_failure_enum.dart';

final class const RecordingException(final RecordingFailureEnum failure)
    implements Exception;
