# Supabase Backend

This directory is the source of truth for the Cordato Supabase configuration
and database schema. Apply schema changes only through a new ordered migration;
do not edit an applied migration or use the Supabase dashboard as the source of
truth.

## Schema Inventory

The initial migration versions the boundaries used by the current mobile app:

- `auth.users` is managed by Supabase Auth and is the identity source.
- `profiles` mirrors the authenticated user's email and display name through an
  `auth.users` trigger. Existing users are backfilled by migration and financial
  RPCs restore a missing actor profile before creating a record. It is readable
  only by its owner.
- `expenses` stores a user's individual expenses.
- `budgets` stores a user's individual budget periods.

`push_tokens` appears in a legacy Flutter enum but has no current reader or
writer, so it is intentionally not provisioned. Storage is enabled locally, but
the app currently has no bucket requirement. Family views, insights, and Edge
Functions are outside this baseline.

All financial ownership is derived from `auth.uid()` in authenticated RPCs. The
client cannot provide or reassign an owner identifier, and it has no direct
table write grant. Every table has RLS enabled. The budget exclusion constraint
prevents inclusive date ranges from overlapping for one owner, while allowing
matching ranges for different owners. All current budget rows are live because
the mobile contract does not yet include a budget status. Expenses deliberately
have no budget foreign key.

The financial mutation RPCs are `create_expense`, `update_expense`,
`delete_expense`, `create_budget`, `update_budget`, and `delete_budget`.
Their parameters describe only the record being changed; ownership always comes
from the authenticated actor. Family RPCs are intentionally absent until the
family context exists.

## Local Setup

Prerequisites: Docker Desktop and the [Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started).

```bash
supabase start
supabase db reset
supabase migration list --local
supabase db lint --local
supabase test db
```

`supabase db reset` recreates the local database and applies all migrations in
timestamp order. Run it after changing any file in `supabase/migrations/`.
`supabase migration list` confirms the local migration history, and
`supabase db lint` checks the resulting database for schema issues.
`supabase test db` runs the structural, authorization, invariant, and
concurrency verification in `supabase/tests/`. Always run the tests after a
clean reset so they exercise the tracked migrations rather than a shared or
remote database:

```bash
supabase db reset
supabase test db
```

The authorization tests create local `auth.users` fixtures and impersonate
their decoded JWT claims under the database `authenticated` and `anon` roles.
They never read runtime Flutter configuration, production settings, or remote
credentials. The budget concurrency test opens two local database sessions with
the test-only `dblink` extension and verifies that the exclusion constraint
allows only one conflicting write to commit. Use the local Studio URL shown by
`supabase status` to
inspect tables, policies, triggers, extensions, and Storage without dashboard
edits.

To run Flutter against the local project, obtain the local API URL and
publishable key with `supabase status` and pass them at runtime:

```bash
flutter run \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...
```

The local auth configuration accepts the app's current callback URL,
`trocado://authentication/callback`. This is the existing app default; changing
it requires updating both `supabase/config.toml` and the authentication module.

## Remote Changes

Linking to a hosted Supabase project is an explicit local operation. Before
reconciling an existing remote, back it up and inspect its migration history:

```bash
supabase link --project-ref "$SUPABASE_PROJECT_REF"
supabase migration list --linked
supabase db pull
```

Review the generated migration before committing it. Do not run `db push` or
apply a new migration to a shared environment until the clean local reset and
validation commands above succeed.

## Secrets

Do not commit or put these values in Flutter build configuration:

- `SUPABASE_ACCESS_TOKEN`
- database connection strings or passwords
- `service_role` keys
- SMTP credentials
- Edge Function provider keys

`SUPABASE_URL` and the publishable/anon client key are runtime configuration,
not database schema secrets. Keep developer-specific values in ignored local
environment files. Set Edge Function secrets only with `supabase secrets set`.
