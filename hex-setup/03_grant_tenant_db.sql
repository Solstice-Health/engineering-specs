-- Grants for hex_ro inside ONE tenant database. Idempotent. Run per tenant DB
-- (04_grant_all_tenant_dbs.sh loops this over every tenant DB). Superseded by
-- Backend-Server scripts/tenant_onboarding/onboard_tenant.sql, which carries the same
-- grants and revokes; keep the two lists identical.
--
-- Model: read everything analytical, then REVOKE the tables that hold customer content
-- bodies, chat transcripts, prompt and template configuration, or plumbing. This revoke
-- list is the access control; the Hex schema filters in 09_hex_governance.py only hide
-- objects in the UI and must mirror this list, never replace it.

do $$
begin
  execute format('grant connect on database %I to hex_ro', current_database());
end $$;

grant usage on schema public to hex_ro;
grant select on all tables in schema public to hex_ro;
grant select on all sequences in schema public to hex_ro;

-- Content bodies, transcripts, configuration, plumbing: not for the analytics path.
do $$
declare t text;
begin
  foreach t in array array[
    'chat_messages', 'n_cg_operation_html_versions', 'prompt_registry', 'integrations',
    'header_footer_library', 'template_library', 'design_library', 'social_scraped_assets',
    'veeva_annotations', 'claim_studio_sessions', 'brand_pipeline_overrides',
    'notifications', 'user_notifications', 'n_cg_operation_processing_times',
    'file_processing_times', 'file_pages', 'alembic_version']
  loop
    if to_regclass('public.' || t) is not null then
      execute format('revoke all on public.%I from hex_ro', t);
    end if;
  end loop;
end $$;

-- Future tables. ALTER DEFAULT PRIVILEGES applies only to tables created by the role it
-- is set for, so set it for the running role and for every role that currently owns a
-- table here (skipped where the running role lacks membership). New tables therefore
-- become readable, and the revoke list above must be re-applied when a sensitive table is
-- added: re-running this file does both.
do $$
declare r record;
begin
  execute 'alter default privileges in schema public grant select on tables to hex_ro';
  execute 'alter default privileges in schema public grant select on sequences to hex_ro';
  for r in select distinct tableowner from pg_tables where schemaname = 'public' loop
    begin
      execute format('alter default privileges for role %I in schema public grant select on tables to hex_ro', r.tableowner);
    exception when insufficient_privilege then
      raise notice 'skipping default privileges for owner % (not a member)', r.tableowner;
    end;
  end loop;
end $$;
