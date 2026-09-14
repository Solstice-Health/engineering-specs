---
name: "PostHog product analytics"
description: "Events, properties, persons, and groups in the Analytics lake (Athena) connection; what each product event means; how to exclude internal staff; join keys to tenant databases and the CRM."
---

# Product analytics from PostHog (the `Analytics lake (Athena)` connection)

PostHog records what people do in the Solstice web app. The events are exported every
hour to S3 and queried through Athena. Use this connection for questions about usage,
engagement, adoption, and behaviour. Data is about one hour behind and starts 3 September 2026.

## Tables (database `solstice_analytics`)

| Table | What it holds | Notes |
|---|---|---|
| `posthog_events_flat` | One row per event with the useful fields already extracted as columns | Prefer this over the raw table. Columns: `tenant`, `brand_id`, `asset_id`, `url`, `tenant_from_url`, `content_kind`, `is_admin`, `admin_request_id`, `request_type`, `request_status`, `bypass_mlr`, `qc_override`, `email`, `person_name`, `is_internal`, `is_bookkeeping`, plus raw `properties`. Filter on `dt`. |
| `posthog_daily_asset_activity` | One row per day, tenant, brand, asset with counts of opens, edits, request views, publishes, exports, and distinct people | Internal staff and bookkeeping events already excluded. Best starting point for usage-per-asset and usage-per-customer questions. |
| `posthog_events` | Raw export, one row per event | Use only when a property is not exposed by the flat view. `properties` is a JSON string. |
| `posthog_persons_latest` | One row per person, latest version | Use this, not the raw `posthog_persons` table, for people. |
| `posthog_persons` | Raw person export with update history | Timestamps are epoch seconds; prefer the view above. |

Standard filters on the flat view: `NOT is_internal AND NOT is_bookkeeping`. If you need a
property that is not a column, read it from `properties` with
`json_extract_scalar(properties, '$.some_key')`.

## Events and what they mean

| Event | Meaning |
|---|---|
| `$pageview`, `$pageleave` | Page visits. `$current_url` holds the URL. Tenant is the subdomain, for example `www.phathom.solsticehealth.co`. |
| `asset.opened` | A user opened an asset. Properties: `operation_id`, `content_kind`, `version_count`, `is_admin`, `from`. |
| `asset.version_switched` | User switched between versions of an asset. |
| `intake.started`, `intake.step_viewed`, `intake.step_completed`, `intake.source_attached`, `intake.submitted` | The asset creation flow. `intake.submitted` means the user finished creating an asset. |
| `editor_edit.edit_session_started`, `editor_edit.edit_session_ended`, `editor_edit.manual_edit_made` | Editing an asset by hand. |
| `prc_edit.edit_session_started`, `prc_edit.edit_session_ended` | Editing in the PRC (promotional review) view. |
| `chat.message_sent`, `chat.feedback_submitted` | Using the AI chat to edit an asset. |
| `request.viewed` | Someone opened a review request. Properties: `admin_request_id`, `request_type`, `status`, `has_admin_request`. |
| `publish.requested`, `publish.succeeded`, `publish.blocked` | Publishing an asset. `bypass_mlr` and `qc_override` say whether review was skipped. |
| `export.requested`, `export.succeeded`, `export.failed` | Downloading or exporting an asset. |
| `session.brand_switched` | User changed the active brand. |
| `$identify`, `$set`, `$groupidentify` | Bookkeeping events. Exclude them from activity counts. |

## People, tenants, brands

- Persons carry `email`, `name`, `tenant` (the tenant slug), and `is_internal`. Set
  `is_internal = 'true'` marks Solstice staff. Exclude them for customer usage questions:
  `json_extract_scalar(person_properties, '$.is_internal') <> 'true'`.
- Events carry group membership in `$groups`: `$groups.tenant` is the tenant slug and
  `$groups.brand` is the brand id from the tenant database.
- "Active users" means distinct `person_id` with at least one non-bookkeeping event in the
  period.

## Joining to other connections

Athena cannot join to the tenant databases or the CRM directly. To combine, pull a
filtered result from each side and join in a notebook.

- Asset: `asset_id` (flat view) equals `analytics.assets.id` in the tenant database and the
  asset id in `/home/assets/<id>` URLs.
- Brand: `brand_id` equals `brands.id` in the tenant database.
- Tenant: `tenant` equals the tenant slug, the tenant database name, `request_drafts.tenant_slug`
  and `accounts.tenant_slug` in the CRM.
- User: `email` equals `users.email` in the tenant database.
