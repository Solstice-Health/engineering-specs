# Plans & Spikes: Process Guide

Before merge-bound code, the approach gets a written plan and a quick peer review. This page defines the categories of work, the process for each, and what sign-off means.

Templates: [Engineering Plan Template](templates/plan-template.md) · [Spike Brief Template](templates/spike-brief.md). Plans live in [`plans/`](plans/), one file per plan, reviewed as a pull request in this repo. Ticket rules extend the Product Engineering Working Agreement.

## The four categories

| Category | The work | Doc | Review | In Linear |
|---|---|---|---|---|
| Tier 0 | Contained and reversible, under about a day | None; the ticket is enough | Normal code review | Bug or Feature template, as today |
| Tier 1 | The default for feature, refactor, and debt work | Plan, one page | 2 reviewers, 24 hours | needs-plan label, plan PR link in the description |
| Tier 2 | Anything that trips a trigger below, regardless of size | Plan, with the Tier 2 sections kept in | 2 reviewers including the domain owner, 24 hours | needs-plan; usually epic-level, child tickets come from Phasing |
| Spike | A timeboxed question with exit criteria | Spike Brief | 2 reviewers, same day | Spike label, due date is the timebox |

**Tier 2 triggers** (same list as the template): touches auth, tenancy, or permissions; handles PHI or client data in a new way; schema migration on existing tables; new external dependency, vendor, or infrastructure; changes a cross-service or client-facing API contract; hard to reverse, meaning undo takes over a day, loses data, or is visible to clients. When in doubt, take the higher tier.

## Examples

**Tier 0**

- Fix the PDF export shifting RBAs on one brand's assets
- Tune a prompt in an existing agent
- Bump retries on a flaky Celery task
- Add a Datadog monitor
- A refactor inside one module, no contract change

**Tier 1**

- A new endpoint on an existing service, following existing patterns
- A new regulatory check type inside the MLR reviewer
- A new Braintrust eval pack
- A new Celery task in an existing pipeline
- Restructuring a service for clarity, contracts unchanged

**Tier 2**

- The usage_events cost ledger: new tables plus capture points across services
- Adopting Restate as the durability spine
- Any change to X-Tenant-Slug scoping, staff roles, or the Auth0 integration
- Adding a TTS vendor to the video pipeline
- Changing the append-only document versioning model
- A new client-facing API contract

**Spike**

- Can Restate checkpoint our LangGraph flows without a rewrite? 2 days
- Which database serves the knowledge graph: Postgres (recursive CTEs, AGE) or Neo4j? 2 days
- Does headless Chrome hold frame rate for video export at 1080p? 1 day

## Close calls

| This | That | Why they tier differently |
|---|---|---|
| New table for a brand-new feature: Tier 1 | Migration that alters or backfills existing tables: Tier 2 | Existing data raises the cost of being wrong |
| Internal endpoint on existing patterns: Tier 1 | Client-facing API contract: Tier 2 | External consumers make later changes expensive |
| Swapping model tier on an existing path: Tier 0 or 1 | Adding a new external vendor: Tier 2 | A new processor changes data flow and ops surface |
| Reading vendor docs to inform a plan: part of the plan | Timeboxed bake-off with fixed criteria: Spike | A spike answers one named question with evidence |

## The process, per category

### Tier 0

1. Ticket as today. Build. Normal code review. No plan, no label.

### Tier 1

1. Ticket is created through any of the usual capture routes.
2. Whoever refines it runs the tier check. Needing a plan means: add the needs-plan label and a Plan link line in the description.
3. Copy [`templates/plan-template.md`](templates/plan-template.md) to `plans/SOL-XXXX-short-slug.md` and open a PR. Claude Code or Cursor drafts it from the codebase; you edit.
4. Pick two reviewers who know the area. Request their review on the PR and link the PR from the ticket.
5. Reviewers comment within 24 hours. One async round; then a 15 minute call if needed.
6. Both reviewers approve the PR and it merges. The plan is Approved; the ticket now passes Definition of Ready and can be committed at Monday planning.
7. Build with the plan as the brief, for you and for the agents. Log deviations in the decision log as they happen.
8. On ship: distill durable decisions into `CLAUDE.md`, mark the plan Shipped, freeze it.

### Tier 2

