-- Flare Chat Realtime enablement (safe, repeatable migration)
-- This does NOT drop, recreate, or modify any existing table or row.
-- It enables database-change events used by incoming calls, WebRTC signalling,
-- and live message updates.

do $$
declare
  table_name text;
begin
  if not exists (
    select 1
    from pg_publication
    where pubname = 'supabase_realtime'
  ) then
    raise exception 'Publication supabase_realtime does not exist in this Supabase project.';
  end if;

  -- A FOR ALL TABLES publication already includes these tables.
  if exists (
    select 1
    from pg_publication
    where pubname = 'supabase_realtime'
      and puballtables = true
  ) then
    raise notice 'supabase_realtime publishes all tables; no changes required.';
    return;
  end if;

  foreach table_name in array array['calls', 'call_signals', 'messages']
  loop
    if to_regclass(format('public.%I', table_name)) is null then
      raise exception 'Required Flare Chat table public.% is missing.', table_name;
    end if;

    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = table_name
    ) then
      execute format(
        'alter publication %I add table public.%I',
        'supabase_realtime',
        table_name
      );
      raise notice 'Added public.% to supabase_realtime.', table_name;
    else
      raise notice 'public.% is already in supabase_realtime.', table_name;
    end if;
  end loop;
end
$$;
