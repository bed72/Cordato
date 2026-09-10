create extension if not exists btree_gist with schema extensions;
create extension if not exists pgcrypto with schema extensions;

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text,
  display_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_email_unique unique (email)
);

create table public.expenses (
  id uuid primary key default extensions.gen_random_uuid(),
  user_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  amount bigint not null,
  description text not null,
  date date not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint expenses_amount_range check (amount between 1 and 9999999999999),
  constraint expenses_description_valid check (
    description = btrim(description)
    and char_length(description) between 2 and 128
  )
);

create table public.budgets (
  id uuid primary key default extensions.gen_random_uuid(),
  user_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  amount bigint not null,
  description text,
  start_date date not null,
  end_date date not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint budgets_amount_range check (amount between 1 and 9999999999999),
  constraint budgets_date_range_valid check (start_date <= end_date),
  constraint budgets_description_valid check (
    description is null
    or (
      description = btrim(description)
      and char_length(description) between 2 and 256
    )
  ),
  constraint budgets_user_date_range_exclusion exclude using gist (
    user_id with =,
    daterange(start_date, end_date, '[]') with &&
  )
);

create index expenses_user_id_date_idx on public.expenses (user_id, date desc);
create index budgets_user_id_start_date_idx on public.budgets (user_id, start_date desc);

create function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create function public.sync_profile_from_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, email, display_name)
  values (
    new.id,
    new.email,
    coalesce(
      new.raw_user_meta_data ->> 'name',
      new.raw_user_meta_data ->> 'full_name',
      new.raw_user_meta_data ->> 'display_name'
    )
  )
  on conflict (id) do update
  set
    email = excluded.email,
    display_name = excluded.display_name;

  return new;
end;
$$;

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create trigger expenses_set_updated_at
before update on public.expenses
for each row execute function public.set_updated_at();

create trigger budgets_set_updated_at
before update on public.budgets
for each row execute function public.set_updated_at();

create trigger auth_users_sync_profile
after insert or update of email, raw_user_meta_data on auth.users
for each row execute function public.sync_profile_from_auth_user();

alter table public.profiles enable row level security;
alter table public.expenses enable row level security;
alter table public.budgets enable row level security;

create policy profiles_select_own
on public.profiles
for select
to authenticated
using (id = (select auth.uid()));

create policy expenses_select_own
on public.expenses
for select
to authenticated
using (user_id = (select auth.uid()));

create policy expenses_insert_own
on public.expenses
for insert
to authenticated
with check (user_id = (select auth.uid()));

create policy expenses_update_own
on public.expenses
for update
to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

create policy expenses_delete_own
on public.expenses
for delete
to authenticated
using (user_id = (select auth.uid()));

create policy budgets_select_own
on public.budgets
for select
to authenticated
using (user_id = (select auth.uid()));

create policy budgets_insert_own
on public.budgets
for insert
to authenticated
with check (user_id = (select auth.uid()));

create policy budgets_update_own
on public.budgets
for update
to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

create policy budgets_delete_own
on public.budgets
for delete
to authenticated
using (user_id = (select auth.uid()));

revoke all on table public.profiles from anon, public;
revoke all on table public.expenses from anon, public;
revoke all on table public.budgets from anon, public;

grant usage on schema public to authenticated;
grant select on table public.profiles to authenticated;
grant select, insert, update, delete on table public.expenses to authenticated;
grant select, insert, update, delete on table public.budgets to authenticated;

revoke all on function public.set_updated_at() from public;
revoke all on function public.sync_profile_from_auth_user() from public;
