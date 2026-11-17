# Report template and writing rules

Read this when you reach Step 7 of SKILL.md. The main report goes in `BACKEND_ARCHITECTURE_REVIEW_RESULTS.md` in the root of the tree you reviewed. Whatever does not fit the limits below goes in `BACKEND_ARCHITECTURE_REVIEW_APPENDIX.md` beside it, so nothing is lost and the main report stays readable.

## What goes where

A report is a ranked selection, not an inventory. The reader files tickets from it, and a finding buried in row 47 of a table does not get fixed.

- **Full issues: at most twelve, and fewer when the main report would otherwise pass 500 lines.** Ten usually fit. Every High, then the Mediums that would be High once a condition holds and the live Mediums with the largest consequence.
- **Short findings: about twenty-five to thirty rows in the main report, ranked.** Every remaining High, then the Mediums not marked low end, most consequential first: those that would be High once a condition holds, then the other live ones, then the latent ones. Fill any room left with the Lows most worth doing. When the Mediums alone would pass thirty rows, move the latent ones to the appendix too, and say so above the table.
- **Appendix:** the findings the main table has no room for, ranked the same way (latent Mediums moved for room, then the Mediums marked low end, then the Lows); the exact command or script behind each measurement; and the previous-report status rows when there are more than about fifteen of them (keep a count per status in the main report). An appendix row may be marked † (not re-read); a row in the main report may not.
- **Target length for the main report: under 500 lines.** When it runs over, shorten the code excerpts and move rows to the appendix before you cut an issue.

Say in the header how many findings are in the appendix.

## Counting rules for the header

Use these definitions, so that the numbers mean the same thing on every pass:

- **raised**: claims returned by reviewers, or noted by you when working alone. Status rows for the previous report are not claims.
- **merged**: claims removed because another claim describes the same defect. raised − merged = distinct.
- **already known**: distinct claims already recorded in an earlier report or the tracker. They stay in the report, cited, when the code shows they are still open or worse.
- **dropped**: distinct claims refuted on checking. A claim that turned out narrower than stated is not dropped; report it as it actually is.
- **reported**: distinct − dropped. This equals full issues + short findings + appendix findings.
- **depth**, which splits the reported findings three ways with no overlap:
  - *traced*: followed from an entry point to the effect, with a search for whatever would make it false, by you or by an independent checker;
  - *re-read*: the decisive lines opened at the cited place, with enough of the code around them to see that they do what the claim says. It covers the lines the claim rests on, not every site it lists. A script that confirms each quoted line sits at the cited place is a useful first pass and not a substitute;
  - *not re-read*: taken on the reviewer's word. Appendix only.
- **severity counts**: each finding counts once, at the severity it is given, with the latent and low-end ones shown in brackets: "3 High, 40 Medium (12 latent, 15 low end), 6 Low (2 latent)". A Medium that would be High once a condition holds counts as Medium.

Marks to use anywhere a finding is listed: **†** not re-read (appendix only); **‡** re-read, but its conclusion rests on something nobody confirmed: a second site nobody opened, the behaviour of a library or provider, a production setting, a product decision. A site the claim only mentions does not earn ‡. A finding marked ‡ says what that something is.

## Main report

