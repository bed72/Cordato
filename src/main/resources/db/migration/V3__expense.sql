-- The expense record: the atomic spend fact — who spent, how much, when. The base truth every derived
-- budget/couple number is later computed from. Mirrors the person/session tables' conventions: `varchar`
-- identifiers so the DDL stays dialect-portable and indexable under the jOOQ DDLDatabase (H2) codegen
-- simulation, and `date` for the calendar day the spend happened (standard SQL, parsed by both H2 and
-- PostgreSQL).
--
-- id           opaque identifier produced by the core id generator (stored as text, never a uuid column)
-- person_id    the person who owns this spend (identity's anchor id); no cross-table FK, matching V1/V2's
--              style — the owner always comes from a live authenticated session, so a person exists
-- amount_cents the exact amount as an integer number of cents (bigint), never floating point
-- spent_on     the calendar day the spend actually happened (may be today or past, never future)
-- description  optional free text; nullable — an absent description is a valid expense
--
-- Deliberately NO column referencing a budget: an expense records only the raw fact, and "which budget does
-- it belong to?" is answered at read time by comparing spent_on to a budget's date range (derive-don't-store).
create table expense (
    id           varchar not null,
    person_id    varchar not null,
    amount_cents bigint  not null,
    spent_on     date    not null,
    description  varchar,
    constraint expense_pkey primary key (id)
);

-- Index by owner (and by the spend day) to serve budget's future by-person, by-date-range queries; cheap on
-- write, and it anticipates the date-range consumption expense is the base truth for.
create index expense_person_id_spent_on_idx on expense (person_id, spent_on);
