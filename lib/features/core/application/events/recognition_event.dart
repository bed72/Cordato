sealed class const RecognitionEvent();

final class const RecognitionText({
  required final String text,
  required final bool isFinal,
}) extends RecognitionEvent;

final class const RecognitionEnded() extends RecognitionEvent;

final class const RecognitionListening() extends RecognitionEvent;

final class const RecognitionLevel(final double level) extends RecognitionEvent;