```markdown
# Backend Architecture Review Results

> Analyzed on: [date]
> Project: [name], [branch or "detached"] at `[commit SHA]`; production branch `[name]`[; remote is N commits ahead, not reviewed because …]
> Stack: [language, framework, data store, queue]
> Pass: [first | follow-up to the report of [date] at `[SHA]`]
> Units in tree: [N controllers, N services, N repositories, N processors]
> Coverage: [swept across the whole tree: …. Read in full: …. Not read: … (details under Not covered)]
> Claims: [N raised, N merged, N distinct, N already known, N dropped, N reported] · [N traced, N re-read, N not re-read]
> Findings: [N full issues, N short findings, N more in the appendix] · [N High, N Medium (N latent, N low end), N Low (N latent)]

## Summary

[Three or four sentences. The first sentence is the finding with the largest consequence, stated as what goes wrong. Then the pattern behind the findings, if there is one. What is sound belongs in its own section, not here.]

## Status of the previous report        (follow-up passes only)

| Item | Title | Status | Evidence |
|------|-------|--------|----------|

Status is one of: Fixed, Partly fixed, Open, Worse, Moot, Accepted (a documented, deliberate exception). One line of evidence each: a commit, a file and line, or what remains. Correct any statement of the previous report that you now know to be wrong.

## What was checked and found sound

[Short bullets naming the invariants that hold, each with the sweep or reading that showed it.]

## Issues

### ISSUE-01: [Short title that says what goes wrong]

**Severity**: High | Medium | Low  [for a Medium that would be High on an ordinary live path: "Medium (High once <condition>)"]
**Principle**: Rule Ownership | Unguarded Door | State Transitions | Retry/Concurrency Safety | Unowned Default | Forked Twin | SLA Violation | Layering Violation | Leaky Boundary | Missing Data Abstraction | Hidden Dependency | Cross-Cutting Duplication | Poor Module API
**Location**: `path/to/file.ext:line` [and the other sites]
**Reachable**: live | latent | test-only: [the path from an entry point to the effect; for live, that the code is on the production branch, that no flag gates it, and what writes the triggering state; for latent, which of those is missing]
**Verified**: traced by [the lead | an independent checker] | re-read. [If it rests on a library's or provider's behaviour: "confirmed in `<installed file:line>`", "confirmed in <documentation page>", or "not confirmed: <what>".]
**Already tracked**: [ticket id, or "no"]

[One or two sentences on the consequence: what goes wrong, for whom, how often. If the size of the effect was estimated and not measured, say so.]

#### Current

[5–15 lines of the project's real code showing the problem]

#### Recommended

[5–15 lines showing the fix in the project's own stack and patterns]

**Done when**: [one or two checkable conditions, including the test that would catch a regression]
**Touches**: [shared or schema files the fix needs, and any decision the owner must make first]

---

## Short findings

One row each, ranked as "What goes where" says, most consequential first; the Module column lets a reader pick out one area. The Severity cell gives the severity, then the reachability, in the same words as a full issue; a low-end Medium is written "Medium (low end), live".

| ID | Severity | Module | Location | Finding | Fix | Tracked |
|----|----------|--------|----------|---------|-----|---------|
| F-01 | Medium, live | billing | `path:line` | [what goes wrong, one sentence] | [the fix, one sentence] | [ticket or "no"] |
| F-02 | Medium, latent (`<flag>` defaults to off) | messaging | `path:line` | [what goes wrong; for a library default, where it was confirmed] | [the fix] | [ticket or "no"] |

## Not covered

[What no reviewer or sweep got to, so the next pass knows where to look.]

## Measurements

| Measure | Previous | Now | How counted |
|---------|----------|-----|-------------|

[At least eight measures. "Previous" is the earlier report's figure, or your own recount of the earlier commit when its method is unknown (put the report's figure in brackets), or "none". The exact command or script for each row is in the appendix.]

## Recommendations

| Priority | Issue | Effort | Impact |
|----------|-------|--------|--------|

## Architecture Health Score

| Criterion | Score (1–5) | Previous | Basis |
|-----------|-------------|----------|-------|
| Rule ownership and enforcement | | | |
| Retry, concurrency and state safety | | | |
| Single Level of Abstraction | | | |
| Layer separation | | | |
| Boundary discipline | | | |
| Data and external access abstraction | | | |
| Dependency injection and testability | | | |
| Cross-cutting concerns | | | |
| Duplication | | | |
| **Overall** | | | |

[Every Basis cell names a measure from the table above or issue ids. Overall is the mean of the nine criteria to one decimal. Where the previous report did not score a criterion, Previous is "n/a"; if its criteria differ from these, also give the mean over the criteria both reports share.]
```

Which principle counts under which criterion, so that each issue is counted once:

| Criterion | Principles |
|-----------|------------|
| Rule ownership and enforcement | Rule Ownership, Unguarded Door |
| Retry, concurrency and state safety | State Transitions, Retry/Concurrency Safety |
| Single Level of Abstraction | SLA Violation |
| Layer separation | Layering Violation |
| Boundary discipline | Leaky Boundary, Poor Module API |
| Data and external access abstraction | Missing Data Abstraction |
| Dependency injection and testability | Hidden Dependency |
| Cross-cutting concerns | Unowned Default, Cross-Cutting Duplication |
| Duplication | Forked Twin |

## Appendix

```markdown
# Backend Architecture Review: Appendix

> Belongs to the report of [date] at `[commit SHA]`.

## Further findings
[Same columns as the short-findings table, ranked the same way: Mediums moved here for room, then the Mediums marked low end, then the Lows. Mark † any row that was not re-read.]

## How each measure was counted
[The command or script for every row of the measurements table, so the next pass can rerun it unchanged.]

## Previous-report status, in full        (only when moved here)
```

## Writing issues

- **Use the project's real code.** The developer should recognise it. Shorten with `// ...`.
- **Keep the fix realistic.** Use the stack and patterns already in the project.
- **One problem per issue.** If one unit has two problems, write two issues.
- **Make each issue fileable.** A reader should be able to paste one issue into a tracker and start work. A short finding gets the same treatment in one row: where, what goes wrong, the fix, how severe, whether it is tracked.
- **Separate facts from decisions.** If the right behaviour is a product or business choice, state the options and what each costs instead of picking one silently.
- **Say what you did not establish.** An effect you estimated, a production fact you could not see, a library behaviour you could not confirm: write it in the issue. Go back to the claims and checks files for each finding as you write it, and carry over whatever they list as not checked.

## Tone

Direct and constructive, like a senior colleague. Say what to do and why. Avoid "consider improving".
