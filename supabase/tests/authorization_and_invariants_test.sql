begin;

insert into auth.users (
  id,
  instance_id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at
)
values
  (
    '10000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'authorization-owner-a@cordato.test',
    'not-used-by-database-tests',
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"display_name":"Owner A"}',
    now(),
    now()
  ),
  (
    '20000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'authorization-owner-b@cordato.test',
    'not-used-by-database-tests',
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"display_name":"Owner B"}',
    now(),
    now()
  );

select plan(5);

do $$
declare
  owner_a_id constant uuid := '10000000-0000-0000-0000-000000000001';
  owner_b_id constant uuid := '20000000-0000-0000-0000-000000000002';
  profile_count integer;
begin
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub', owner_a_id::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', owner_a_id, 'role', 'authenticated')::text,
    true
  );

  select count(*) into profile_count
  from public.profiles
  where id = owner_a_id;

  if profile_count <> 1 then
    raise exception 'Owner A could not read its profile';
  end if;

  execute 'reset role';
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub', owner_b_id::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', owner_b_id, 'role', 'authenticated')::text,
    true
  );

  select count(*) into profile_count
  from public.profiles
  where id = owner_a_id;

  if profile_count <> 0 then
    raise exception 'Owner B can read Owner A profile';
  end if;

  execute 'reset role';
end;
$$;

select pass('profiles are readable only by the authenticated owner');

do $$
declare
  owner_b_id constant uuid := '20000000-0000-0000-0000-000000000002';
  expense_id uuid;
begin
  delete from public.profiles where id = owner_b_id;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub', owner_b_id::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', owner_b_id, 'role', 'authenticated')::text,
    true
  );

  select public.create_expense(100, 'Perfil ausente', '2026-01-14')
  into expense_id;

  if not exists (select 1 from public.profiles where id = owner_b_id) then
    raise exception 'Financial RPC did not restore the actor profile';
  end if;

  perform public.delete_expense(expense_id);
  execute 'reset role';
end;
$$;

select pass('financial RPCs restore a missing actor profile before creating records');

do $$
declare
  owner_a_id constant uuid := '10000000-0000-0000-0000-000000000001';
  owner_b_id constant uuid := '20000000-0000-0000-0000-000000000002';
  owner_a_expense_id uuid;
  owner_b_expense_id uuid;
  owner_a_amount bigint;
  owner_id uuid;
  expense_count_before_invalid_input integer;
begin
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub', owner_a_id::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', owner_a_id, 'role', 'authenticated')::text,
    true
  );

  select public.create_expense(1250, 'Mercado', '2026-01-15')
  into owner_a_expense_id;
  select public.update_expense(
    owner_a_expense_id,
    1350,
    'Mercado atualizado',
    '2026-01-16'
  ) into owner_a_expense_id;

  select count(*) into expense_count_before_invalid_input
  from public.expenses;

  begin
    perform public.create_expense(0, 'Valor invalido', '2026-01-20');
    raise exception 'Zero expense amount was accepted';
  exception
    when check_violation then null;
  end;

  begin
    execute $query$select public.create_expense(100, 'Data invalida', '2026-02-30'::date)$query$;
    raise exception 'Invalid civil date was accepted';
  exception
    when sqlstate '22007' or sqlstate '22008' then null;
  end;

  if (select count(*) from public.expenses) <> expense_count_before_invalid_input then
    raise exception 'Invalid expense input persisted a partial record';
  end if;

  execute 'reset role';
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub', owner_b_id::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', owner_b_id, 'role', 'authenticated')::text,
    true
  );

  select public.create_expense(2100, 'Transporte', '2026-01-17')
  into owner_b_expense_id;

  select user_id into owner_id
  from public.expenses
  where id = owner_b_expense_id;

  if owner_id <> owner_b_id then
    raise exception 'Expense RPC accepted an owner other than the JWT actor';
  end if;

  if exists (select 1 from public.expenses where id = owner_a_expense_id) then
    raise exception 'Owner B can read Owner A expense';
  end if;

  begin
    perform public.update_expense(
      owner_a_expense_id,
      9999,
      'Tentativa de alteracao',
      '2026-01-18'
    );
    raise exception 'Owner B updated Owner A expense';
  exception
    when no_data_found then null;
  end;

  begin
    perform public.delete_expense(owner_a_expense_id);
    raise exception 'Owner B deleted Owner A expense';
  exception
    when no_data_found then null;
  end;

  -- Direct writes are revoked, so a supplied owner identifier cannot impersonate A.
  begin
    insert into public.expenses (user_id, amount, description, date)
    values (owner_a_id, 100, 'Impersonacao', '2026-01-19');
    raise exception 'Owner B inserted an expense for Owner A';
  exception
    when insufficient_privilege then null;
  end;

  execute 'reset role';
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub', owner_a_id::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', owner_a_id, 'role', 'authenticated')::text,
    true
  );

  select amount into owner_a_amount
  from public.expenses
  where id = owner_a_expense_id;

  if owner_a_amount <> 1350 then
    raise exception 'Cross-user expense mutation changed Owner A data';
  end if;

  perform public.delete_expense(owner_a_expense_id);

  execute 'reset role';
end;
$$;

select pass('expense RPCs derive ownership from the JWT actor and reject cross-user mutations');

