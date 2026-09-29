# SOL-XXXX: Backend request logging

| | |
|---|---|
| **Ticket** | SOL-XXXX (no ticket yet) |
| **Author** | @saisolstice |
| **Reviewers** | TBD |
| **Tier** | 1 |
| **Status** | In review |
| **Date** | 2026-09-29 |

> [!IMPORTANT]
> **Tier check.** None of the Tier 2 triggers apply. The change is a log contract and one Datadog monitor on existing services. Datadog is already the logging destination.
> - [ ] Touches auth, tenancy, or permissions
> - [ ] Handles PHI or client data in a new way
> - [ ] Schema migration on existing tables
> - [ ] New external dependency, vendor, or infrastructure
> - [ ] Changes a cross-service or client-facing API contract
> - [ ] Hard to reverse: undoing it after ship would take more than a day, lose data, or be visible to clients

## Goal

Every Backend-Server HTTP request, every agent-runner HTTP request, and every Restate handler failure that is already a terminal error produces one structured log that Datadog can search. A server failure, a failed Celery task, an unhandled runner request, a failed agent turn, or a terminal Restate handler produces one error log with enough fields to open a ticket without reproducing the bug. Slack delivery, when it is later enabled, is a Datadog monitor on those error logs. No process calls Slack.

Eeva's frontend event spec shipped as [SOL-3331](https://linear.app/solsticehealth/issue/SOL-3331). This spec is the request-log contract for Backend-Server and Solstice-AI. The `error.kind` / `error.message` / `error.stack` fields and the monitor exist for this work. Nothing here waits on another logging ticket.

## Decision

Datadog posts to Slack. The app does not. The destination, once notifications are turned on, is one team channel so everyone can see what broke. On-call is who acts when the process itself is down. A single 500 is still posted there so the team can see it.

A 2xx or 4xx access line stays INFO and does not match any monitor. HTTP 500 is the rule for a request that failed the user. The three non-500 rows below are the stalls that never produce a 500, because the request already succeeded and the job, turn, or session died afterward.

P0, prod only:

| `evt` | Service | Why it pages |
|---|---|---|
| `http.server_error` | `solstice-backend` | The response to the user is 500 |
| `agent.request_failed` | `solstice-agent-runner` | The runner response is 500 |
| `celery.task_failed` | `solstice-backend` | The upload or job already returned, then the worker died, so the user waits forever |
| `agent.turn_failed` | `solstice-agent-runner` | The chat request already returned, then the turn died in the product |
| `session.handler_failed` | `solstice-html-edit-session` | Restate gives up. The session is dead and the user cannot continue |

Stays INFO, never Slack: every access line (`http.request`, `agent.request`), every 4xx, and `session.handler_retry`. A retry is Restate doing its job, not a verdict. The failure monitor groups by `evt` and `error.kind` and renotifies every 30 minutes, so one broken route does not become a thread of copies.

Process down, same team channel, written so the first line says the process is down:

| Signal | What it means |
|---|---|
| Web has produced no logs for 10 minutes in prod | The API process is down. One failed request is not this. |
| Celery worker has produced no logs for 10 minutes in prod | The worker process is down. One failed task is not this. |

These two are the ones on-call treats as the platform being down. They go to the same channel so the team sees them too. Both stay notifications-off until the failure monitor is turned on.

## Current behavior

`RequestLoggingMiddleware` (`src/shared/middleware/request_logging_middleware.py`) writes one line per HTTP request with method, path, status, and `duration_ms`. `get_base_context()` (`src/shared/logging/context.py`) adds `request_id`, user id, name, email, `tenant_slug`, `feature`, `operation_id`, and the formatter adds `dd.trace_id` when a span is active. JSON is emitted whenever `DD_ENV` is not `local`.

Holes:

