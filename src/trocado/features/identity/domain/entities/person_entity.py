from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime

from trocado.features.identity.domain.enums.person_status import PersonStatus
from trocado.features.identity.domain.value_objects.email_value_object import EmailValueObject
from trocado.features.identity.domain.value_objects.name_value_object import NameValueObject

# Reserved (RFC 2606) domain for neutralized emails: a deleted account's address can never collide with
# a real one nor route anywhere, yet still parses as a valid email.
DELETED_EMAIL_DOMAIN = "trocado.invalid"


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

    def delete(self) -> None:
        """Retire the account: the only transition into `DELETED`.

        Flips `status` to `DELETED` (the account no longer authenticates) and neutralizes the email to a
        collision-free sentinel derived from the id — freeing the original address for reuse, since reads
        surface only active accounts. The id is opaque and `@`/whitespace-free, so the sentinel always
        parses as a valid email. No data is moved here; the ledger cascade lives in the use case.
        """
        self.status = PersonStatus.DELETED
        self.email = EmailValueObject(f"deleted+{self.id}@{DELETED_EMAIL_DOMAIN}")

    # Identity equality: a person IS its id, not the sum of its fields.
    def __eq__(self, other: object) -> bool:
        return isinstance(other, PersonEntity) and other.id == self.id

    def __hash__(self) -> int:
        return hash(self.id)
