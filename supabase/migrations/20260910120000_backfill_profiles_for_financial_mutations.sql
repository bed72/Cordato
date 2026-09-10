insert into public.profiles (id, email, display_name)
select
  id,
  email,
  coalesce(
    raw_user_meta_data ->> 'name',
    raw_user_meta_data ->> 'full_name',
    raw_user_meta_data ->> 'display_name'
  )
from auth.users
on conflict (id) do nothing;

create or replace function public.create_expense(
  p_amount bigint,
  p_description text,
  p_date date
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  expense_id uuid;
begin
  if actor_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  insert into public.profiles (id)
  values (actor_id)
  on conflict (id) do nothing;

  insert into public.expenses (user_id, amount, description, date)
  values (actor_id, p_amount, p_description, p_date)
  returning id into expense_id;

  return expense_id;
end;
$$;

create or replace function public.create_budget(
  p_amount bigint,
  p_description text,
  p_start_date date,
  p_end_date date
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  budget_id uuid;
begin
  if actor_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  insert into public.profiles (id)
  values (actor_id)
  on conflict (id) do nothing;

  insert into public.budgets (
    user_id,
    amount,
    description,
    start_date,
    end_date
  )
  values (
    actor_id,
    p_amount,
    p_description,
    p_start_date,
    p_end_date
  )
  returning id into budget_id;

  return budget_id;
end;
$$;
