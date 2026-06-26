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
    password: str  # the hash; a plain string needs no value object — it carries no invariant
    status: PersonStatus  # no default: only `create(...)` may birth an ACTIVE person; rehydration states it
    created_at: datetime
    name: NameValueObject
    email: EmailValueObject

    @classmethod
    def create(
        cls,
        *,
        id: str,
        password: str,
        created_at: datetime,
        name: NameValueObject,
        email: EmailValueObject,
    ) -> PersonEntity:
        """Create a brand-new, active person — the only sanctioned way to be born."""
        return cls(
            id=id,
            name=name,
            email=email,
            password=password,
            created_at=created_at,
            status=PersonStatus.ACTIVE,
        )

    def update_account(self, *, name: NameValueObject, email: EmailValueObject) -> None:
        """Update the editable account fields — `name` and `email` — in place.

        A full replacement of the two editable fields with already-validated value objects. Identity and
        credentials are untouched: `id`, `created_at`, `status`, and the password `hash` are preserved.
        This is the only sanctioned account mutation, alongside `create` (birth) and `delete` (retire).
        """
        self.name = name
        self.email = email

    def update_password(self, new_hash: str) -> None:
        """Rotate the credential: overwrite the stored password hash in place.

        Takes an already-computed hash (a plain `str` — a hash carries no invariant, so no value object;
        hashing is the gateway's job, done in the use case). Identity and account state are untouched:
        `id`, `created_at`, `status`, `name`, and `email` are preserved. A sanctioned transition alongside
        `create` (birth), `update_account` (edit), and `delete` (retire).
        """
        self.password = new_hash

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
