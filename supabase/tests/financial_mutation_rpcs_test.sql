begin;

select plan(1);

do $$
begin
  if (
    select count(*)
    from pg_proc
    join pg_namespace on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname in (
        'create_expense',
        'update_expense',
        'delete_expense',
        'create_budget',
        'update_budget',
        'delete_budget'
      )
      and pg_proc.prosecdef
  ) <> 6 then
    raise exception 'Expected financial mutation RPCs are missing or unprotected';
  end if;

  if not has_function_privilege(
    'authenticated',
    'public.create_expense(bigint, text, date)',
    'execute'
  ) or not has_function_privilege(
    'authenticated',
    'public.update_expense(uuid, bigint, text, date)',
    'execute'
  ) or not has_function_privilege(
    'authenticated',
    'public.delete_expense(uuid)',
    'execute'
  ) or not has_function_privilege(
    'authenticated',
    'public.create_budget(bigint, text, date, date)',
    'execute'
  ) or not has_function_privilege(
    'authenticated',
    'public.update_budget(uuid, bigint, text, date, date)',
    'execute'
  ) or not has_function_privilege(
    'authenticated',
    'public.delete_budget(uuid)',
    'execute'
  ) then
    raise exception 'Authenticated callers cannot execute every financial RPC';
  end if;

  if has_table_privilege('authenticated', 'public.expenses', 'insert')
    or has_table_privilege('authenticated', 'public.expenses', 'update')
    or has_table_privilege('authenticated', 'public.expenses', 'delete')
    or has_table_privilege('authenticated', 'public.budgets', 'insert')
    or has_table_privilege('authenticated', 'public.budgets', 'update')
    or has_table_privilege('authenticated', 'public.budgets', 'delete') then
    raise exception 'Authenticated callers retain direct financial table writes';
  end if;
end;
$$;

select pass('financial mutations are available only through protected RPCs');
select * from finish();

rollback;
