-- Grants for hex_ro inside ONE tenant database. Idempotent. Run per tenant DB
-- (04_grant_all_tenant_dbs.sh loops this over every tenant DB).
-- Read-only on every table and view in public, including tables created later.

do $$
begin
  execute format('grant connect on database %I to hex_ro', current_database());
end $$;

grant usage on schema public to hex_ro;
grant select on all tables in schema public to hex_ro;
grant select on all sequences in schema public to hex_ro;
alter default privileges in schema public grant select on tables to hex_ro;
alter default privileges in schema public grant select on sequences to hex_ro;
