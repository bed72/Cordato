create function public.create_expense(
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

  insert into public.expenses (user_id, amount, description, date)
  values (actor_id, p_amount, p_description, p_date)
  returning id into expense_id;

  return expense_id;
end;
$$;

create function public.update_expense(
  p_id uuid,
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

  update public.expenses
  set amount = p_amount, description = p_description, date = p_date
  where id = p_id and user_id = actor_id
  returning id into expense_id;

  if expense_id is null then
    raise exception 'Expense not found' using errcode = 'P0002';
  end if;

  return expense_id;
end;
$$;

create function public.delete_expense(p_id uuid)
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

  delete from public.expenses
  where id = p_id and user_id = actor_id
  returning id into expense_id;

  if expense_id is null then
    raise exception 'Expense not found' using errcode = 'P0002';
  end if;

  return expense_id;
end;
$$;

create function public.create_budget(
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

create function public.update_budget(
  p_id uuid,
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

  update public.budgets
  set
    amount = p_amount,
    description = p_description,
    start_date = p_start_date,
    end_date = p_end_date
  where id = p_id and user_id = actor_id
  returning id into budget_id;

  if budget_id is null then
    raise exception 'Budget not found' using errcode = 'P0002';
  end if;

  return budget_id;
end;
$$;

create function public.delete_budget(p_id uuid)
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

  delete from public.budgets
  where id = p_id and user_id = actor_id
  returning id into budget_id;

  if budget_id is null then
    raise exception 'Budget not found' using errcode = 'P0002';
  end if;

  return budget_id;
end;
$$;

revoke insert, update, delete on table public.expenses from authenticated;
revoke insert, update, delete on table public.budgets from authenticated;

revoke all on function public.create_expense(bigint, text, date) from public;
revoke all on function public.update_expense(uuid, bigint, text, date) from public;
revoke all on function public.delete_expense(uuid) from public;
revoke all on function public.create_budget(bigint, text, date, date) from public;
revoke all on function public.update_budget(uuid, bigint, text, date, date) from public;
revoke all on function public.delete_budget(uuid) from public;

grant execute on function public.create_expense(bigint, text, date) to authenticated;
grant execute on function public.update_expense(uuid, bigint, text, date) to authenticated;
grant execute on function public.delete_expense(uuid) to authenticated;
grant execute on function public.create_budget(bigint, text, date, date) to authenticated;
grant execute on function public.update_budget(uuid, bigint, text, date, date) to authenticated;
grant execute on function public.delete_budget(uuid) to authenticated;
