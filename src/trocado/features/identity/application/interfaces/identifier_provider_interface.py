from abc import ABC, abstractmethod


class IdentifierProviderInterface(ABC):
    """Port that supplies opaque identifiers for new entities."""

    @abstractmethod
    async def generate(self) -> str:
        """Return a fresh, globally-unique identifier."""
        raise NotImplementedError
