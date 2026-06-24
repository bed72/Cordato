from abc import ABC, abstractmethod
from datetime import datetime


class ClockInterface(ABC):
    """Shared-kernel port for reading the current time.

    Why it exists: the pure domain must never call ``datetime.now()`` directly — that would make
    entities non-deterministic and untestable. Instead, a use case obtains the moment from this port
    and passes it into the entity factory (e.g. as ``created_at``). Tests inject a fixed-clock fake so
    timestamps are reproducible; production injects an adapter backed by the real wall clock.

    Implementors (adapters in ``core/infrastructure/gateways/``):
        - MUST return a timezone-aware ``datetime`` (never naive). UTC is the project default.
        - MUST be cheap and side-effect free beyond reading the clock.

    Callers (use cases):
        - Depend on this abstraction, never on a concrete clock.
        - ``await`` it once per operation and reuse the value for every timestamp in that unit of work.
    """

    @abstractmethod
    async def now(self) -> datetime:
        """Return the current instant as a timezone-aware ``datetime``.

        Returns:
            A timezone-aware ``datetime`` (its ``tzinfo`` is set, by convention UTC). Never a naive
            timestamp — a naive value would silently drop the offset downstream.
        """
        raise NotImplementedError
