## ADDED Requirements

### Requirement: The couple budget is the combined panorama of both partners' active budgets

The system SHALL return, for a reader (`reader_id`) who is in a live pair, a single combined budget view
that spans both partners' active budgets for the requested day. The view's period SHALL be
`[min(start_date), max(end_date)]` across the present active budgets, its `amount` SHALL be the **sum** of
the present active budgets' amounts, its `total_spent` SHALL be the **sum** of their spends, and its
`remaining` SHALL be `amount − total_spent`. The view is **read-only** and **derived at read-time**:
nothing is stored, copied, or owned by the pair, and forming it SHALL NOT mutate either ledger. The partner
is the *other* person of the reader's live pair (`person_b_id` when the reader is `person_a`, and vice
versa). The view is a deliberately approximate panorama — the exact figures remain in each person's own
active budget.

#### Scenario: Both partners have an active budget

- **WHEN** a reader in a live pair requests the couple budget for a day on which both partners have an
  active budget
- **THEN** the system returns a combined view whose period is `[min(start_date), max(end_date)]` of the two
  budgets, whose `amount` is the sum of the two amounts, whose `total_spent` is the sum of the two spends,
  and whose `remaining` is `amount − total_spent`

#### Scenario: The amounts and spends are summed exactly

- **WHEN** the combined view is computed from two active budgets
- **THEN** the summed `amount`, `total_spent`, and `remaining` are exact decimals, never rounded or
  approximated by floating point

### Requirement: The panorama spans only the partners who have an active budget

The system SHALL build the panorama from whichever partners have an active budget for the day. When **only
one** partner has an active budget, the view SHALL equal that partner's active budget span and figures (the
other partner contributes nothing — a missing active budget is never fabricated into a bucket). When
**neither** partner has an active budget for the day, there is no panorama and the system SHALL return
nothing (no view), exactly as the individual active-budget view is absent when there is no active budget.

#### Scenario: Only one partner has an active budget

- **WHEN** a reader in a live pair requests the couple budget for a day on which exactly one partner has an
  active budget
- **THEN** the system returns a view whose period, `amount`, `total_spent`, and `remaining` are those of
  that single partner's active budget, and the partner without one contributes nothing

#### Scenario: Neither partner has an active budget

- **WHEN** a reader in a live pair requests the couple budget for a day on which neither partner has an
  active budget
- **THEN** the system returns nothing — there is no couple budget to view

### Requirement: Only a reader in a live pair has a couple budget

The system SHALL reject the request when the reader is in no live pair (`deleted_at` null) in which they
are `person_a` or `person_b`. A dissolved (soft-deleted) pair SHALL NOT grant a view: once the lens is
gone, there is no couple to look through. The rejection SHALL carry a short pt-BR message that does not
leak any partner's data. Being in a live pair but having no active budget is **not** a rejection — it
returns nothing (the previous requirement), never the not-paired error.

#### Scenario: An unpaired reader is rejected

- **WHEN** a reader who belongs to no live pair requests the couple budget
- **THEN** the system rejects the request with a not-paired error and returns no view

#### Scenario: A dissolved pair grants no view

- **WHEN** a reader whose only pair has been dissolved (soft-deleted) requests the couple budget
- **THEN** the system rejects the request with a not-paired error and returns no view

### Requirement: Reading partner active budgets crosses no module boundary

The system SHALL read each partner's active budget through a port owned by the `pairing` context, stated in
pairing's own vocabulary, and SHALL NOT introduce any dependency from `pairing` on the `budgeting` module.
The port SHALL return the partner's active budget for the day in pairing's own terms, or nothing when that
partner has no active budget. The concrete adapter that reads the underlying budget is wired at the
composition root — the only layer permitted to know both modules.

#### Scenario: Pairing depends only on its own port

- **WHEN** the couple budget is computed
- **THEN** both partners' active budgets are obtained through pairing's own reader port, with no import of
  the budgeting feature from pairing's domain or application
