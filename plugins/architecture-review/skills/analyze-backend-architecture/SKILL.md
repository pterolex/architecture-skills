---
name: analyze-backend-architecture
argument-hint: <path-to-repository>
disable-model-invocation: true
user-invocable: true
description: Review a backend's architecture for rule ownership, layering, boundary discipline, job and transaction safety, and duplication. Verifies every finding against the code, supports follow-up passes against an earlier report, and writes a ticket-ready report.
---

# Analyze Backend Architecture

You are reviewing the architecture of a backend project (REST, GraphQL, gRPC, or a background-worker service). The output is a report a developer can act on: every finding is checked against the code, ranked by what it breaks, and written so it can be filed as a ticket without rework.

The skill is framework- and language-agnostic. Translate the terms to the project's stack: "controller" ≈ route handler ≈ resolver; "service" ≈ use case ≈ interactor; "repository" ≈ DAO ≈ data mapper; "gateway" ≈ client ≈ adapter for an external system.

## What a good review finds

A review that only checks whether files sit in the right layer runs dry quickly and misses the defects that cost money. The findings that matter most are usually about **behaviour that has no single owner**. Look for both kinds, and lead the report with whichever has the larger consequence.

### Structural principles

1. **Single Level of Abstraction.** Each unit works at one level. A controller orchestrates service calls; a service composes domain operations; a repository composes data-access primitives. A unit that mixes `orderService.create(...)` with a raw SQL string, or `paymentGateway.charge(...)` with hand-parsing an HTTP response, needs restructuring. The test: can you say what the unit does in one sentence using only the names of the things it calls?

2. **One-directional layers.** Transport (parse the request, call a service, shape the response) → business (rules and orchestration) → data access and gateways (all communication with the database, cache, queue, and third parties). The two common violations are business logic in the transport layer and data access in the business layer.

3. **Boundary discipline.** Transport types (`req`, `res`, headers, status codes) stop at the controller. Persistence types (ORM entities, raw rows, raw API payloads) stop at the repository or gateway. Business code throws typed domain errors; only the boundary maps them to status codes. Every external dependency sits behind one boundary unit with its dependencies passed in, so it can be replaced in tests. Use whatever form is idiomatic for the stack: an injected class in NestJS or Spring, an interface in Go, a module of functions taking a client in functional codebases.

4. **Explicit dependencies.** Dependencies are injected, not reached for through globals, module-level singletons, scattered environment reads, or direct reads of the wall clock and random source inside business logic.

5. **Minimal structural duplication.** Extract when the orchestration shape, query, or rule is the same, not when two snippets merely look alike. Cross-cutting concerns (auth, validation, error mapping, rate limiting, logging) belong in middleware, guards, or interceptors.

### Behavioural principles

6. **One owner per business rule.** A rule (who may refund, when a slot is free, what counts as paid, how a phone number is normalised) should be decided in exactly one place. A rule copied into several services drifts, and the drift is a live defect. When you find a copy, compare the copies line by line and report the differences, not just the duplication.

7. **Enforce at the only door.** A rule with a correct owner is still broken if callers can reach the effect without passing through it: a check at compose time but not at send time, a guard on one of five entry points, a validator on the REST route but not the queue consumer. For each important rule, find every path to the effect and confirm each one passes the check. Prefer fixes that put the rule on the single unit every path must use.

8. **Explicit state transitions.** Entities with a status field need one place that says which transitions are legal. Look for status writes scattered across services, transitions that skip side effects, terminal states that can be left, and states nothing ever writes.

9. **Safe under retry and concurrency.** Webhooks, queue jobs, and scheduled tasks run more than once and in parallel. Check idempotency keys, claim-before-work, what a `catch` block writes after a partial success, transaction boundaries that include or wrongly exclude an external call, and awaited side effects on the request path that should be queued.

10. **Framework defaults have an owner.** Validation pipes, serializers, queue options, HTTP client timeouts, retry policies, and shutdown behaviour all have defaults that silently shape behaviour. Where the code depends on a default, something (a test, a wrapper, a base class) should pin it.

