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

    def update_name(self, name: NameValueObject) -> None:
        """Update the display `name` in place — a plain profile edit.

        Overwrites only `name` with an already-validated value object; everything else — `id`, `created_at`,
        `status`, `email`, and the password `hash` — is preserved. A sanctioned account mutation alongside
        `create` (birth), `update_email` (re-identify), `update_password` (rotate), and `delete` (retire).
        """
        self.name = name

    def update_email(self, email: EmailValueObject) -> None:
        """Update the `email` (the login identifier) in place — a credential-sensitive re-identification.

        Overwrites only `email` with an already-validated, normalized value object; `id`, `created_at`,
        `status`, `name`, and the password `hash` are preserved. The current-password re-confirmation and the
        other-session purge that guard this change live in the use case, not the entity. A sanctioned account
        mutation alongside `create` (birth), `update_name` (edit), `update_password` (rotate), and `delete`
        (retire).
        """
        self.email = email

    def update_password(self, password: str) -> None:
        """Rotate the credential: overwrite the stored password hash in place.

        Takes an already-computed hash (a plain `str` — a hash carries no invariant, so no value object;
        hashing is the gateway's job, done in the use case). Identity and account state are untouched:
        `id`, `created_at`, `status`, `name`, and `email` are preserved. A sanctioned transition alongside
        `create` (birth), `update_name`/`update_email` (edit), and `delete` (retire).
        """
        self.password = password

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
