# Hex analytics: operations runbook

Companion to the plan [SOL-XXXX: Analytics lake and Hex](../plans/SOL-XXXX-analytics-lake-hex.md),
which explains the design. This folder holds the scripts and guide sources needed to
operate it. Built 2026-09-13.

## What is connected

| Hex connection | Source | Path | Access |
|---|---|---|---|
| `Prod - <tenant>` (21) | Tenant databases on `solstice-prod-read-replica` | SSH tunnel through `solstice-bastion` (100.48.197.203) as OS user `hex` | DB role `hex_ro`, SELECT only |
| `Analytics lake (Athena)` | PostHog PROD events and persons, hourly Parquet in `s3://solstice-analytics-lake/posthog/` | Athena workgroup `solstice-analytics`, Glue db `solstice_analytics` | Hex assumes IAM role `hex-athena` (external id) |
| `CRM (Supabase)` | Solstice CRM, project `jqddeitfzorljqmldany` | Session pooler `aws-1-us-west-2.pooler.supabase.com:5432` | DB role `hex_ro`, SELECT + RLS policies on 7 tables |

Excluded on purpose: `solstice-auth` (credentials), the DEV PostHog project, Datadog (until a
question needs it).

## Recurring operations

**New tenant.** Run Backend-Server `scripts/tenant_onboarding/onboard_tenant.sql` against the new
database (grants `crm_sync_ro` and `hex_ro`). The CRM sync registers the tenant in
`platform_tenants` on its next nightly run and PostHog needs nothing. Add a `Prod - <slug>` Hex
connection by hand if per-tenant querying is wanted (Hex's API cannot create SSH-tunnelled
connections; use the template in the plan, and type the SSH host rather than pasting it).

**Guides changed.** Edit the markdown in `guides/`, then:

```bash
HEX_TOKEN=hxtw_... ./08_upload_hex_guides.sh
```

**Lock down access** (when more than the evaluators use Hex):

```bash
HEX_TOKEN=hxtw_... python3 09_hex_governance.py          # dry run
HEX_TOKEN=hxtw_... python3 09_hex_governance.py --apply
```

**Rotate `hex_ro`.** `alter role hex_ro with password '...'` on the prod primary (replicates to the
replica) and on Supabase, then update the password in each Hex connection. No other credential
exists: Hex reaches Athena and PostHog reaches S3 by assuming roles.

## Files

| File | Purpose | Run where |
|---|---|---|
| `01_bastion_add_hex_user.sh` | Creates the restricted `hex` OS user on the bastion from Hex's workspace SSH key (Hex: Settings, Data sources, bottom of page) | bastion |
| `02_hex_ro_role.sql` | Creates `hex_ro` on the RDS cluster with timeouts and read-only transactions | prod primary |
| `03_grant_tenant_db.sql`, `04_grant_all_tenant_dbs.sh` | Per-tenant grants for `hex_ro` (superseded by Backend-Server `scripts/tenant_onboarding`, kept for reference) | prod primary via tunnel |
| `07_supabase_crm_hex_ro.sql` | `hex_ro` on the CRM with RLS select policies. To be turned into a CRM migration | Supabase |
| `08_upload_hex_guides.sh` | Publishes `guides/*.md` to Hex through the guides API | laptop |
| `09_hex_governance.py` | Access group, sharing lockdown, connection descriptions, hidden plumbing tables | laptop |
| `guides/` | Source of truth for the four Hex guides: platform data model, PostHog analytics, CRM, core metrics | |

## AWS resources (account 432113314921, us-east-1)

S3 `solstice-analytics-lake` (SSE-S3, TLS only, public access blocked; `athena-results/` expires after
30 days). IAM roles `posthog-batch-exports` (trusted by PostHog US with external id
`posthog-01a05dc5-662f-0000-24f4-a94174f8361a`, write-only under `posthog/`) and `hex-athena`
(trusted by Hex's Athena role with Hex's external id, read-only). Glue tables `posthog_events`,
`posthog_persons`; views `posthog_persons_latest`, `posthog_events_flat`,
`posthog_daily_asset_activity`. Athena workgroup `solstice-analytics`, 10 GB scan cap per query.

PostHog batch exports (project 589053): `PROD events -> S3 analytics lake`
(`01a09be5-4cab-0000-e182-11d697932706`) and `PROD persons -> S3 analytics lake`
(`01a09be5-55ed-0001-731d-d57f23c68905`), hourly, Parquet, uncompressed, prefix
`posthog/<model>/dt={year}-{month}-{day}/`. Persons `created_at` and `_inserted_at` are epoch
seconds in the Parquet, not timestamps; the Glue table types them bigint and the view converts.
