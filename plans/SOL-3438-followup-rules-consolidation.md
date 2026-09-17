# SOL-3438 follow-up: one home for the Contract v2 rules

**Status:** agreed, not yet implemented. Hand this to an implementer.
**Prerequisite reading:** [SOL-3438-unify-prc-write-flows.md](SOL-3438-unify-prc-write-flows.md) — this is scoped into that plan's PR 1 (backend) with a tail in PR 2 (MCP).

## What this changes, in one line

The document that *describes* Contract v2 moves next to the code that *enforces* it, is served from a read-only endpoint, and every validator check is stamped with the authoring rule it enforces so the two can be asserted against each other.

## Why

Two artifacts describe the same contract and live in different repositories:

| | Authoring rules | Enforcement |
|---|---|---|
| Where | `solstice-mcp-server/plugins/solstice-platform/skills/prc-template-recreation/references/renderer-contract.md` | `Backend-Server/src_v2/prc_proof.py` → `validate_prc_proof_report` |
| Served by | `solstice_prc_template_rules(profile)` | the rejected write |
| Vocabulary | `common.declaration`, `common.creative_slots`, … | `L0`–`L5`, `B1`–`B3` |
| Size | 92 rules over 5 profile scopes | 9 check identifiers |

They change together and deploy separately — the document ships in the MCP image (`Dockerfile:29`), the enforcement on the backend — so a contract change cannot be made atomically. This is the forked-composer problem in a second shape.

The vocabularies also do not join. A rejection says `L3`; the rules tool answers in `common.*`. An agent told its document failed `L3` has to guess which of 92 bullets that means.

**Not a merge.** The document is written for an author and is an order of magnitude larger than the enforceable subset. Neither artifact is generated from the other. One repo, plus a tested join, is the whole goal.

## Do this

### 1. Move the document and its parser into the backend

Move `renderer-contract.md` to a new `Backend-Server/src_v2/prc_contract/` package, beside `src_v2/prc_proof.py`. Port `_load_prc_template_rules` from `solstice-mcp-server/src/solstice_mcp/tools/content.py:70-125` — it is 50 lines of markdown parsing between `<!-- PRC_RULES_START -->` / `<!-- PRC_RULES_END -->` markers, with no MCP-specific logic beyond its `ToolError` raises.

Keep the parse-per-call behaviour and the loud failures. The existing comment says it best: a deployment that drops the file must fail rather than serve stale rules.

Confirm the `.md` reaches the image — the backend's Dockerfile copies `src_v2/`, but check for a `--include` or package-data filter that would drop a non-`.py` file.

### 2. Serve it

`GET /api/v2/prc-template-rules?profile={email|banner|social|website}`, in a new router under `src_v2/prc_contract/`, mounted in `src_v2/router.py`.

Response, identical to what the tool returns today plus one field:

```json
{ "contract_version": "v2",
  "profile": "email",
  "rules": { "must": [ { "id": "common.declaration", "text": "…", "enforcement": "backend" } ],
             "should": [ … ], "must_not": [ … ] },
  "source": "prc-template-recreation/references/renderer-contract.md" }
```

**Auth.** It serves the MCP as well as the app, so follow the `prc_writes_router` precedent in `src_v2/router.py:73-83`: no manifest gate, an actor dependency on the router. It is *not* brand-scoped — the payload is static and tenant-independent — so do not reach for `prc_brand_actor`. The route-walk test that asserts every route under that mount carries a brand check will need to learn about this one; make that explicit rather than loosening the test.

### 3. Stamp every check with the rule it enforces

`ProofIssue` in `src_v2/prc_proof.py` gains `rule: str | None = None`; `ProofIssueOut` in `src_v2/operations/schemas.py` gains the same. Then each `fail()` call in `validate_prc_proof_report` (lines ~570-620) names its rule:

| Check | Rule |
|---|---|
| `L0` missing declaration | `common.declaration` |
| `L1` body profile | `common.profile` |
| `L2` no pages host | `common.pages` |
| `L2` no page | `common.pages` |
| `L3` no creative slots | `common.creative_slots` |
| `L4` missing config seed | `common.config` |
| `L5` declares no fields | `common.fields` |
| `B1` missing baked marker | *none — see below* |
| `B2` missing export markers | *none* |
| `B3` empty / non-empty creative slot | *none* |

All seven named IDs exist in the document today; verified.

**The B-series deliberately maps to nothing.** Those checks describe what *composition produces*, not what an author writes, and the document has no bake scope. Adding one is new normative content and wants the domain owner, so it is out of scope here — leave `rule=None`, and file the gap. The B-checks already carry hints, so nothing regresses.

### 4. Mark enforcement, and assert the join

Add an `<!-- PRC_ENFORCEMENT_START -->` / `<!-- PRC_ENFORCEMENT_END -->` block to the document listing the rule IDs the **app's engine** enforces. The parser marks each rule:

- `backend` — named by a validator check. **Derived, never declared**, so it cannot drift.
- `engine` — listed in that block. Hand-maintained; source it from the app's `prc-contract-check.ts`.
- `advisory` — everything else.

Then the tests:

- every `rule` a check names exists in the parsed document;
- every ID in the engine block exists in the parsed document;
- a rule is marked at most once — `backend` wins if both claim it;
- a snapshot of the backend-enforced set, so dropping a check's rule shows up in review.

> The plan states the invariant as "every rule marked machine-enforced has a check that emits it." Because the `backend` marking is derived from the checks, that direction holds by construction — the assertions above are what is left to test.

### 5. Parity across the move

For all four profiles, the endpoint's `id`→`text` mapping must be byte-identical to what the MCP's local parse returns today. `solstice-mcp-server/tests/test_prc_templates.py:1514` has a `_doc_rules(profile)` helper that parses the document independently — port it, and keep that test on the MCP side pointed at the endpoint.

### 6. MCP tail — PR 2, not PR 1

`solstice_prc_template_rules` calls the endpoint through `PrcBackendClient`. Tool name, argument and payload unchanged. Then delete `_load_prc_template_rules`, `PRC_TEMPLATE_CONTRACT_PATH`, `PRC_RULES_START/END`, and the `renderer-contract.md` file — **keep the `Dockerfile:29` COPY**, which copies the whole skills tree and carries more than this one file.

Until that lands, PR 1 has created a second copy rather than moved one. The two PRs are not independently shippable in the way the rest of the plan's are; say so in the PR description.

### 7. Demote the third description

`engineering-specs/plans/SOL-3053-prc-template-anatomy-contract.md` describes the same contract and contradicts it. Reduce it to a pointer at the moved document. Going from three places to two is not consolidating.

## Two things that will bite

**The rules tool gains a failure mode it has never had.** It reads a file in its own image today and cannot fail from the network. After the move a backend outage blocks template authoring outright rather than degrading it. The plan accepts this behind the cutover flag; if the canary shows it mattering, cache the last good payload per profile.

**Test the endpoint at the route.** Same hazard as the rest of this ticket: a response model that disagrees with what the service returns passes every service-level test and 500s on the wire. This one is worse than most, because the payload is nested three deep.

## Do not

- Rewrite any rule's text, or change what the rules say. The document moves and is marked up; it is not authored. The one addition is the enforcement block.
- Generate either artifact from the other.
- Add a bake scope to the document. Flagged above; separate change, with the domain owner.
- Touch the Solstice app's checker or the harness. Both keep their own judgement; see the main plan.
