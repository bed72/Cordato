-- The person record: identity's anchor entity. Columns use plain `varchar` so the DDL
-- stays dialect-portable (standard SQL, indexable everywhere — unlike PostgreSQL `text`,
-- which the jOOQ DDLDatabase codegen cannot index during its H2 simulation) and a future
-- engine swap stays cheap.
--
-- id     opaque identifier produced by the core id generator (stored as text, never a uuid column)
-- email  normalized address; UNIQUE enforces uniqueness at the datastore, closing the signup race
-- hash   irreversible password hash, never the plaintext
-- name   display name
-- status person lifecycle state (ACTIVE / DELETED) persisted as text
create table person (
    id     varchar not null,
    email  varchar not null,
    hash   varchar not null,
    name   varchar not null,
    status varchar not null,
    constraint person_pkey primary key (id),
    constraint person_email_key unique (email)
);