1. Steps are the same as Tier 1, with three differences.
2. One of the two reviewers owns the domain being touched.
3. The Tier 2 sections stay in: migration and rollout, security and compliance, phasing, deploy view, pre-mortem.
4. These usually enter as epics: Aris writes the epic (the what and why), the owning engineer writes the plan (the how) before decomposition, and child tickets are generated from the plan's Phasing section. Child tickets are Tier 0: they execute an approved plan.

### Spike

1. Spike ticket with the Spike label; the due date is the timebox.
2. Copy [`templates/spike-brief.md`](templates/spike-brief.md) to `plans/SOL-XXXX-spike-short-slug.md` and open a PR with Question, Candidates and criteria, Method, and Exit criteria filled. Both reviewers approve it the same day, before the clock starts.
3. Run it. Spike code is throwaway by default. Changes to the experiment go under Deviations.
4. Write Findings and a Recommendation. No sign-off on findings: the binding decision belongs to the Plan the spike seeds. A proceed recommendation spawns the follow-on ticket with needs-plan.

## How to approach the doc as an author

- Let Claude Code or Cursor research the codebase and draft every section, including all four views. Edit before sending; at review you answer for the content, whichever tool drafted it.
- Budget under an hour of your own time for a Tier 1 plan. A plan that takes a day to write is either too long or the wrong tier.
- Write for a five minute read. Reviewers start at the diagrams.
- Trade-offs accepted is the core section. Name the long-term property you are protecting, what you give up for it, and the condition that triggers a revisit.
- Mark a view N/A with a reason when it does not apply. Forced diagrams help nobody.
- If there are no open questions, write none.
- You drive the loop end to end: pick reviewers, chase the 24 hours, book the call, land the sign-off, keep the decision log current through the build.

## How we collaborate on it

- Review is async by default, in comments on the plan PR. SLA: 24 hours, every tier.
- One async round. If a thread goes back and forth twice, the author books 15 minutes, settles it live, and records the outcome in the decision log.
- Anyone on the team can read and comment on any plan. Only named reviewers sign.
- Reviewers read in this order: the four views, then Trade-offs accepted, then What exists today checked against your own knowledge. If an existing service or util covers part of the plan, name it.
- Blocking is reserved for correctness, security, and cost. Taste disagreements become a comment plus a decision log entry, and the author decides.
- Disagree-and-commit is a normal outcome. The log records who held what position; that record is what the log is for.
- A reviewer who spots a missed trigger bumps the tier. The author swaps the domain owner in as one of the two reviewers, keeps the Tier 2 sections in, and the 24 hour clock restarts.

## What sign-off means

Sign-off is both named reviewers approving the plan PR, mirrored in the plan's Sign-off table. The merged plan is Approved, and the ticket passes Definition of Ready.

**Approve means**

- The approach is sound and I understand it.
- The trade-offs are acceptable for the horizon stated.
- I checked the views and What exists today against my own knowledge of the system.

**Approve does not mean**

- The outcome is guaranteed, or every implementation detail is pre-approved.
- The plan cannot change. It can; that is what the decision log is for.
- The reviewer takes over accountability. The author keeps the build; the reviewer shares the direction.

**After sign-off.** Small deviations during the build get a decision log entry, committed to the plan file. A material deviation (a trigger now applies, a trade-off changed, the approach is different) re-opens sign-off: log it and re-ping the approvers. When the work ships, the plan freezes as a point-in-time record; later changes get their own plan.

## Linear mechanics, in one place

- needs-plan label (renamed from adr) marks plan-tier work; the plan PR link sits in the ticket description.
- Definition of Ready gains one condition: a needs-plan ticket is committed at Monday planning only when its plan is Approved.
- No new statuses. Plan writing and review happen while the ticket sits in Backlog or Todo.
- Spike tickets keep the Spike label; the due date is the timebox; the brief PR link goes in the description.
- cursor:ready goes on a needs-plan ticket only after the plan is Approved. For plan-tier work, an approved plan is what "spec is complete" means.
- Optional saved view for Monday planning: label needs-plan, status Backlog or Todo.

## Keeping it honest

- Expected mix: most plans are Tier 1, roughly one in ten is Tier 2. Tier 2 above a quarter of all plans means the trigger list has crept; raise it at retro. Zero Tier 2 for a month while schema PRs merge means the gate is being dodged; raise that too.
- A plan that reads like pseudo-code gets sent back for length. The program should be written once.
- At retro we look at two numbers: review turnaround, and direction changes caught in review. Ten plans in a row with no direction change means reviews have gone quiet; say so.
