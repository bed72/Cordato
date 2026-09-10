begin;

select plan(1);

do $$
begin
  if to_regclass('public.profiles') is null
    or to_regclass('public.expenses') is null
    or to_regclass('public.budgets') is null then
    raise exception 'The application tables were not provisioned';
  end if;

  if (
    select count(*)
    from pg_extension
    where extname in ('btree_gist', 'pgcrypto')
  ) <> 2 then
    raise exception 'Required extensions were not provisioned';
  end if;

  if exists (
    select 1
    from pg_class
    join pg_namespace on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'public'
      and pg_class.relname in ('profiles', 'expenses', 'budgets')
      and not pg_class.relrowsecurity
  ) then
    raise exception 'RLS is disabled on an application table';
  end if;

  if (
    select count(*)
    from pg_policy
    join pg_class on pg_class.oid = pg_policy.polrelid
    join pg_namespace on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'public'
      and pg_class.relname in ('profiles', 'expenses', 'budgets')
  ) <> 9 then
    raise exception 'Expected owner policies are missing';
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'budgets_user_date_range_exclusion'
      and contype = 'x'
  ) then
    raise exception 'Budget overlap exclusion constraint is missing';
  end if;

  if not exists (
    select 1
    from pg_trigger
    where tgname = 'auth_users_sync_profile'
      and not tgisinternal
  ) then
    raise exception 'Auth profile synchronization trigger is missing';
  end if;

  if not has_table_privilege('authenticated', 'public.expenses', 'select')
    or has_table_privilege('anon', 'public.expenses', 'select') then
    raise exception 'Table read grants do not match the protected client boundary';
  end if;
end;
$$;

select pass('initial application schema is provisioned with protected boundaries');
select * from finish();

rollback;
