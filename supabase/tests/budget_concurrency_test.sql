create extension if not exists dblink with schema extensions;

delete from auth.users
where id = '30000000-0000-0000-0000-000000000003';

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
values (
  '30000000-0000-0000-0000-000000000003',
  '00000000-0000-0000-0000-000000000000',
  'authenticated',
  'authenticated',
  'authorization-concurrency@cordato.test',
  'not-used-by-database-tests',
  now(),
  '{"provider":"email","providers":["email"]}',
  '{"display_name":"Concurrent Owner"}',
  now(),
  now()
);

select plan(1);

do $$
declare
  owner_id constant uuid := '30000000-0000-0000-0000-000000000003';
  connection_string text := format('dbname=%L', current_database());
  first_status text;
  second_status text;
  successful_writes integer;
  persisted_budgets integer;
  worker_sql text;
begin
  worker_sql := format(
    $sql$
      do $worker$
      begin
        perform set_config('request.jwt.claim.sub', %L, true);
        perform set_config('request.jwt.claim.role', 'authenticated', true);
        perform set_config(
          'request.jwt.claims',
          json_build_object('sub', %L::uuid, 'role', 'authenticated')::text,
          true
        );
        perform public.create_budget(100000, 'Concorrente', '2026-05-01', '2026-05-31');
        perform pg_sleep(1);
      end;
      $worker$;
    $sql$,
    owner_id::text,
    owner_id::text
  );

  perform extensions.dblink_connect('budget_writer_one', connection_string);
  perform extensions.dblink_connect('budget_writer_two', connection_string);
  perform extensions.dblink_send_query('budget_writer_one', worker_sql);
  perform pg_sleep(0.1);

  second_status := extensions.dblink_exec(
    'budget_writer_two',
    worker_sql,
    false
  );

  select status into first_status
  from extensions.dblink_get_result('budget_writer_one', false)
    as result(status text);

  successful_writes :=
    (case when first_status = 'DO' then 1 else 0 end)
    + (case when second_status = 'DO' then 1 else 0 end);

  select count(*) into persisted_budgets
  from public.budgets
  where user_id = owner_id
    and start_date = '2026-05-01'
    and end_date = '2026-05-31';

  if successful_writes <> 1 or persisted_budgets <> 1 then
    raise exception
      'Concurrent overlapping budget writes must leave exactly one row (first: %, second: %, rows: %)',
      first_status,
      second_status,
      persisted_budgets;
  end if;

  perform extensions.dblink_disconnect('budget_writer_one');
  perform extensions.dblink_disconnect('budget_writer_two');
end;
$$;

select pass('concurrent overlapping budget writes leave no overlapping live budgets');
select * from finish();

delete from auth.users
where id = '30000000-0000-0000-0000-000000000003';