do $$
declare
  owner_a_id constant uuid := '10000000-0000-0000-0000-000000000001';
  owner_b_id constant uuid := '20000000-0000-0000-0000-000000000002';
  january_budget_id uuid;
  february_budget_id uuid;
  owner_b_budget_id uuid;
  membership_count integer;
  unchanged_start_date date;
  unchanged_end_date date;
  budget_count_before_invalid_input integer;
begin
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub', owner_a_id::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', owner_a_id, 'role', 'authenticated')::text,
    true
  );

  select public.create_budget(500000, 'Janeiro', '2026-01-01', '2026-01-31')
  into january_budget_id;
  select public.create_budget(600000, 'Fevereiro', '2026-02-01', '2026-02-28')
  into february_budget_id;
  select public.update_budget(
    february_budget_id,
    610000,
    'Fevereiro atualizado',
    '2026-02-01',
    '2026-02-28'
  ) into february_budget_id;
  perform public.create_expense(7500, 'Despesa de janeiro', '2026-01-15');

  select count(*) into budget_count_before_invalid_input
  from public.budgets;

  begin
    perform public.create_budget(-1, 'Valor invalido', '2026-03-01', '2026-03-31');
    raise exception 'Negative budget amount was accepted';
  exception
    when check_violation then null;
  end;

  begin
    perform public.create_budget(100, 'Intervalo invalido', '2026-03-31', '2026-03-01');
    raise exception 'Invalid budget date range was accepted';
  exception
    when check_violation then null;
  end;

  begin
    perform public.create_budget(100, 'Sobreposto', '2026-01-15', '2026-02-15');
    raise exception 'Overlapping budget was accepted for the same owner';
  exception
    when exclusion_violation then null;
  end;

  if (select count(*) from public.budgets) <> budget_count_before_invalid_input then
    raise exception 'Invalid budget input persisted a partial record';
  end if;

  begin
    perform public.update_budget(
      february_budget_id,
      600000,
      'Fevereiro alterado',
      '2026-01-15',
      '2026-02-28'
    );
    raise exception 'Overlapping budget update was accepted for the same owner';
  exception
    when exclusion_violation then null;
  end;

  select start_date, end_date
  into unchanged_start_date, unchanged_end_date
  from public.budgets
  where id = february_budget_id;

  if unchanged_start_date <> '2026-02-01'::date
    or unchanged_end_date <> '2026-02-28'::date then
    raise exception 'Failed budget update persisted a partial range';
  end if;

  select count(*) into membership_count
  from public.expenses expense
  join public.budgets budget
    on expense.user_id = budget.user_id
   and expense.date between budget.start_date and budget.end_date
  where expense.user_id = owner_a_id
    and budget.id = january_budget_id
    and expense.description = 'Despesa de janeiro';

  if membership_count <> 1 then
    raise exception 'Expense membership is not derived from the budget date range';
  end if;

  if exists (
    select 1
    from pg_constraint
    where conrelid = 'public.expenses'::regclass
      and contype = 'f'
  ) then
    raise exception 'Expenses must not persist a budget foreign key';
  end if;

  execute 'reset role';
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub', owner_b_id::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', owner_b_id, 'role', 'authenticated')::text,
    true
  );

  select public.create_budget(900000, 'Janeiro B', '2026-01-01', '2026-01-31')
  into owner_b_budget_id;

  if owner_b_budget_id is null then
    raise exception 'Matching budget range was rejected for a different owner';
  end if;

  if exists (select 1 from public.budgets where id = january_budget_id) then
    raise exception 'Owner B can read Owner A budget';
  end if;

  begin
    perform public.update_budget(
      january_budget_id,
      1,
      'Tentativa de alteracao',
      '2026-01-01',
      '2026-01-31'
    );
    raise exception 'Owner B updated Owner A budget';
  exception
    when no_data_found then null;
  end;

  begin
    perform public.delete_budget(january_budget_id);
    raise exception 'Owner B deleted Owner A budget';
  exception
    when no_data_found then null;
  end;

  execute 'reset role';
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub', owner_a_id::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', owner_a_id, 'role', 'authenticated')::text,
    true
  );
  perform public.delete_budget(february_budget_id);

  execute 'reset role';
end;
$$;

select pass('budget constraints prevent invalid and overlapping ranges while preserving date-derived expenses');

do $$
begin
  execute 'set local role anon';
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claim.role', 'anon', true);
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);

  begin
    perform public.create_expense(100, 'Sem sessao', '2026-01-20');
    raise exception 'Unauthenticated actor created an expense';
  exception
    when insufficient_privilege then null;
  end;

  begin
    perform public.create_budget(100, 'Sem sessao', '2026-04-01', '2026-04-30');
    raise exception 'Unauthenticated actor created a budget';
  exception
    when insufficient_privilege then null;
  end;

  begin
    execute 'select count(*) from public.profiles';
    raise exception 'Unauthenticated actor read profiles';
  exception
    when insufficient_privilege then null;
  end;

  begin
    execute 'select count(*) from public.expenses';
    raise exception 'Unauthenticated actor read expenses';
  exception
    when insufficient_privilege then null;
  end;

  begin
    execute 'select count(*) from public.budgets';
    raise exception 'Unauthenticated actor read budgets';
  exception
    when insufficient_privilege then null;
  end;

  execute 'reset role';
end;
$$;

select pass('unauthenticated actors cannot read protected records or execute financial mutations');
select * from finish();

rollback;
