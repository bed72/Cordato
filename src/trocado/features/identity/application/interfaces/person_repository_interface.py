from abc import ABC, abstractmethod

from trocado.features.identity.domain.entities.person_entity import PersonEntity
from trocado.features.identity.domain.value_objects.email_value_object import EmailValueObject


class PersonRepositoryInterface(ABC):
    """Identity port for persisting and looking up people.

    Why it exists: the use case must store and query people without knowing *where* — an in-memory dict
    today, an ORM-backed table tomorrow. This port is that seam: it speaks only in domain entities and
    value objects, never in rows or query objects, so the storage technology can change behind it
    without touching the domain or the use case. The concrete adapter lives in
    ``identity/infrastructure/repositories/``.

    Implementors (adapters):
        - MUST accept and return domain ``PersonEntity`` objects, mapping to/from their storage form
          internally (a dedicated mapper), never exposing the storage model outward.
        - MUST treat account status as their own responsibility: normal reads surface only ``active``
          people; non-active accounts are excluded unless an explicit audit method asks for them.

    Callers (use cases):
        - Depend on this abstraction, never on a concrete store.
        - Use ``find_active_by_email`` for the uniqueness check before creating a person.
    """

    @abstractmethod
    async def find_active_by_email(self, email: EmailValueObject) -> PersonEntity | None:
        """Look up the **active** person holding a given email.

        Args:
            email: The normalized email to match (the value object guarantees it is already trimmed and
                lowercased).

        Returns:
            The active ``PersonEntity`` holding this email, or ``None`` if no active person does.
            Deliberately ignores non-active accounts — a deleted account's freed email reads as
            available, so the same email can be reused by a brand-new person.
        """
        raise NotImplementedError

    @abstractmethod
    async def create(self, person: PersonEntity) -> None:
        """Persist a newly created person.

        Args:
            person: The fully-formed ``PersonEntity`` to store (already assigned its ``id``,
                ``created_at``, and ``active`` status by the creation factory).
        """
        raise NotImplementedError
