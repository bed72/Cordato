sealed class const RecordingEvent();

final class const RecordingEnded() extends RecordingEvent;

final class const RecordingListening() extends RecordingEvent;

final class const RecordingLevel(final double level) extends RecordingEvent;
