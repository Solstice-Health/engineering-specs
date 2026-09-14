---
name: "Solstice core metrics"
description: "Agreed definitions for the numbers leadership asks about: active users, assets created, review requests raised, pending backlog, turnaround time, MLR reports, published assets. Use these definitions and name them in answers."
---

# Solstice core metrics

When a question uses one of these terms, use this definition, say which one you used, and
apply the standard exclusions. If the question needs a different definition, say so.

## Standard exclusions (apply to every metric unless asked otherwise)

- Tenants: exclude any tenant slug ending in `_sandbox` (for example `phathom_sandbox`, `takeda_sandbox`, `alexion_sandbox`) and `testing_demo`. In PostHog, sandbox slugs appear that have no Hex connection; exclude them the same way.
- Rows: exclude soft-deleted rows (`deleted_at IS NULL`).
- Test content: exclude assets whose `file_name` starts with `#TEST` and assets in
  projects or folders whose name starts with `#TEST`.
- Solstice staff: exclude users with email ending `@solsticehealth.co` in tenant databases,
  and persons with `is_internal = 'true'` in PostHog.
- Time: UTC. "Last week" means the previous Monday to Sunday. "This month" means month to date.

## Metrics

**Active users** (PostHog). Distinct `person_id` with at least one event in the period,
excluding bookkeeping events `$identify`, `$set`, `$groupidentify`, `$pageleave`.
Weekly active users use a Monday to Sunday week.

**Assets created** (tenant DB). Rows in `analytics.assets` with `parent_id IS NULL` and
`page = 1`, counted by `created_at`. Versions and additional pages of the same asset are
not new assets. Break down by `content_type` when asked for mix.

**Review requests raised** (tenant DB, or CRM `request_drafts` across tenants). Rows in
`admin_requests`, counted by `created_at`. A request is one row regardless of type. When
the question is about first submissions only, use `request_type = 'initial_save'`.

**Assets submitted for review** (tenant DB). Distinct `cg_operation_id` in
`admin_requests`. Share submitted = this divided by assets created in the same period.

**Pending backlog** (tenant DB). `admin_requests` with `status = 'pending'` as of now.
Age of a pending request is `now() - created_at`. Report the count and the oldest.

**Turnaround time** (tenant DB). For `admin_requests` with `status = 'completed'`,
`resolved_at - created_at`. Report the median, not the mean, and give the sample size.

**Dismissed requests** (tenant DB). `admin_requests` with `status = 'dismissed'`. The
reason is in `request_metadata -> 'dismissal' ->> 'category'`.

**Change request rounds per asset** (tenant DB). Count of `admin_requests` rows per
`cg_operation_id` where `request_type` starts with `change_request`.

**MLR reports generated** (tenant DB). Distinct `operation_id` in
`analytics.mlr_reviews` where `has_mlr_review`. This is the automated MLR
review, not a human submission. Do not use `marketing_files.is_reviewed` for anything
MLR related.

**Published assets** (tenant DB). Distinct `cg_operation_id` with at least one
`admin_requests` row where `status = 'completed'`. Publishing resolves all pending
requests on the asset, so this is the closest available signal for "went live".

**Exports** (PostHog). Count of `export.succeeded` events. Failure rate =
`export.failed` divided by `export.requested`.

**Customers, active** (CRM). Accounts with a deal in stage `Closed Won`.

## Phrasing to use in answers

State the definition in one line, for example: "Active users = people with at least one
product event, excluding Solstice staff and sandbox tenants." If a number depends on a
choice between two definitions above (for example submitted for review versus MLR
reports generated), give both and label them.
