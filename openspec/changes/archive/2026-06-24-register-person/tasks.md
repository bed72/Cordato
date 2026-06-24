## 1. Module skeleton & dependency

- [x] 1.1 Create the package root `src/trocado/__init__.py` and `src/trocado/features/__init__.py`
- [x] 1.2 Create `src/trocado/features/identity/` with `domain/`, `application/`, `infrastructure/` and the
      sub-package `__init__.py` files following the canonical layer structure
- [x] 1.3 Configure packaging so `src/trocado` is importable (build/hatch settings or `tool.uv`/`tool.pytest`
      `pythonpath` as appropriate) and `uv run pytest` can import `trocado`
- [x] 1.4 Add the runtime dependency: `uv add argon2-cffi`

## 2. Domain (pure, synchronous)

- [x] 2.1 `domain/value_objects/person_status.py` → `PersonStatus` enum (`active` / `deleted`) in its own file
- [x] 2.2 `domain/value_objects/email_value_object.py` → `EmailValueObject` (validate format, normalize: trim +
      lowercase)
- [x] 2.3 `domain/value_objects/name_value_object.py` → `NameValueObject` (trim, reject blank)
- [x] 2.4 `domain/value_objects/password_value_object.py` → `PasswordValueObject` (raw plaintext, policy ≥ 8
      chars; transient, never persisted)
- [x] 2.5 (removed) The stored hash is a plain `str`, not a value object — wrapping a bare primitive that carries
      no invariant is over-engineering. See the convention added to CLAUDE.md.
- [x] 2.6 `domain/errors/` → one error per file: `InvalidEmailError`, `InvalidNameError`, `WeakPasswordError`,
      `EmailAlreadyInUseError`
- [x] 2.7 `domain/entities/person_entity.py` → `PersonEntity` with a pure `create(...)` factory (assigns id,
      created_at, status=active; holds email/name value objects + a `password: str` hash field;
      imports `PersonStatus`)
- [x] 2.8 Unit tests for every value object and the entity factory (happy paths + each validation error)

## 3. Application (async ports, use case, data, mapper)

- [x] 3.1 `application/interfaces/person_repository_interface.py` → `PersonRepositoryInterface` (abc.ABC):
      `async def find_active_by_email(email) -> PersonEntity | None`, `async def create(person) -> None`
- [x] 3.2 `application/interfaces/password_hasher_interface.py` → `PasswordHasherInterface` (abc.ABC):
      `async def hash(password: PasswordValueObject) -> str`
- [x] 3.3 `application/interfaces/identifier_provider_interface.py` → `IdentifierProviderInterface` (abc.ABC):
      `async def generate() -> str`
- [x] 3.4 `application/interfaces/clock_interface.py` → `ClockInterface` (abc.ABC): `async def now() -> datetime`
- [x] 3.5 `application/data/create_person_data.py` → `CreatePersonData` (name, email, password)
- [x] 3.6 `application/data/person_data.py` → `PersonData` (id, name, email, status, created_at — no password)
- [x] 3.7 `application/mappers/person_data_mapper.py` → `PersonDataMapper` (PersonEntity → PersonData)
- [x] 3.8 `application/use_cases/create_person_use_case.py` → `CreatePersonUseCase` (async): build value
      objects → `find_active_by_email` uniqueness check → hash password → get id+now from ports →
      `PersonEntity.create` → `repository.create` → return `PersonData`
- [x] 3.9 Unit tests for the use case covering every spec scenario (success, duplicate active email, malformed
      email, normalization, weak password, blank name, freed-email reuse), using fakes/in-memory doubles

## 4. Infrastructure (adapters)

- [x] 4.1 `infrastructure/repositories/person_repository.py` → `PersonRepository` (in-memory dict adapter
      implementing the port; `find_active_by_email` returns only active persons)
- [x] 4.2 `infrastructure/gateways/password_hasher.py` → `PasswordHasher` (Argon2 via argon2-cffi; wrap the sync
      hash call with `asyncio.to_thread` at the adapter edge — no lib name in the class)
- [x] 4.3 `infrastructure/gateways/` → `IdentifierProvider` (`uuid.uuid7()`, time-ordered, stdlib 3.14;
      returns `str`) and `Clock` (timezone-aware `now`) adapters
- [x] 4.4 Integration-style test wiring the real `PersonRepository` + Argon2 `PasswordHasher` through
      `CreatePersonUseCase` for a successful registration and a duplicate-email rejection

## 5. Verify

- [x] 5.1 Run the full gate: `uv run poe check` (format-check, lint, mypy strict, pytest) — all green
- [x] 5.2 Run `/trocado:guard` over the diff and confirm PASS (async ports, dependency direction, naming, no lib
      names, dedicated mappers, password never plaintext, per-person scope)
