#!/usr/bin/env node
// Build ARCHITECTURE_OVERVIEW.html from validated Mermaid diagram files.
//
// Usage:
//   node build_report.mjs report-input.json ARCHITECTURE_OVERVIEW.html

import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, isAbsolute, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const DEFAULT_MERMAID_VERSION = "11.15.0";
const scriptDir = dirname(fileURLToPath(import.meta.url));
const templatePath = resolve(scriptDir, "../assets/template.html");

function fail(message) {
  console.error("ERROR: " + message);
  process.exit(2);
}

function readJson(path) {
  try {
    return JSON.parse(readFileSync(path, "utf8"));
  } catch (error) {
    fail(`could not read JSON from ${path}: ${error.message}`);
  }
}

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function slugify(value, fallback) {
  const slug = String(value || "")
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
  return slug || fallback;
}

function assertHtmlId(id, label) {
  if (!/^[a-z][a-z0-9-]*$/.test(id)) {
    fail(`${label} id must be kebab-case and start with a letter: ${id}`);
  }
}

function resolveFromConfig(configDir, maybePath) {
  if (!maybePath) return null;
  return isAbsolute(maybePath) ? maybePath : resolve(configDir, maybePath);
}

function readDiagram(configDir, article, label) {
  const diagramPath = resolveFromConfig(configDir, article.diagram || article.diagramPath);
  if (!diagramPath) fail(`${label} is missing "diagram"`);
  const source = readFileSync(diagramPath, "utf8").trim();
  if (!source) fail(`${label} diagram is empty: ${diagramPath}`);
  return { path: diagramPath, source };
}

function normalizeArticle(configDir, article, index, kind) {
  if (!article || typeof article !== "object") {
    fail(`${kind}[${index}] must be an object`);
  }
  const title = String(article.title || "").trim();
  if (!title) fail(`${kind}[${index}] is missing "title"`);
  const id = article.id || slugify(title, `${kind}-${index + 1}`);
  assertHtmlId(id, `${kind}[${index}]`);
  const diagram = readDiagram(configDir, article, `${kind}[${index}]`);
  const firstLine = diagram.source.split(/\r?\n/, 1)[0]?.trim() || "diagram";
  return {
    id,
    title,
    tag: String(article.tag || firstLine).trim(),
    intro: String(article.intro || ""),
    caption: String(article.caption || ""),
    diagram,
    className: kind === "workflows" ? "workflow" : "",
  };
}

function ensureUniqueIds(articles) {
  const seen = new Set(["summary", "workflows"]);
  for (const article of articles) {
    if (seen.has(article.id)) fail(`duplicate article id: ${article.id}`);
    seen.add(article.id);
  }
}

function renderToc(appSummary, workflows) {
  const lines = [
    '    <a href="#summary">App Summary</a>',
    ...appSummary.map(
      (article) =>
        `    <a href="#${escapeHtml(article.id)}" class="toc-sub">${escapeHtml(article.title)}</a>`,
    ),
    '    <a href="#workflows">Key Workflows</a>',
  ];
  if (workflows.length >= 3) {
    lines.push(
      ...workflows.map(
        (workflow) =>
          `    <a href="#${escapeHtml(workflow.id)}" class="toc-sub">${escapeHtml(workflow.title)}</a>`,
      ),
    );
  }
  return lines.join("\n");
}

function renderArticle(article) {
  const classAttr = article.className ? ` class="${escapeHtml(article.className)}"` : "";
  return `    <article id="${escapeHtml(article.id)}"${classAttr}>
      <h3>${escapeHtml(article.title)} <span class="tag">${escapeHtml(article.tag)}</span></h3>
      <p>${escapeHtml(article.intro)}</p>
      <div class="diagram-card">
<pre class="mermaid">
${escapeHtml(article.diagram.source)}
</pre>
        <div class="caption">${escapeHtml(article.caption)}</div>
      </div>
    </article>`;
}

function replaceToken(html, token, value) {
  return html.replaceAll(`{{${token}}}`, value);
}

const [configArg, outputArg] = process.argv.slice(2);
if (!configArg || !outputArg) {
  fail("usage: node build_report.mjs <report-input.json> <output.html>");
}

const configPath = resolve(configArg);
const configDir = dirname(configPath);
const config = readJson(configPath);
const factsPath = resolveFromConfig(configDir, config.factsPath);
const facts = factsPath ? readJson(factsPath) : {};

const appSummary = (Array.isArray(config.appSummary) ? config.appSummary : []).map((article, index) =>
  normalizeArticle(configDir, article, index, "appSummary"),
);
const workflows = (Array.isArray(config.workflows) ? config.workflows : []).map((article, index) =>
  normalizeArticle(configDir, article, index, "workflows"),
);

if (appSummary.length === 0) fail("config.appSummary must include at least one diagram");
ensureUniqueIds([...appSummary, ...workflows]);

const metadata = facts.metadata || {};
const project = facts.project || {};
const outputPath = resolve(outputArg);
const template = readFileSync(templatePath, "utf8");

const replacements = {
  PROJECT_NAME: escapeHtml(config.projectName || project.name || metadata.projectName || "Architecture Overview"),
  DATE: escapeHtml(config.date || metadata.date || new Date().toISOString().slice(0, 10)),
  STACK: escapeHtml(config.stack || metadata.stack || facts.stack || "Unknown"),
  SCOPE: escapeHtml(config.scope || project.path || metadata.scope || "."),
  MERMAID_VERSION: escapeHtml(config.mermaidVersion || metadata.mermaidVersion || DEFAULT_MERMAID_VERSION),
  SUMMARY_PARAGRAPH: escapeHtml(config.summaryParagraph || config.summary || ""),
  WORKFLOWS_INTRO: escapeHtml(config.workflowsIntro || ""),
  TOC_LINKS: renderToc(appSummary, workflows),
  SUMMARY_ARTICLES: appSummary.map(renderArticle).join("\n\n"),
  WORKFLOW_ARTICLES: workflows.map(renderArticle).join("\n\n"),
};

let html = template;
for (const [token, value] of Object.entries(replacements)) {
  html = replaceToken(html, token, value);
}

const leftoverTokens = html.match(/{{[A-Z0-9_]+}}/g);
if (leftoverTokens) {
  fail(`unreplaced template token(s): ${[...new Set(leftoverTokens)].join(", ")}`);
}

mkdirSync(dirname(outputPath), { recursive: true });
writeFileSync(outputPath, html);
console.log(`Wrote ${outputPath}`);
