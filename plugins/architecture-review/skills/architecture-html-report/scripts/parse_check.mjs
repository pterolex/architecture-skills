// parse_check.mjs — validate Mermaid syntax WITHOUT a browser.
//
// Usage:  node parse_check.mjs file1.mmd [file2.mmd ...]
//
// Uses mermaid.parse() inside a jsdom DOM. This catches grammar/syntax errors
// (the overwhelming majority of diagram defects) without needing Chromium, so
// it works in locked-down sandboxes where the mermaid-cli (mmdc) cannot fetch a
// headless browser. A successful mmdc render is a slightly stronger check, so
// validate_mermaid.sh prefers mmdc and only falls back to this when Chromium is
// unavailable.
//
// Requires `mermaid` and `jsdom` to be resolvable from this file's directory.
// Exit code 0 only if every file parses; non-zero otherwise.

import { readFileSync } from "node:fs";
import { JSDOM } from "jsdom";

const dom = new JSDOM("<!doctype html><body></body>");
globalThis.window = dom.window;
globalThis.document = dom.window.document;

const mermaid = (await import("mermaid")).default;
mermaid.initialize({ startOnLoad: false, securityLevel: "strict" });

const files = process.argv.slice(2);
if (files.length === 0) {
  console.error("usage: node parse_check.mjs <file.mmd> [...]");
  process.exit(2);
}

let failed = 0;
let passed = 0;
for (const f of files) {
  try {
    await mermaid.parse(readFileSync(f, "utf8"));
    console.log("PASS  " + f);
    passed++;
  } catch (e) {
    failed++;
    const msg = String(e?.message || e);
    console.error("FAIL  " + f);
    for (const line of msg.split("\n")) console.error("        " + line);
  }
}
console.log("------------------------------------------------------------");
console.log(`Mermaid validation (parse): ${passed} passed, ${failed} failed (of ${files.length}).`);
process.exit(failed ? 1 : 0);
