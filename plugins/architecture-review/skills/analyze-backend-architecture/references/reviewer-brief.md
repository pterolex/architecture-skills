# Reviewer brief: skeleton

Use this when you split a review across reviewers (Step 2 of SKILL.md). Write one shared brief from the skeleton below, plus a slice note of a few lines for each reviewer. Reviewers start with no knowledge of the task, the codebase or this skill, so everything they need has to be in these two texts or in a file the texts point to. Fill in every bracketed part and delete sections that do not apply. A shared brief of one to two thousand words is normal for a large codebase, and one with several earlier reviews behind it can need twice that; most of it is sections 3 to 6, which only you can write, because they come from your preflight and measurements.

Save the brief and the slice notes somewhere outside the reviewed tree before you launch anyone, and give each reviewer the two paths.

---

## Shared brief

You are one of [N] parallel reviewers helping a lead review the architecture of a backend. [This is a first pass. | This is a follow-up pass: the code was last reviewed in depth on [date] at `[sha]`.] Your output is a list of **claims** for the lead to verify, not findings. The lead checks every claim against the code and drops what does not hold, so a precise claim is worth far more than a long list.

### 1. What is being reviewed

- Tree: `[absolute path]`, commit `[sha]`. Review exactly this commit.
- Stack: [language, framework, transport, data store, queue, the external systems it talks to].
- Size: [files and lines; units per layer; the largest areas by size].
- Domain: [two or three sentences: what the product does, who uses it, where money moves and where messages go out].

### 2. Ground rules

1. Change nothing: no edits, installs, test runs, network calls, or git commands that alter state. The only files you may write are your claims file and scratch files in your own scratch folder; both paths are in your slice note, outside the reviewed tree.
2. Do not change directory; use absolute paths and each tool's own path option.
3. Only the tree above is evidence about the code. [Other checkouts and old reports are history, not the current code.]
4. [Anything the user ruled out: the issue tracker, another report, a folder. Say "do not open, list or search" and name the paths exactly.]
5. Do not list or read any temporary or shared folder other than your own scratch folder: it can hold material from other reviews.

### 3. Environment traps

[Each trap you hit yourself in Step 1, with its workaround. Typical ones: a search tool that silently lacks a pattern feature, so a sweep returns zero; a shell wrapper that truncates output; no dependencies in the tree, and where an install that matches the lockfile is.]

### 4. Project conventions

