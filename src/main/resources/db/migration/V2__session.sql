-- The session record: core's first persisted aggregate, the anchor of an authenticated request.
-- Mirrors the person table's conventions: `varchar` identifiers so the DDL stays dialect-portable
-- and indexable under the jOOQ DDLDatabase (H2) codegen simulation, timestamps as
-- `timestamp with time zone` (standard SQL, parsed by both H2 and PostgreSQL) so they map to a
-- java.time type carrying an instant.
--
-- id          opaque identifier produced by the core id generator (stored as text, never a uuid column)
-- person_id   the person this session was opened for (identity's anchor id)
-- hash_token  SHA-256 of the opaque token; UNIQUE gives the lookup index and never stores the plaintext
-- expires_at  instant the session stops being live; findActiveByToken compares against it
-- created_at  instant the session was opened
create table session (
    id         varchar not null,
    person_id  varchar not null,
    hash_token varchar not null,
    expires_at timestamp with time zone not null,
    created_at timestamp with time zone not null,
    constraint session_pkey primary key (id),
    constraint session_hash_token_key unique (hash_token)
);
