# SOL-XXXX: Experiment title

> [!NOTE]
> **How to use.** For controlled comparisons of output quality, copy this file to `plans/SOL-XXXX-experiment-short-slug.md`, fill through Decision rule, and get same-day approval from two reviewers before the first run. Experiments stay sandboxed and never change what clients see. See the [Process Guide](../README.md). Delete this block in your copy.

| | |
|---|---|
| **Ticket** | SOL- |
| **Author** | @ |
| **Reviewers** | @ / @ |
| **Timebox** | 1 to 5 days |
| **Run pin** | Code commit, dataset version, model/config, and repeats or seed |
| **Status** | Proposed / Running / Done |

## Hypothesis

*Name the change, expected effect, and decision it informs. If keep and drop lead to the same next step, skip the experiment.*

## Arms

*Compare control with one or more treatments. Change one variable per arm and keep everything else pinned.*

| Arm | What changes from control |
|---|---|
| Control | Current behavior, config pinned above |
| A: | |
| B: | |

## Test set

*Name the cases, sample count, and whether the set is development or held-out. Freeze it before the first scored run; log any change under Deviations and apply it to every arm.*

## Decision rule

*Pre-register who scores, how, and numeric keep/drop thresholds. Hide arm labels for human judgment and link ratings to the outputs in Results.*

- Scored by:
- Keep when:
- Drop when:
- Split or unclear:

## Deviations from the brief

*Append dated changes and why. An empty section means the experiment ran as approved.*

- YYYY-MM-DD: Change and reason

## Results

*Link the real outputs, record evidence per case, and add a summary row for the decision metric. Include spend and runtime when affected.*

| Case | Control | Arm A | Arm B |
|---|---|---|---|
| | | | |
| **Summary** | | | |

## Decision

*Keep, drop, or iterate using the pre-registered rule. Log any override under Deviations and name the landing point or follow-up.*

---

Kept changes ship through normal code review or seed a Plan when they trip a plan tier. Paste the results into [Verification](plan-template.md#8-verification) or [Alternatives rejected](plan-template.md#6-alternatives-rejected), and build the guarding Braintrust eval at ship time.
