from abc import ABC, abstractmethod

from trocado.features.identity.domain.value_objects.password_value_object import PasswordValueObject


class PasswordHasherInterface(ABC):
    """Identity port for turning a raw password into a storable hash.

    Why it exists: a password is never persisted in plaintext (a non-negotiable security rule), and the
    domain must not know *which* algorithm hashes it. This port is the seam: the use case hands it a
    validated ``PasswordValueObject`` and stores the returned hash on the ``PersonEntity``; the concrete
    algorithm (Argon2 today) lives entirely inside an infrastructure adapter and can change without
    touching the domain or the use case. Lives in ``identity`` — not the ``core`` kernel — because
    password hashing is an authentication concern, not a capability every context needs.

    Implementors (adapters in ``identity/infrastructure/gateways/``):
        - MUST use a strong, salted password-hashing algorithm (e.g. Argon2/bcrypt) and return its
          self-describing hash string (salt + parameters embedded).
        - MUST run any CPU-bound, synchronous hashing call off the event loop (``asyncio.to_thread``)
          so it never blocks other awaits.
        - MUST NOT log, echo, or otherwise leak the plaintext.

    Callers (use cases):
        - Pass the transient ``PasswordValueObject`` straight from input; never the raw ``str``.
        - Store only the returned hash — the plaintext is discarded after this call.
    """

    @abstractmethod
    async def hash(self, password: PasswordValueObject) -> str:
        """Hash a raw password and return the value to persist.

        Args:
            password: The validated, transient plaintext password. Its plaintext is consumed here and
                never persisted.

        Returns:
            The hash string to store on the entity — a self-describing digest (algorithm, parameters,
            and salt embedded), never the plaintext.
        """
        raise NotImplementedError

    @abstractmethod
    async def verify(self, password: PasswordValueObject, hash: str) -> bool:
        """Check a raw password against a stored hash.

        Used to re-confirm identity before a guarded action (e.g. account deletion). Implementors MUST
        compare in constant time (the algorithm's own verify), run the CPU-bound call off the event loop,
        and never log or echo the plaintext.

        Args:
            password: The validated, transient plaintext password supplied for re-confirmation.
            hash: The stored, self-describing digest to verify against.

        Returns:
            ``True`` if the password matches the hash, ``False`` otherwise. A mismatch is a ``False``
            return, never an exception — the caller decides how to frame it.
        """
        raise NotImplementedError