- Paths containing `/sse/` or `/stream` are logged at DEBUG, so they do not show up at the deployed log level.
- `@log_route` sets `route_logged_var`, which demotes the middleware line to DEBUG, and then logs its own start and finish lines. Routes without the decorator only get the middleware line. Routes with it get a different pair of lines and no middleware line at INFO.
- `V2Error` (`src_v2/exceptions.py`) returns JSON and does not log. A 500 from that handler is only a status code on the access line.
- Unhandled exceptions become a 500 from Starlette and a traceback on uvicorn stderr. The JSON formatter does not emit `error.kind`, `error.message`, or `error.stack`.
- In `config/celery/task.py`, the generic "Task failed", "Task starting", and "Task finished" logs sit after a `return` inside the heartbeat skip (`task_failure_handler` around the `return` at line 1258, `task_prerun_handler` at line 1194, `task_postrun_handler` at line 1224). They never run. Only a `process_marketing_page` failure has a live log, and that one records task args.

Middleware order in `main.py`: `RequestLoggingMiddleware`, then `RequestIDMiddleware`, then `TenantMiddleware`, then CORS outermost. Starlette runs `ExceptionMiddleware` inside the logging middleware, so a handled `HTTPException` or `V2Error` is seen by the logger as a finished response, not as a raised exception.

## Request log

`RequestLoggingMiddleware` is the single access line for every HTTP request except paths starting with `/health`, `/docs`, `/openapi.json`, or `/redoc`.

One line, written when the response finishes, including streams. Do not log each SSE chunk.

| Field | Value |
|---|---|
| `evt` | `http.request` |
| level | INFO. A 5xx still keeps this line at INFO. The server-error log below is the ERROR line, so a failure is two records with different `evt` values and the monitor matches only one of them. |
| `http.method` | request method |
| `http.path` | `scope["path"]` only |
| `http.status_code` | integer |
| `duration_ms` | wall clock, one decimal |
| `streaming` | true when the path contains `/sse/` or `/stream` |

Context fields already attached by the formatter stay on this line. Do not copy them into `extra`.

Do not log the query string. SSE URLs carry the access token in the query (`SOL-1088`). Do not log the body or headers.

`@log_route` keeps setting `feature` and `operation_id` before the handler runs, so the middleware line in `finally` already has them. It stops emitting its own "Request" and "Response" info lines, and it stops setting `route_logged_var`. On failure it re-raises and does not log; the server-error log below is the one error line.

## Server-error log

One `logger.exception` call, `evt=http.server_error`, for each of these:

- an unhandled exception
- `HTTPException` with status ≥ 500
- `V2Error` with status ≥ 500

4xx responses, including `V2Error` and `HTTPException` below 500, do not get this event. Their access line is enough.

Fields, in addition to the formatter context:

| Field | Value |
|---|---|
| `error.kind` | exception class name |
| `error.message` | `str(exc)[:500]` |
| `error.stack` | traceback truncated to 8 frames and 2000 characters |
| `http.method` | method |
| `http.path` | path, no query string |
| `http.status_code` | status returned to the client |

Use `exc_info=True` so the logging traceback is present. `error.stack` is the truncated copy the monitor template reads. The client body stays the existing generic detail. Do not put the traceback, query string, or request body in the response.

Register the unhandled and `HTTPException` handlers inside `register_exception_handlers` in `src_v2/exceptions.py`. `register_v2` already calls that function on the FastAPI app (`main.py`), so the handlers cover every route, not only `/api/v2`. One helper builds the `extra` dict so the three handlers cannot drift.

## Celery failure log

`task_failure_handler` emits one error log for every task failure except tasks whose name starts with `tasks.update_heartbeat` or `tasks.check_stalled_task`.

| Field | Value |
|---|---|
| `evt` | `celery.task_failed` |
| `celery_task_name` | Celery task name |
| `celery_task_id` | task id |
| `error.kind` | exception class name |
| `error.message` | `str(exc)[:500]` |
| `error.stack` | same truncation as HTTP |

