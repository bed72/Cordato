from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime

from trocado.features.identity.domain.enums.person_status import PersonStatus
from trocado.features.identity.domain.value_objects.email_value_object import EmailValueObject
from trocado.features.identity.domain.value_objects.name_value_object import NameValueObject


@dataclass(eq=False, slots=True)
class PersonEntity:
    """A person — the ledger's anchor. Identity is the `id`; everything else hangs off it."""

    id: str
    created_at: datetime
    email: EmailValueObject
    name: NameValueObject
    password: str  # the hash; a plain string needs no value object — it carries no invariant
    status: PersonStatus  # no default: only `create(...)` may birth an ACTIVE person; rehydration states it

    @classmethod
    def create(
        cls,
        *,
        id: str,
        created_at: datetime,
        email: EmailValueObject,
        name: NameValueObject,
        password: str,
    ) -> PersonEntity:
        """Create a brand-new, active person — the only sanctioned way to be born."""
        return cls(
            id=id,
            name=name,
            email=email,
            created_at=created_at,
            password=password,
            status=PersonStatus.ACTIVE,
        )

    # Identity equality: a person IS its id, not the sum of its fields.
    def __eq__(self, other: object) -> bool:
        return isinstance(other, PersonEntity) and other.id == self.id

    def __hash__(self) -> int:
        return hash(self.id)
