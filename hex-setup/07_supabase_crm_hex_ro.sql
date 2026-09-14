-- Hex read-only access to the Solstice CRM (Supabase project jqddeitfzorljqmldany).
-- Idempotent. Applied 2026-09-13 by hand; to be re-expressed as a CRM migration.
--
-- NO PASSWORD IN THIS FILE. The role is created without one (so it cannot log in), and
-- the password is set once, out of band, with a generated value that is never committed:
--
--   alter role hex_ro with password '<openssl rand -hex 24>';
--
-- Re-running this file refreshes grants and policies and leaves the password untouched.
--
-- Exposes the business tables only. Access-control tables (profiles, allowed_emails,
-- page_access, page_data_access) stay hidden. RLS is on for these tables, so a plain
-- GRANT is not enough: each table also gets a SELECT policy for hex_ro.

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'hex_ro') then
    create role hex_ro with login noinherit nosuperuser nocreatedb nocreaterole
      noreplication connection limit 10;
  end if;
end $$;

alter role hex_ro set statement_timeout = '120s';
alter role hex_ro set idle_in_transaction_session_timeout = '60s';
alter role hex_ro set default_transaction_read_only = on;

grant connect on database postgres to hex_ro;
grant usage on schema public to hex_ro;

do $$
declare t text;
begin
  foreach t in array array['deals','activity','accounts','mlr_assets',
                           'request_drafts','audience_mappings','sync_runs']
  loop
    execute format('grant select on public.%I to hex_ro', t);
    execute format('drop policy if exists hex_ro_read on public.%I', t);
    if exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
               where n.nspname = 'public' and c.relname = t and c.relrowsecurity) then
      execute format('create policy hex_ro_read on public.%I for select to hex_ro using (true)', t);
    end if;
  end loop;
end $$;

-- Verify: the seven tables with SELECT for hex_ro, and that the role has a password set.
select table_name, privilege_type
from information_schema.role_table_grants
where grantee = 'hex_ro' and table_schema = 'public'
order by table_name;
select rolname, rolpassword is not null as has_password from pg_authid where rolname = 'hex_ro';
