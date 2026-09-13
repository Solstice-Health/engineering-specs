---
name: "Solstice CRM"
description: "Accounts, deals, deal stages, and the daily-synced request_drafts table in the CRM (Supabase) connection; the only place all customers appear together; how CRM status differs from platform request status."
---

# Solstice CRM (the `CRM (Supabase)` connection)

The CRM is Solstice's internal sales and account system. It is the only connection where
every customer appears in the same tables, so use it for questions across all customers.

## Tables

| Table | What a row is | Notes |
|---|---|---|
| `accounts` | A customer company | `name`, `msa` (master services agreement). |
| `deals` | A commercial deal with a customer | `company`, `stage`, `value`, `monthly_revenue`, `projected_value`, `contract_expiry`, `launch_brand`, `owner`, `account_id`. |
| `activity` | A deal stage change | `deal_id`, `from_stage`, `to_stage`. Deal history. |
| `mlr_assets` | An asset tracked commercially against a deal | `deal_id`, `asset_type`, `veeva_job_code`, `review_cycles`, `approval_date`. |
| `request_drafts` | A platform review request, synced daily from every tenant | See below. |
| `audience_mappings` | Normalisation of audience text per tenant and brand | Reference data. |
| `sync_runs` | One row per nightly sync run | `tenants_scanned`, `tenants_failed`, `drafts_upserted`. Check here if request data looks stale. |

## Deal stages

Stages seen in the product include `Proposal Sent`, `Closed Won`, and `Closed Lost`.
`Closed Won` means an active paying customer. Check `select distinct stage from deals` for
the full current list before grouping by stage. Revenue questions use
`value` (total contract) or `monthly_revenue`; `projected_value` is a forecast.

## Request drafts and how they relate to the platform

`request_drafts` is a copy of `admin_requests` from every tenant database, refreshed once a
day by a sync job. One row per request. Columns: `tenant_slug` (the customer tenant),
`request_id` (the `admin_requests.id` in that tenant), `request_type`, `display_name`,
`project_name`, `brand_name`, `requester_name`, `requester_email`, `requested_at`,
`status`, `accepted_asset_id`, `reviewed_at`.

- `status` here is the CRM triage state (`draft`, `accepted`, `rejected`), not the platform
  request status. It says whether the CRM has attached the request to a tracked asset.
- For platform request status (pending, completed, dismissed) the tenant connection is the
  source of truth. The CRM sync only includes requests from live operations and excludes
  assets whose name or folder starts with `#TEST`.
- Join to accounts and deals by company name: `request_drafts.tenant_slug` corresponds to
  the customer, and `deals.company` or `accounts.name` carries the customer name. Names
  may differ in case or spelling from the slug; match loosely.
- Data is up to 24 hours behind the platform.

## Not available here

User accounts, roles, and access lists for the CRM app itself are not exposed to Hex.
