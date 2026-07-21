-- The budget record: the planned ceiling per date range. Mirrors the person/session/expense tables'
-- conventions: `varchar` identifiers so the DDL stays dialect-portable and indexable under the jOOQ
-- DDLDatabase (H2) codegen simulation, and `date` for the calendar days (standard SQL, parsed by both
-- H2 and PostgreSQL).
--
-- id           opaque identifier produced by the core id generator (stored as text, never a uuid column)
-- person_id    the person who owns this budget (identity's anchor id); no cross-table FK, matching
--              V1/V2/V3's style — the owner always comes from a live authenticated session, so a
--              person exists
-- amount_cents the exact ceiling as an integer number of cents (bigint), never floating point
-- start_date   the first calendar day covered by the budget, included
-- end_date     the last calendar day covered by the budget, included; never before start_date
-- note         optional free text; nullable — an absent note is a valid budget
-- status       the budget's lifecycle state (LIVE/DELETED); only LIVE budgets compete for the
--              non-overlap invariant — needed from the first migration even though no route reaches
--              DELETED in this slice
--
-- Deliberately NO column referencing expenses: a budget records only its own ceiling, and "which
-- expenses belong to it?" is answered at read time by comparing an expense's date to this range
-- (derive-don't-store).
create table budget (
    id           varchar not null,
    person_id    varchar not null,
    amount_cents bigint  not null,
    start_date   date    not null,
    end_date     date    not null,
    note         varchar,
    status       varchar not null,
    constraint budget_pkey primary key (id)
);

-- Index by owner and status to serve the non-overlap invariant's query (find another LIVE budget of the
-- same person overlapping a given range); cheap on write.
create index budget_person_id_status_idx on budget (person_id, status);
