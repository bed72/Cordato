from abc import ABC, abstractmethod


class IdentifierProviderInterface(ABC):
    """Shared-kernel port for minting identities for new entities.

    Why it exists: the pure domain must never call ``uuid`` (or any id generator) directly — that
    would make entities non-deterministic and untestable. A use case asks this port for an id and
    passes it into the entity factory (e.g. as ``PersonEntity.create(id=...)``). Tests inject a fake
    returning a known value so the assigned id is predictable; production injects a UUIDv7-backed
    adapter.

    The id is treated as an **opaque string** — the domain never parses, orders, or derives meaning
    from it. Time-ordering is an adapter implementation detail (UUIDv7) chosen for index locality once
    persistence lands, not a contract the domain relies on.

    Implementors (adapters in ``core/infrastructure/gateways/``):
        - MUST return a fresh, non-empty, globally-unique string on every call.
        - SHOULD produce time-ordered ids (e.g. UUIDv7) so the eventual primary key indexes well.

    Callers (use cases):
        - Depend on this abstraction, never on a concrete generator.
        - ``await`` one id per entity being created.
    """

    @abstractmethod
    async def generate(self) -> str:
        """Return a fresh, globally-unique, opaque identifier.

        Returns:
            A non-empty ``str`` that is unique across all calls. Opaque by contract — callers store
            and compare it but never inspect its internal structure.
        """
        raise NotImplementedError
