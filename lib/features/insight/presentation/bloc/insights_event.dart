sealed class InsightsEvent {
  const InsightsEvent();
}

final class const InsightsRequestedEvent({final int? year, final int? month})
    extends InsightsEvent {}