11. **No forked twins.** When a second variant of a feature is built by copying the first (a second tenant type, a second payment rail, a v2 endpoint), the two halves drift. Measure the overlap, list the drifts, and say which side is correct for each.

## Severity and reachability

Every claim, check and report line carries both, stated separately: "High, live", "Medium, latent until `dev` is released". Reviewers get these two wrong more often than they misread the code, and in both directions, so settle them deliberately rather than carrying a first impression into the report.

**Severity** follows the consequence, not which principle is broken.

- **High:** on an ordinary path in production, money is lost or duplicated, a legal or consent commitment is broken, another tenant's data is exposed or corrupted, or the service goes down; or a structural problem so widespread it blocks safe change across the codebase.
- **Medium:** a wrong result or a failure that is contained, recoverable, or arises only under an unusual condition; or a structural problem that makes one area hard to test or change.
- **Low:** no wrong behaviour on any path; the change would improve clarity or lower the chance of a future mistake.

Three tests settle most borderline cases:

- **High or Medium?** An ordinary path is something a customer, a business user or a staff member does in the normal course of using the product, or a job or webhook doing its routine work. A deliberate act counts: if any business user can do it from their own account, the path is ordinary, and a money or consent consequence on it is High. When a consequence of that kind needs more (a fault such as a lost response or a crash between two writes, a race, a maintenance script someone must run by hand, or a flag or release that production does not have yet), the finding is Medium and says what would make it High. Two cases are High that leads often rate Medium: a business user turning a client's own opt-out back into consent from their own account, and one tenant reading another tenant's records through an id it types, even when the records look harmless.
- **Medium or Low?** Name the wrong result: who gets it, and what it is. If you can, the finding is Medium, however rare the trigger and whether it is live or latent; "arises only under an unusual condition" is part of what Medium means. A second receipt after a double click, or a reminder sent twice after a lost response, is still Medium, at the low end of the band (below). Low is for a finding where nothing wrong happens on any path: a missing audit row when the same act is logged elsewhere, a rule held in two lists that still agree.
- **Measured or estimated?** If the size of an effect comes from reading the code and not from a measurement or library source, say so in the finding.

**The low end of Medium.** Medium covers a lot, and on a large pass most findings can land in it. Mark the ones at the bottom of the band "Medium (low end)": the wrong result is minor, and whoever meets it can put it right at little cost (a duplicate message, a raw error where a typed refusal belongs, one missed reminder, a figure shown wrong that nobody acts on). It is still a Medium. The mark only decides where the finding goes in the report, so that the main report leads with the Mediums that matter (`references/report-template.md`).

**Reachability** is whether the defect can fire in production today. It is checked, not assumed.

- **live:** the code is on the production branch, any flag, allowlist or setting it sits behind is on there, and the state that triggers it can arise through the product itself. Find what writes that state; a precondition nothing in the application can create is not live.
- **latent:** one of those three does not hold today. Say which, and what would make it live.
- **test-only:** nothing outside the tests reaches it.

When you cannot see a flag's value in production, go by its default in the code and say so: "latent (`X` defaults to off; its production value was not read)".

When the branch under review is not the production branch, check each finding against production's own copy of the code: `git show <production>:<path>` for the cited lines, or `git grep -n '<a decisive line>' <production> -- <directory>` when the code has moved since. A defect present there in the same form is live; one that exists only in the reviewed branch is latent until that branch ships. A diff between the branches does not answer this after a refactor, because it marks every moved file as changed.

The report ranks by both: Highs first; then the Mediums that would be High once a condition holds, together with the other live Mediums, by the size of the consequence; then the latent Mediums; the low-end Mediums and the Lows last.

## How the work is divided

On a small project you do every step yourself. On a large one, when you can run subagents, there are three roles:

- **You, the lead**, do the preflight, the measurements, the plan and the briefs (Steps 0 to 2), then merge, check and write (Steps 5 to 7). You read little code beyond what checking needs. Your context is the scarce resource of the whole run, so have reviewers and checkers put their detail in files and reply with a summary.
- **Reviewers**, one lens each, do Steps 3 and 4 inside their lens. They return claims, not findings.
- **Checkers** are fresh readers that try to refute the claims that matter most (Step 5).

