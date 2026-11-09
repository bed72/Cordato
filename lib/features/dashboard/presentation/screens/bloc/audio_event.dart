sealed class const AudioEvent();

final class const AudioStarted() extends AudioEvent;

final class const AudioObserved(final int operation) extends AudioEvent;

final class const AudioSubmitted() extends AudioEvent;

final class const AudioCancelled({final bool lifecycle = false})
    extends AudioEvent;

final class const AudioCollapsed(final int operation) extends AudioEvent;
