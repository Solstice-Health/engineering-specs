# SOL-XXXX: Experiment title

> [!NOTE]
> **How to use.** For controlled comparisons of output quality: a prompt, context, model, or pipeline change, run as arms over a fixed test set. Copy this file to `plans/SOL-XXXX-experiment-short-slug.md` and open a PR with every section above Deviations filled. Two reviewers, same-day sign-off, before the first run: the decision rule only counts as pre-registered while no results exist. Experiment code and config are throwaway by default, and an experiment never changes what clients see. See the [Process Guide](../README.md). Delete this block in your copy.

| | |
|---|---|
| **Ticket** | SOL- |
| **Author** | @ |
| **Reviewers** | @ / @ |
| **Timebox** | 1 to 5 days |
| **Environment** | Sandbox or branch, plus the pinned model and agent config |
| **Status** | Proposed / Running / Done |

## Hypothesis

*The change, the effect you expect, and the decision this feeds, a sentence each. "Golden examples in context bring banner output closer to the brand's approved look" is a hypothesis. "Let's see what golden examples do" is exploration; explore freely off the books, then come back with the claim you now believe. If keep and drop lead to the same next step, skip the experiment.*

## Arms

*Control plus one or more treatments. One variable moves per arm; everything else stays pinned, the model included. A comparison where two settings changed at once answers neither question: add an arm or cut a variable.*

| Arm | What changes from control |
|---|---|
| Control | Current behavior, config pinned above |
| A: | |
| B: | |

## Test set

*Real inputs, named here before the first run: which brands, which briefs, how many cases. Every arm runs the full set at the same volume. A case added mid-run gets added to every arm.*

## Decision rule

*Who scores, how, and the thresholds, written before the first run and in numbers where possible. One person eyeballing side by side is a valid method at this stage; the rigor lives in the fixed test set and the pre-registered thresholds, and scored eval packs belong at the ship gate. When more than two people should weigh in, run a blind vote in Slack: same brief, outputs paired, voters pick without knowing which arm made which. Record ratings as they land, tied to the output links in Results. "Keep generic examples if we would pick them over control on at least 16 of 24 outputs" is the shape.*

- Scored by:
- Keep when:
- Drop when:
- Split or unclear:

## Deviations from the brief

*Appended while running, one line each with a why: an arm added or dropped, a test case swapped, the rule reworded, the timebox extended, the model moved underneath you. An empty section claims the experiment ran exactly as approved.*

- *Example: 2026-08-21, dropped arm B after 4 of 24 runs: renders crashed on every Ibsrela case; the treatment needs a fix before it can be compared.*

## Results

*Appended when the runs finish. Link the real outputs; a reviewer should be able to open any cell. One row per case, one column per arm, ratings or short evidence in the cells, no adjectives. Add spend and runtime per arm when the change moves cost.*

| Case | Control | Arm A | Arm B |
|---|---|---|---|
| | | | |

## Decision

*Keep, drop, or iterate, read off the pre-registered rule. The rule can be overridden with a written why, logged under Deviations. On keep, name where the change lands; on iterate, the follow-up experiment gets its own brief.*

---

Experiments feed decisions: a kept change that stays contained ships through normal code review; a kept change that trips a plan tier seeds that Plan, with the results table pasted into its [Verification](plan-template.md#8-verification) or [Alternatives rejected](plan-template.md#6-alternatives-rejected) section. The Braintrust eval pack that guards it in CI gets built for the change we keep, at ship time.