`exc_info` comes from the signal's `einfo` when present. Do not log `args` or `kwargs`. Do not use `task_id` or `task_name` as `extra` keys; Celery already puts those on the log record. Tenant and user id continue to arrive from the existing task headers (`x_tenant_slug`, `x_user_id`) restored in `celery_app.py`.

Remove the unreachable logs after the early `return` in `task_prerun_handler`, `task_postrun_handler`, and `task_failure_handler`. Do not replace the prerun and postrun logs with a start or finish line per task. Successful tasks stay as quiet as they are today. The marketing-page-specific failure log goes away; `celery.task_failed` covers it without the args.

## Solstice-AI

Two processes already emit JSON to Datadog. A third plane, the MicroVM's raw stdout, does not. This spec covers the first two and leaves the third alone.

In-VM heap death (`FATAL` / `JavaScript heap out of memory`) lands in CloudWatch `/aws/lambda-microvms/pi-harness-*`, not in Datadog. Lifecycle suspend and resume are the same. This monitor does not page on those. A turn that dies as HTTP 500 on the runner is `agent.request_failed`; a turn the tracer marks failed is `agent.turn_failed`.

### Runner (`harness/runtime/observability/log.ts`)

`DD_SERVICE` is `solstice-agent-runner` (`terraform/modules/microvm-image/microvm_image.tf`). Logs go to stdout and, when intake is on, to Datadog via `ddIntake.ts`. Context is `operation_id`, `turn_id`, `request_id`. The runner has no user email or tenant slug; `operation_id` is the ticket key. Do not add a user lookup.

There is no access line per HTTP request. Hono routes log specific events (`agent.init`, `agent.turn_dispatch`, `agent.asset_write`, and the hooks). `app.onError` in `harness/runtime/server.ts` logs `agent.request_failed` for unhandled errors and also `console.error`s the same exception. `HttpError` (400 / 404 / 409) returns JSON and logs nothing. The 500 response body is `err.message`.

Add one access line, `evt=agent.request`, when each response finishes, except `/health`. Fields: `http.method`, `http.path` (pathname only), `http.status_code`, `duration_ms`. Level INFO, including 5xx. One line per request, including a long `/turn` stream, written when it finishes.

`agent.request_failed` keeps its event name and gains `error.kind`, `error.message` (500 chars), and `error.stack` (8 frames, 2000 chars). The client body is `{"detail": "Internal server error"}`. Drop the `console.error` on that path. `HttpError` stays a 4xx with no `agent.request_failed`; the access line carries the status.

`agent.turn_failed` (`harness/runtime/observability/tracing/sinks/datadog.ts`) gains `error.kind` of `TurnFailed` and `error.message` set to the existing clipped message. The tracer event has no stack, so `error.stack` is omitted. `operation_id` is already on the line via `setLogContext`.

`console.error` elsewhere in the harness (`turn.ts`, `session.ts`) stays CloudWatch stdout. Do not promote those lines to `status:error` events in this spec.

### Restate session (`platform/restate-agent-session`)

`DD_SERVICE` is `solstice-html-edit-session` (`terraform/modules/restate-services/html_edit_session.tf`). `telemetry/tracing.py` already logs `session.handler_failed` at error for `TerminalError`, and `session.handler_retry` at info otherwise. Completion logs stay as they are.

`session.handler_failed` gains `error.kind`, `error.message` (`str(exc)[:500]`), and `error.stack` (same truncation as HTTP), passes `exc_info`, and drops the current `error` extra so the message is not stored twice. `DatadogJsonFormatter` already copies caller extras onto the JSON object, so it needs no new field logic. Retries stay INFO and off the monitor.

Code for this spec lands in two repos: `Backend-Server` and `Solstice-AI`. The monitor is one Datadog object over both.

## Formatter

