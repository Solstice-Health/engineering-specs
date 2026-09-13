-- Run ONCE against the PRIMARY (solstice-prod) through the prod tunnel (port 5433).
-- Roles are cluster-wide and replicate to the read replica automatically.
--
--   psql -h localhost -p 5433 -U postgres -d postgres -f 02_hex_ro_role.sql
--
-- Then set the password out of band (never in git or chat):
--   psql -h localhost -p 5433 -U postgres -d postgres \
--     -c "alter role hex_ro with password '<openssl rand -hex 24>'"

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'hex_ro') then
    create role hex_ro with login noinherit nosuperuser nocreatedb nocreaterole
      noreplication connection limit 10;
  end if;
end $$;

-- Guard rails so an analytics query cannot hold the replica or a session for long.
alter role hex_ro set statement_timeout = '120s';
alter role hex_ro set idle_in_transaction_session_timeout = '60s';
alter role hex_ro set default_transaction_read_only = on;