Reviewers find; checkers prove. Ask reviewers for breadth: about fifteen minutes of reading each and their strongest eight to ten claims. Spend the depth in Step 5, on the claims that will lead the report. On a large codebase a reviewer kept to that budget ends at about 500,000 tokens as the agent tool reports them, a checker at 400,000 to 500,000 for four claims, and your own session at about 700,000. Seven reviewers and four checkers therefore come to about six million tokens and an hour and a half from start to finish; ten and four, which is what the sizing rule in Step 2 gives a codebase of 200,000 lines, come to nearly eight million and an hour and three quarters. A smaller codebase needs fewer of both. A reviewer left to read until it is certain of everything costs half as much again and finds little more. Before you launch, say in one line what the pass will cost, so the user can ask for a smaller one; when nobody can be asked, write that line in your notes and go on.

## Workflow

### Step 0: Preflight

Before reading any code:

- **Pin what you review.** Record the branch and commit SHA; for a detached HEAD, find which remote branch contains the commit. See whether the remote has moved, without changing anything when you can (`git ls-remote`); fetch only when a read-only run is not required. If the checkout is behind, say so and review the up-to-date commit. The exception is a commit the user has pinned on purpose: review exactly that one, and when you reconcile in Step 6 list the files that newer commits touch, by name only.
- **Find the production branch** (the default branch, the deploy configuration, or the user's word). You need it to judge reachability.
- **Find the previous report.** It is the `BACKEND_ARCHITECTURE_REVIEW_RESULTS.md` in the tree root, or the one the user names. If there is one, this is a **follow-up pass**: read it fully and list every item in it, full issues and short findings alike. Those items, and only those, get a status in Step 6. Older reports are history, and their open items are the tracker's business. If the previous report was a partial pass that carried nothing forward, say in one line where the older open items are recorded rather than re-checking them all; a full re-status of old reports is a separate job the user can ask for. In that case there are two baselines, so find the last full review and its commit as well: "what changed since" is counted from the last full review, while the statuses and the Previous column of the measurements belong to the previous report, even when its commit is the older of the two. Name both in the header, and put your recount of the last full review's commit in the appendix.
- **Find the tracker and earlier material** (older reports, fix logs) and note the paths for the brief, so findings already tracked are cited instead of raised again. If the user has ruled the tracker out, take ticket ids from the earlier reports and say their states may be stale.
- **Choose where to work.** If the checkout is clean and on the pinned commit, or the user has told you to review it in place, review it in place. If it has uncommitted changes, is behind the remote, or is in use by someone else, do not disturb it: create a separate worktree at the pinned commit and review there. If the earlier report exists only as an uncommitted file in the checkout, copy it somewhere safe first.
- **Check the dependencies.** Claims about a library's defaults need its installed source. If the review tree has none, look for an install elsewhere on the machine that matches the lockfile, and compare package versions by script over the whole lockfile before trusting it, because a nearby install is often stale. Failing that, install in the review tree, or record that such claims could not be confirmed.

Do not change directory into other repositories or worktrees; use absolute paths and each tool's own path option.

### Step 1: Map and measure

Map the layout: transport, business, data access, gateways, jobs and consumers, cross-cutting pieces, the entry points, how dependencies are wired, and how configuration is loaded.

Then take measurements you can repeat on the next pass. Count them with a script or search, not by impression:

- units per layer (controllers, services, repositories, job processors) and non-test file count
- data-store access outside the data layer (files and call sites)
- direct third-party SDK or HTTP calls outside gateways
- environment reads outside the config module
- direct clock reads in business code versus injected clock use
- functions over a length threshold (state the threshold)
- entry points lacking a cross-cutting control the project uses elsewhere (write down which guards or decorators you counted as that control)

Three cautions on sweeps. A pattern feature the search tool lacks returns zero hits and looks like a clean result, so confirm each sweep against one known positive. A pattern can also match too much, and a list of file names does not show it, so open one hit in each file the sweep names before you count it. And when the project wraps a primitive (its own transaction runner, its own queue registration), sweep for the wrapper as well.

Keep every command or script. They go in the report's appendix so the next pass can rerun them unchanged, which is the only way the numbers stay comparable. When the previous report's method is unknown and its commit is cheap to recount with your own script (`git archive <sha>` into a scratch folder), do that, and show the report's own figure in brackets.

### Step 2: Plan the reading

- **Small project (under about 150 source files):** read every controller, service, and repository yourself.
- **Larger project, working alone:** do not sample at random and do not claim full coverage. Run the sweeps from Step 1 over the whole tree, read every offending unit in full, and read every unit on the paths traced in Step 4. State in the report what was swept and what was read.
- **Larger project with subagents:** split the review across parallel reviewers, usually five to seven and up to ten on a very large codebase. Slice by flow, so that every part of the tree belongs to exactly one reviewer and each reviewer asks both the behavioural and the structural questions of its part:

| Lens | What it covers |
|------|----------------|
| Money | payments, refunds, payouts, subscriptions, entitlements and limits, and the transactions and locks on those paths |
| Core lifecycle | the product's central entity (orders, bookings, accounts): creation, change, cancellation, every status write, and the long units where that happens |
| Messages and consent | every path that sends something to a person (email, SMS, chat, push), opt-out and consent, templates, and the sweeps that send |
| Asynchronous work | webhooks, queue processors and schedules: idempotency, claims, retries, shutdown, and what a failure leaves behind |
| Edges | transport, authentication, authorization and tenant scoping, validation; gateways to external systems, their timeouts and error handling; configuration and framework defaults |
| Structure and status | the offenders your layering sweeps found, the module graph and injection, duplication; the status of each item of the previous report |

Fit the lenses to the domain: drop one the product has no use for, merge two small ones, and add a lens for a forked variant (a second tenant type, a second payment rail) or for a large product area that sits outside these flows (a content studio, an ads manager, reporting).

Then size the slices against the map from Step 1. A reviewer on the budget above covers roughly 25,000 to 30,000 lines of source. A slice two or three times that size comes back with most of it unread, so split it by sub-area and give each part its own reviewer. Stop at ten reviewers: past that you cannot merge and check what comes back, so leave the least risky areas out and list them under Not covered.

The last lens in the table owns no directories. On a small or medium codebase it is one reviewer's whole job. On a large one, where every reviewer is needed for a slice, give the status rows to the Edges reviewer, read the offenders of your own sweeps yourself, and say under Not covered what structural reading nobody did (the module graph, measured duplication).

Write the brief from `references/reviewer-brief.md`, which is a skeleton with the sections a reviewer needs and the shape of a claim. Tell every reviewer where to start: first the code changed since the last full review, which nobody has reviewed; then the flows in its slice that no earlier report has traced. An earlier report's findings and its "found sound" list show what was traced. Where the earlier passes were mostly structural, most behaviour has never been traced, whatever its age, and that is where the defects are. Have each reviewer write its claims to a file you name and reply with a short summary, and give it the reading budget above. Launch them together.

Reviewers must not change the tree, but they do have to write a claims file, so a read-only agent type usually cannot be used. Rely on the brief's ground rules, and check the tree when each wave returns (its status, its HEAD, and the previous report's checksum if that file is uncommitted).

