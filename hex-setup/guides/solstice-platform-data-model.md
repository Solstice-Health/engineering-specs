---
name: "Solstice platform data model"
description: "How to read the per-tenant Prod databases: tenants, brands, users, assets (n_cg_operations), review requests (admin_requests), MLR results, status values, soft deletes, and known traps such as marketing_files.is_reviewed."
---

# Solstice platform data model (the `Prod - <tenant>` connections)

Solstice is a content platform for pharmaceutical marketing teams. Customers create
promotional assets (emails, banners, slides, one-pagers, web pages), route them through
review, and publish them. Each customer runs in its own tenant.

## Tenants and connections

- One Postgres database per customer. In Hex each is a separate connection named
  `Prod - <tenant>` (for example `Prod - phathom`). The tenant slug is the database name.
- All connections point at the production read replica and are read-only.
- Any tenant slug ending in `_sandbox` (`phathom_sandbox`, `takeda_sandbox`, and in PostHog also
  `alexion_sandbox`) and `testing_demo` are not real customer activity. Exclude them unless the
  question is about testing.
- Real customer tenants: abbvie, akebia, alexion, ardelyx, argenx, astrazeneca, incyte,
  ipsen, novocure, nuvationbio, pfizer, phathom, priovant, real_chemistry, sanofi,
  stemline, teva, ucb.
- A question about one customer goes to that tenant's connection. A question across all
  customers cannot be answered from these connections in one query; use the CRM
  connection (synced request tracker for every tenant) or say that the answer is per tenant.

## Core tables (schema `public`, identical in every tenant)

| Table | What a row is | Notes |
|---|---|---|
| `companies` | The customer organisation | Usually one row per tenant. |
| `brands` | A drug or product brand within the company | Central entity. Nearly everything joins to `brands.id`. |
| `users` | A person with a login | `email`, `name`, `company_id`. Solstice staff appear here too. |
| `brand_team_members` | Which users belong to which brand and their role | Join `users` to `brands`. |
| `projects` | A folder that organises assets for a brand | Unique on `(brand_id, name)`. |
| `analytics.assets` | An asset: one generated piece of content, one row per version/page | This is what users call an asset. A view over `n_cg_operations` without its content columns; the base table is not readable. See below. |
| `admin_requests` | A request: a unit of work in the admin review queue | See below. This is the table for "pending requests". |
| `analytics.mlr_reviews` | One automated MLR review run for an asset version | Counts and flags only (`has_mlr_review`, `findings_count`, `consolidated_findings_count`, `report_id`); the report payload is not readable. |
| `marketing_files` | Files uploaded for review (older upload-based flow) | Different flow from assets. |

Soft deletes: most tables have `deleted_at`. Always add `deleted_at IS NULL` unless the
question is about deleted records.

## Assets (`analytics.assets`)

- One row per asset. `content_type` says what kind: `email`, `banner`, `slide`,
  `file_editor`, `trifold`, `onepager`, `webpage`, `other`.
- `status` is the generation pipeline stage, not a review status. Values: `editing`,
  `filtered_claims`, `enhanced_claims`, `generated_messages`, `generated_slides`,
  `unified_run`, `completed`. Do not use it to mean "approved".
- `file_name` is the name users see. Names starting with `#TEST` are test assets and are
  excluded from the CRM sync; exclude them from customer metrics too.
- `version_number` and `parent_id` link versions of the same asset. `page` and
  `page_root_id` link pages of a multi-page asset. To count distinct assets, count rows
  where `parent_id IS NULL` or count distinct `page_root_id`/`id` depending on the question.
- `project_id` places the asset in a folder.
- `brand_id` and `user_id` say which brand the asset belongs to and who created it.
- The asset id appears in product URLs as `/home/assets/<id>` and in PostHog events as the
  `operation_id` property.
- Not readable from Hex, by design: asset content and HTML, chat transcripts, prompts,
  templates, claims and clinical files, guideline results, Veeva documents. If a question
  needs them, say so rather than guessing at a table name.

## Requests (`admin_requests`)

A request is created when a user asks the customer's admin or reviewer to look at an asset.
This is the right table for review workload, backlog, and turnaround questions.

- `request_type`:
  `initial_save` = user clicked Save to Project or Save and Get Review for the first time;
  `change_request_review` and `change_request_complex` = user submitted a change request
  on an already saved asset (one row per batch of changes).
- `status`: `pending` (open) or terminal `completed` (resolved when the admin publishes)
  or `dismissed` (closed without publishing; reason in `request_metadata.dismissal`).
- `priority`: `backlog`, `low`, `medium`, `high`, or NULL meaning not yet triaged.
- Turnaround time is `resolved_at - created_at` for completed requests.
- `assigned_to` is a JSON snapshot `{user_id, name, email}` taken when the request was
  created and is not updated later.
- Denormalised for convenience: `brand_id`, `display_name`, `project_name`.
- Join to the asset via `cg_operation_id = n_cg_operations.id`; to the requester via
  `requester_user_id = users.id`; to the resolver via `resolved_by_user_id`.

## MLR review

MLR stands for medical, legal, and regulatory review. In Solstice the automated MLR
review for an asset version is one row in `analytics.mlr_reviews` (join `operation_id` to
`analytics.assets.id`). `findings_count` and `consolidated_findings_count` size the report;
the report text itself is not available in Hex. Count MLR reviews from this view, not from
`marketing_files.is_reviewed`.

## Things that are easy to get wrong

- `marketing_files.is_reviewed` only means someone opened the file in the document viewer
  and saved it. It is set to true on save and never reset. It is not an MLR submission or
  an approval. Label any metric built on it as "files saved in the viewer".
- `analytics.assets.status = 'completed'` means generation finished, not that the asset was
  approved or published. Publishing is visible as `admin_requests.status = 'completed'`
  for the asset's requests.
- Timestamps are UTC.
- Solstice staff use the product inside customer tenants. To exclude internal activity,
  filter `users.email NOT LIKE '%@solsticehealth.co'`.