[The house patterns, so that reviewers do not raise them as defects: how authentication and authorization are applied, where data access is meant to live, how transactions, queues and configuration are wrapped, which tests act as ratchets, which exceptions are deliberate, which files may not be edited without the owner's say.]

### 5. What is already known

[Where the earlier reports and fix trackers are, and how to search them for a file or class name. Then the known open items in one line each, with ticket ids.]

A known item is worth a claim only when the code shows it is still open, has got worse, or was wrongly marked fixed. Say which item it is.

### 6. Where new defects are most likely

[What changed since the last full review, and the commands that show it for a path, for example `git -C [tree] log --oneline [last-reviewed-sha]..HEAD -- [path]`.] Code written or moved since then has had no review, so read it first: a fix that introduced a new defect, a new entry point that skips an existing owner, a refactor that changed behaviour silently.

Then read the flows in your slice that no earlier report has traced. [What earlier passes traced and found sound, in a line or two per area; or "earlier passes were structural, so no behaviour here has been traced".] Old code that nobody has traced is as likely to hold a defect as new code. Do not spend your budget proving again what an earlier pass already traced.

### 7. What to look for

Behaviour first; these usually produce the findings that matter.

1. **Rule Ownership.** A business rule decided in more than one place. Compare the copies line by line and report the differences.
2. **Unguarded Door.** A rule with a correct owner that some path to the effect bypasses: a route, a webhook, a job, an admin action, a script.
3. **State Transitions.** A status written from many places; a transition that skips a side effect the same transition performs elsewhere; a terminal state that can be left; a state nothing ever writes.
4. **Retry/Concurrency Safety.** Webhooks, jobs and schedules run more than once and in parallel: idempotency, claim before work, what a `catch` writes after a partial success, an external call inside a transaction, a commit followed by an enqueue that can be lost.
5. **Unowned Default.** A framework default nobody pins: validation, serialization, queue options, timeouts, retries, shutdown.
6. **Forked Twin.** Two variants built by copying; the same rule with a different outcome on each.

Structure second: SLA Violation (mixed abstraction levels), Layering Violation (business logic in transport, data access outside the data layer), Leaky Boundary (transport or persistence types passed inward), Missing Data Abstraction, Hidden Dependency, Cross-Cutting Duplication, Poor Module API. A structural problem with no behavioural consequence is Low.

Give each claim one principle, by these names: the one whose fix closes the claim.

**Severity** follows consequence, not the principle broken:
- High: on an ordinary path in production, money is lost or duplicated, a legal or consent commitment is broken, another tenant's data is exposed or corrupted, or the service goes down. An ordinary path is what a customer, a business user or a staff member does in the normal course of using the product, deliberate acts included, or a job or webhook doing its routine work.
- Medium: a wrong result or a failure that is contained, recoverable, or arises only under an unusual condition. A consequence from the High list that needs a fault, a race, a script run by hand, or a flag or release production does not have yet is Medium; say what would make it High.
- Low: no wrong behaviour on any path.

If you can name who gets a wrong result and what it is, the claim is at least Medium, however rare the trigger and whether it is live or latent. Do not rate a real wrong result Low because it needs a lost response, a double submit or an odd but permitted act. Two cases are High that reviewers often rate Medium: a business user turning a client's own opt-out back into consent, and one tenant reading another tenant's records through an id it types.

**Reachability**, checked rather than assumed, and stated separately from severity:
- live: the code is on the production branch (`[name]`), any flag or allowlist it sits behind is on there, and the state that triggers it can arise through the product itself. Name the writer of that state.
- latent: one of those three does not hold today. Say which, and what would make it live. When you cannot see a flag's production value, go by its default in the code and say so.
- test-only.

[How to check against production when the reviewed branch is ahead of it: `git -C [tree] show [production]:[path]`, or `git -C [tree] grep -n '<a decisive line>' [production] -- [directory]` when the code has moved.]

### 8. What to return

Write at most [8 to 12] claims to your claims file, strongest first, each in this shape:

```
### CLAIM [your id]-NN: one-line title
- Severity: High | Medium | Low (for a Medium that would be High, add what would make it High; for one whose wrong result is minor and cheap to put right, add "low end")
- Principle: [one of the names in section 7]
- Location: path:line, and the other sites
- Code: the 5 to 15 decisive lines, quoted exactly
- Consequence: what goes wrong, for whom, in which concrete scenario
- Path: entry point → … → effect, each hop as path:line
- Reachable: live | latent | test-only, and what you checked for each of the three conditions
- Already tracked: ticket or earlier item, or "no; searched [which files] for [which terms]"
- Not checked: the guard, dedupe, lock, constraint or library behaviour you did not look for
- Suggested fix: one or two lines in the project's own patterns
- Done when: one checkable condition, with the test that would catch a regression
```

End the file with three short sections: **Found sound** (invariants that hold in your slice, each with the sweep or reading that showed it), **Not covered** (what in your slice you did not get to) and **Sweeps run** (the exact patterns and their counts, so the lead can repeat them).

Then reply to the lead in under 150 words: how many claims at each severity, and the one you are least sure of. The detail belongs in the file.

How to work:
- Check before you write. Open the file at the line, follow the call path one level up and one down, and look for the obvious thing that would make the claim false. For a library's or provider's default behaviour, read the installed source or the documentation and cite it; otherwise write "not confirmed".
- Confirm any zero-hit search against a known positive, and read a sample of the hits of any search you count.
- Quote real code. No comments on formatting, lint or naming, and no "consider improving".
- If your slice is sound, say so. Three solid claims beat twelve guesses, and "nothing new here, and this is what I checked" is a complete answer.
- Plan for about [15] minutes of reading, or roughly a hundred tool calls. You are finding candidates; an independent checker goes deep on the ones that matter. Stop when you have your strongest claims; a wider trawl costs more than the lead can verify.
- Read narrowly and in batches: open the line range you need instead of a whole large file, and send independent searches and reads together in one step. Every step re-reads everything you have opened so far, so a few full steps cost far less than many small ones.

---

## Slice note (one per reviewer)

```
Reviewer id: [two letters]
Lens: [name]
Your slice: [directories, with lines of source; about 25,000 to 30,000 lines in all]
Start here: [directories or files, newest and never-traced first]
Your questions:
- [three to six questions specific to this lens and this codebase]
Also yours: [for one reviewer only: give each item of the previous report a status with evidence; read the offender lists of the lead's sweeps]
Claims file: [path]
Scratch folder: [path, one per reviewer]
```
