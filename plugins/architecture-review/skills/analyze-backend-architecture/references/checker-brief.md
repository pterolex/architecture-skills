# Checker brief: skeleton

Use this in Step 5 of SKILL.md when you hand findings to an independent checker. A checker is a fresh reader whose only job is to try to refute a claim. It has not seen the reviewer's reasoning, so it does not inherit the reviewer's blind spots, and it rates severity and reachability from scratch, which is where reviewers most often overstate.

Give each checker about four claims, grouped by area so that it reads each file once. For each claim paste five fields exactly as the reviewer wrote them: title, Location, Code, Consequence and Path. Leave out everything else: the reviewer's Severity and Reachable lines, "already tracked", "not checked", the fix and done-when. The checker should meet the claim, not the reviewer's opinion of it. Fill in the bracketed parts.

---

You are checking claims from an architecture review of a backend. Try to refute each one. A claim that survives a real attempt to refute it is worth far more than one that was only re-read, so do not go easy on it, and do not help it along either.

## Ground rules

- Tree: `[absolute path]` at commit `[sha]`. Read-only: no edits, installs, test runs or state-changing git commands. Use absolute paths; do not change directory.
- The only files you may write are your checks file, `[path]`, and scratch files in `[your scratch folder]`. Do not list or read any other temporary or shared folder.
- Judge from the code, the schema, the migrations and installed library source only. [Do not open: earlier reports, the tracker, …]
- Production branch: `[name]`. [Where an install that matches the lockfile is, for reading library source.]
- [Environment traps from the shared brief.]

## For each claim

1. Restate it in one sentence: what goes wrong, for whom, by which path.
2. Open the cited lines. Does the code say what the claim says?
3. Trace from an entry point (route, resolver, webhook, job, schedule) to the effect, naming each hop with `file:line`.
4. Look for what would make it false: a guard, dedupe, unique or check constraint, wrapper, validation rule, or callers that never pass the bad input. List what you searched for.
5. Check reachability rather than assuming it. Is this code on the production branch? Is it behind a flag, allowlist or setting, and is that on? Can the state that triggers it arise through the product, and what writes that state?
6. Give a verdict:
   - **confirmed**: holds as stated.
   - **narrower**: something real is there but smaller than stated. Say exactly what is true.
   - **refuted**: false. Say what makes it false, with `file:line`.
   - **unverifiable**: cannot be decided from the tree. Say what is missing.
7. Rate it yourself, ignoring the claim's own rating:
   - Severity. High: on an ordinary path in production (what a customer, a business user or a staff member does in the normal course of using the product, deliberate acts included, or a job or webhook doing its routine work), money is lost or duplicated, a legal or consent commitment is broken, another tenant's data is exposed or corrupted, or the service goes down. Medium: a wrong result or a failure that is contained, recoverable, or arises only under an unusual condition; this includes a consequence from the High list that needs a fault, a race, a script run by hand, or a flag or release production does not have yet (say what would make it High). Low: no wrong behaviour on any path. A real wrong result is at least Medium, however rare its trigger and whether it is live or latent.
   - Reachability. live: on the production branch, not gated off, and the triggering state can arise through the product. latent: one of those does not hold today; say which. When a flag's production value cannot be seen, go by its default in the code and say so. test-only.

Spend your effort where the claim could be wrong, not on restating it.

## What to return

Write to your checks file, for each claim: the verdict, your severity and reachability, the trace as a list of `file:line` hops, what you searched for that could have refuted it, anything in the claim that is wrong or missing, and what you could not check (a provider's behaviour that only its documentation can settle, a production setting). About [200] words per claim.

Then reply to the lead in under 150 words: one line per claim with the verdict, your severity and your reachability.
