# SOL-3438 follow-up: fold validation into the writes that already do it

**Status:** agreed, not yet implemented. Hand this to an implementer.
**Prerequisite reading:** [SOL-3438-unify-prc-write-flows.md](SOL-3438-unify-prc-write-flows.md) — this narrows part of it.

## What this changes, in one line

Three standalone validation endpoints and one MCP tool are removed, and the two writes that already validate start reporting *what* was wrong instead of a single collapsed message.

## Why

Both writes already validate before storing anything:

- **Version commit** — `apply_version_commit` calls `validate_prc_proof` and rejects.
- **Template publish** — `create_template_version` calls `_reject_unusable_shell`, added in the first PR, and rejects.

Both then throw away the detail. `validate_prc_proof` raises on the *first* failed condition, so a caller gets one message where the reporting form would have given every failure with a stable identifier and a repair hint.

That is the whole reason the separate endpoints looked necessary. They were answering a question the write was already answering, badly. Fix the answer and the endpoints have no caller.

Attempting the write is cheap in both cases. A rejected template publish writes nothing and needs no upload. A rejected commit writes nothing either — its only cost is an S3 object the caller already uploaded, which a lifecycle rule can sweep.

### The one caller this does not serve

The AI harness runner asks mid-turn, while the agent is still editing, and its "save" is parking a proposal at turn end — terminal, not retryable. Learning at save time means the turn fails in front of a user, so it genuinely needs to ask without writing.

It is out of scope here: this ticket is about MCP/backend duplication, the backend already validates harness output authoritatively at ingest (`src_v2/agents/html_edit/ingest.py`), and deferring costs the agent earlier feedback rather than correctness. The work exists on `gifan/SOL-3438-harness-proof-verdict` (pushed, green) if it is picked up later.

**Consequence to state plainly:** until that lands, the contract is judged in three places — backend, Solstice app, AI harness — not two. The main plan's Goals section currently claims two; correct it.

## Do this

### 1. Version commit returns the full report

`src_v2/operations/services/versions.py:237-239` currently collapses both proof failures:

```python
except StalePrcProofError as exc:
    raise StaleProof(str(exc)) from exc
except InvalidPrcProofError as exc:
    raise InvalidProof(str(exc)) from exc
```

Carry the failures through instead, from `validate_prc_proof_report(html, content_type)` in `src_v2/prc_proof.py`, which already returns `list[ProofIssue]` with `check` / `message` / `hint`.

The error body is shaped by `_v2_error_handler` in `src_v2/exceptions.py`, which today emits `{"detail": {"code", "message"}}` when `V2Error.code` is set. It needs to carry the failures too — extend `V2Error` with an optional failures payload rather than stuffing them into `message`.

Keep `code` values as they are (`invalid_proof`, `stale_proof`): the MCP maps them to tool-facing strings the tool descriptions name by hand, and changing them silently changes agent behaviour.

### 2. Template publish returns the full report

`src/content_generation_new/application/prc_template_service.py:50`:

```python
raise HTTPException(status_code=400, detail=f"html_template is not a usable PRC shell: {exc}") from exc
```

Same treatment. Note this path calls `validate_prc_template`, which wraps `_validate_base` — the *input* half of composition, which has no reporting form yet. Either give it one, or run the existing `validate_prc_proof_report` over the stamped template to enumerate structural failures. The second is what `PrcValidationService.validate_template` does today; read it before deleting it.

### 3. Delete the validation surface

| Remove | Note |
|---|---|
| `src_v2/operations/services/validation.py` | `PrcValidationService` — no callers left |
| `src_v2/operations/routers/prc_templates.py` | whole router; unmount from `src_v2/router.py` |
| `validate_operation_proof` in `src_v2/operations/routers/prc_writes.py` | keep `prepare_version_upload` and `publish_operation_version` |
| `validate_proof` in `src_v2/agents/router.py` (~line 249) | the callback-plane route; existed only for the harness |
| `ValidateProofRequest`, `ValidateTemplateRequest` in `src_v2/operations/schemas.py` | |
| `get_prc_validation_service` in `src_v2/operations/dependencies.py` | |
| `solstice_validate_prc` in `solstice-mcp-server` `src/solstice_mcp/tools/content.py` | both modes |
| `validate_proof`, `validate_template` in `src/solstice_mcp/prc_client.py` | |

**Keep** `ValidationReportResponse` and `ProofIssueOut` in `src_v2/operations/schemas.py` — the error bodies want the same shape. Keep `validate_prc_proof_report` and `ProofIssue` in `src_v2/prc_proof.py`; they are what makes the reports possible.

### 4. Tests

Delete `tests/v2/operations/test_prc_routes.py`'s validation cases and the route-registration assertions for the removed paths. Keep the route-walk test for what remains.

Add, and this is the important part: **route-level** assertions that a rejected commit and a rejected template publish come back with named failures. Not service-level — see below.

## Two things that will bite

**Test at the route, not the service.** A bug exactly like this shipped once already: `ValidationReportResponse` declared pydantic models while the service returned dataclasses, so *every validation call that found a problem returned 500*. The clean path returned an empty list and passed. 1264 unit tests missed it; it was caught by driving the MCP client against a running backend. Any new report-carrying error body has the same hazard.

**The report is now load-bearing.** With no validate endpoint, a rejected write is the *only* way an agent learns what is wrong. If the failures do not reach the body, the feature is gone and nothing fails loudly.

## Do not

- Touch the Solstice app. It keeps its in-browser checker; a continuous in-editor check against ~21MB proofs is not viable over an endpoint. Separately discussed, separately ticketed.
- Do the harness change. Out of scope per above.
- Change MCP tool signatures or the error-string mapping in `src/solstice_mcp/prc_client.py` beyond deleting the two validate methods.
- Touch `prepare` or `publish`. Prepare is irreducible — a ~21MB proof cannot pass through the tool-call channel, so the agent must PUT to S3 out of band and refer to the key.

## Current state

| Repo | Branch | Commits |
|---|---|---|
| Backend-Server | `gifan/SOL-3438-prc-validator-union` | 9, rebased on `dev` after #1305 merged |
| solstice-mcp-server | `gifan/SOL-3438-prc-writes-via-backend` | 4 |
| Solstice-AI | `gifan/SOL-3438-harness-proof-verdict` | 3 — shelve |

All pushed, all green, none merged. This follow-up can land on the existing branches or as its own.