Backend `DatadogJsonFormatter.add_fields` copies `error.kind`, `error.message`, and `error.stack` from the log record onto the JSON object when they were passed in `extra`. It does not invent them for lines that have no exception. Existing redaction stays on all three JSON formatters (Backend-Server, the runner's `redact()`, and the Restate formatter): any key containing `token`, `secret`, `api_key`, `password`, `authorization`, `credential`, or `bearer` is replaced with `***REDACTED***`. The runner already redacts numbers that merely contain those substrings, so `prompt_tokens` still ships as a number. Do not change that.

## Datadog monitor

Create one log monitor. Leave its notifications off. Do not attach a Slack channel, webhook, email, or PagerDuty destination.

Query is by event name, not a single service. The three prod service tags are `solstice-backend`, `solstice-agent-runner`, and `solstice-html-edit-session`.

```
env:prod status:error @evt:(http.server_error OR celery.task_failed OR agent.request_failed OR agent.turn_failed OR session.handler_failed)
```

Group by `evt` and `error.kind`. Trigger when the count is at least 1 in 5 minutes. Renotify interval is 30 minutes. Recovery does not post.

Message template, stored on the monitor so a later enable step does not invent one. It must include: `service`, env, version, `evt`, `error.kind`, `error.message`, `http.path` or `celery_task_name` or `handler`, `tenant_slug`, `user_email`, `operation_id`, `request_id`, `dd.trace_id`, and a Logs Explorer link filtered to that `request_id` when present, otherwise to `operation_id`. Runner lines have `operation_id` and no user email. Backend lines have both. Missing fields stay blank. No log body beyond those fields.

Dev and local logs stay searchable in Datadog. The monitor query is prod only, so a synthetic dev error cannot page even after notifications are turned on.

## Verification

Pytest, run in `backend-server-web-1`:

- A 200 and a 422 each emit one INFO line with `evt=http.request` and no `error.kind`. The query string from the request is absent from the log record.
- An unhandled exception, an `HTTPException(500)`, and a `V2Error` with status 500 each emit `evt=http.server_error` with `error.kind`, `error.message`, and `error.stack`, and the HTTP response body is the generic detail with no traceback.
- A `V2Error` 404 emits only the access line.
- A decorated route emits one access line from the middleware, with `feature` set, and no second "Request" / "Response" line.
- A stream path emits one INFO access line when the response finishes.
- `task_failure_handler` emits `evt=celery.task_failed` and does not include task args. Heartbeat and stall-check failures emit nothing.
- Formatter output contains `error.kind`, `error.message`, and `error.stack` when those extras are set, and omits them otherwise.

Solstice-AI unit tests, next to the existing observability tests:

- A runner 200 and a `HttpError` 409 each emit one `agent.request` line and no `agent.request_failed`. The path has no query string.
- An unhandled runner exception emits `agent.request_failed` with `error.kind`, `error.message`, and `error.stack`, and the HTTP body is the generic detail.
- `agent.turn_failed` includes `error.kind=TurnFailed` and `error.message`, and does not include document HTML.
- `session.handler_failed` includes the three `error.*` fields. A non-terminal raise still logs `session.handler_retry` at info and not `session.handler_failed`.

After deploy to dev, throw one synthetic unhandled error on the backend and confirm the log matches the field list in Logs Explorer. A runner check is the same shape on `service:solstice-agent-runner` in dev, using an existing dev operation rather than a new prod VM. Neither check enables the monitor's notifications.

## Out of scope

- Frontend product analytics.
- Datadog Error Tracking toggles, dashboards, log-based metrics, and a `print()` lint gate. The two process-down checks above are the only absence alerts in this spec.
- Compliance audit storage.
- Logging request or response bodies.
- A Slack client, webhook, or message from application code.
- Turning the monitor's notifications on.
- Shipping MicroVM stdout, heap `FATAL` lines, or suspend/resume lifecycle out of CloudWatch into Datadog.
- Replacing `console.error` in `harness/runtime/turn.ts` and `harness/runtime/session.ts`.