Give every reviewer and checker a scratch folder of its own outside the tree, and name it in the brief. Before you launch, look at where subagents write by default: a shared temporary folder can hold material from other runs or other reviews, and nobody on this pass should list or read it.

### Step 3: Structural review

Reviewers do this step and the next inside their lens; working alone, you do them yourself. For the units read:

- **Controllers and handlers:** do they parse, call one service, and shape the response? Flag business rules, multi-step orchestration, direct data or SDK access, and request objects passed downward.
- **Services:** one abstraction level? Flag raw queries, direct HTTP or SDK calls, manual payload parsing, HTTP concepts, and services spanning several bounded contexts.
- **Repositories and gateways:** are they the only path to their store or external system? Do they return domain shapes or leak rows and raw payloads? Flag business decisions made inside them. For gateways, check that timeouts are set and that provider errors are classified into domain errors rather than surfacing as generic failures.
- **Module contracts:** domain types in and out, typed errors, no methods with six or more positional parameters or several boolean flags.
- **Cross-cutting:** authentication and authorization, validation, error mapping, rate limiting, logging, and transaction ownership each centralised, or re-implemented per handler?
- **Dependencies:** injected or reached for? Any cycles, or a lower layer importing an upper one?

### Step 4: Behavioural review

This step produces most of the high-severity findings. Do not skip it when Step 3 comes back clean.

1. **Start with what nobody has traced:** first what changed since the last full review (new entry points, new modules, fixes to earlier findings), then the flows no earlier report followed from entry point to effect.
2. **List the rules that matter.** From the domain, pick the ones where a mistake costs money, breaks a legal or consent promise, exposes another tenant's data, or sends something to a customer: payments and refunds, payouts, entitlement and limits, consent and opt-out, authorization and tenant scoping, outbound messaging, availability and booking, anything with a status lifecycle.
3. **Find each rule's owner and its copies.** Search for the rule's vocabulary. Where it is decided in more than one place, compare the copies and record each difference.
4. **Trace every door.** For each effect (money moves, message sends, record becomes visible), list all entry points that reach it: public and authenticated routes, admin routes, webhooks, jobs, scripts. Confirm each passes the owner's check. Ask also what can undo or stop the effect, and whether every party who should be able to has a door for it.
5. **Check lifecycles.** For each status field, find every write and judge whether the set of transitions is deliberate.
6. **Check retry and concurrency** on every webhook handler, job processor, and scheduled task that touches the rules above.
7. **Check framework defaults** the code leans on: validation of arrays and nested or undecorated fields, queue retry and repeat options, client timeouts, shutdown drain time.
8. **Check for forked twins** wherever two modules share a naming pattern or were added in one burst.
9. **Check configuration:** is there one definition of which settings are required in a deployed environment, or do optional settings silently disable features?

### Step 5: Verify every claim

Nothing enters the report on a first reading, whether it came from you or from a reviewer.

1. **Merge duplicates.** Two reviewers often reach the same defect from different lenses. Keep one claim, combine their evidence, and note that it was found independently. Where the two disagree on severity or reachability, read the gate or the guard yourself and settle it.
2. **Set aside what is already known.** A claim recorded in an earlier report or the tracker is cited, not re-raised, unless the code shows it is still open or worse.
3. **Check each claim to a depth that matches what rides on it.**
   - *Traced:* followed from an entry point to the effect, with a search for the guard, dedupe, constraint or wrapper that would make it false, and with reachability checked as defined above. Every finding reported as High needs this from an **independent checker**: a fresh reader briefed from `references/checker-brief.md` who has not seen the reviewer's reasoning and rates severity and reachability from scratch. You do not know which claims are High until they are checked, so send every claim that would be High as the reviewer describes it: a consequence from the High list on an ordinary live path, whatever rating the reviewer gave. A Medium that needs a fault, a race, a hand-run script or an unreleased flag before it could be High does not need a checker on that account. Add the Mediums most likely to become full issues. Four claims to a checker; on a large pass that is usually three or four checkers and twelve to sixteen claims. Trace any other finding you mean to write as a full issue yourself, starting from the entry point rather than from the reviewer's text. Without subagents, trace them all yourself the same way.
   - *Re-read:* the decisive lines opened at the cited place, with enough of the code around them to see that they do what the claim says. This is the minimum for anything in the main report, full issues and short findings alike. Low-end Mediums go to the appendix, which keeps this affordable on a large pass.
   - *Not re-read:* taken on the reviewer's word. Allowed only in the appendix, and marked †.
4. **Settle severity and reachability from the check**, using the definitions above. When a checker's rating differs from the reviewer's, take the checker's unless you can show from the code why not. When a rating turns on a product decision (whether a published policy is a commitment, whether a one-sided rule is intended), keep the rating and write the decision into the finding. For the claims no checker saw, apply the same tests yourself; reviewers tend to rate a real wrong result Low because its trigger is rare.
5. **Classify each result:** confirmed, narrower, or refuted. Drop what is refuted. Report a narrower claim as what it actually is.
6. **Carry the caveats.** Whatever a reviewer or checker listed as not checked stays with the finding until someone settles it: a library or provider behaviour nobody confirmed, a production setting nobody could read, a second site nobody opened. Settle it yourself, or write it into the finding. A caveat that drops out between the claims file and the report turns a guess into a fact.

For a claim about a framework's, library's or provider's default behaviour, confirm it against installed source or documentation and cite which, or mark it "not confirmed". The citation goes in the finding itself, not only in the claims file: a reader of the report cannot tell a confirmed default from an assumed one otherwise. Reviewers and checkers read installed source and have no network. What only a provider's documentation can settle (what a payment webhook carries, whether a platform completes a request whose answer was lost) is yours to look up, for every High that rests on it; the rest can stay "not confirmed".

Expect some claims to fail: a quarter to a third is normal on a first pass with module slices. When reviewers were briefed to verify before writing, a pass where nothing is refuted is common too. It is not proof, so say at which depth each finding was checked and let the reader judge. The counting rules and the † and ‡ marks are in `references/report-template.md`.

### Step 6: Reconcile with what is already known

- **Follow-up pass:** give every item of the previous report a status: Fixed, Partly fixed, Open, Worse, Moot, or Accepted (a documented, deliberate exception), each with one line of evidence (a commit, a file and line, or what remains). Include its short findings, so nothing survives only in version-control history. Correct any statement in the previous report you now know to be wrong, and say so.
- **Tracker:** where a finding is already ticketed, cite the ticket and add any new evidence instead of presenting it as new.
- **Code that moved while you worked:** if the reviewed branch advanced between pinning and writing, re-check the findings in the files it touched. For a commit the user pinned on purpose, only name those files.

### Step 7: Write the report

Read `references/report-template.md` and follow it: it has the template, the limits on what goes in the main report and what goes in the appendix, and the counting rules for the header. Write the report in the root of the tree you reviewed and the appendix beside it. Do not commit either unless asked. On a follow-up pass the new report replaces the old one, which is why Step 6 must give every item of the old one a status.

Open the summary with the finding of largest consequence, stated as what goes wrong. Say what you did not establish wherever it applies: an effect you estimated, a production fact you could not see, a library behaviour you could not confirm.

Before you finish, read the report once for two things that slip through. Every statement about what a library, framework or provider does by itself (a queue's default concurrency or retry, the order of a request's lifecycle, what a webhook carries, what a provider does with a second request) must name its source or say "not confirmed". And every finding must still carry what its reviewer or checker listed as not checked.

## Scoring

Tie each health score to evidence in the Basis column, a measurement or the issues that drive it, so scores can be compared between passes.

- **5:** the invariant holds across the tree; sweeps come back clean and something enforces it (a test, lint rule, or type).
- **4:** holds with a few isolated exceptions; no High or Medium issue under this criterion.
- **3:** holds in most of the code; Medium issues exist, or the exceptions are growing.
- **2:** the code practises it, yet it is broken in several areas or there is a High issue under this criterion, one or more.
- **1:** not practised: no owner, layer or mechanism to speak of, whatever the number of issues.

Count each issue once, under the criterion its principle belongs to; the report template lists which principle goes where.

The overall score is the mean of the criteria, to one decimal. On a follow-up pass, explain every score that moved, and separate a real change in the code from a change in what was measured: a criterion scored lower because this pass looked harder is not a regression. Where the previous report did not score a criterion, write "n/a" rather than inventing a baseline, and when its set of criteria differs, also give the mean over the criteria both reports share.

## Important notes

- Be honest about coverage. Say what you swept, what you read, and what you did not look at. Do not write "all services were reviewed" unless they were.
- Make no changes to the code during the review.
- Do not comment on formatting, linting, or naming beyond what affects architecture.
- Do not recommend new libraries, a different database, or a different framework unless the existing approach is fundamentally broken.
- Respect the project's scale. Flag a missing abstraction only where the code is paying for its absence: drifted copies, direct external calls, units that cannot be tested. Do not recommend layering for its own sake.
- If the project is sound, say so. A short report with two minor suggestions is a valid result, and so is a follow-up pass that mostly confirms earlier fixes.
- When the structural review finds little, spend the time on Step 4 rather than lowering the bar for structural findings.
