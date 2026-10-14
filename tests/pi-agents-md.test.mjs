import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { lstat, mkdtemp, readFile, readlink, rm } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";

const repo = process.cwd();
const source = path.join(repo, "home/pi-agent/AGENTS.md");

// Only pi-extensions is installed on every machine. Anything else that a rule
// names (shop-pi-fy tools, Herdsman agents, Shopify CLIs, tools that register
// only where they are set up) must be conditional.
const optional = [
  "bg_run",
  "bg_wait",
  "bk_wait",
  "codemode",
  "web_fetch",
  "quick_read",
  "scout",
  "data-auditor",
  "gs pr view",
  "Google Docs tool",
];

function bullets(markdown) {
  return markdown
    .split(/\n(?=- )/)
    .filter((block) => block.startsWith("- "))
    .map((block) => block.replace(/\s+/g, " "));
}

test("global Pi rules make every tool outside pi-extensions conditional", async () => {
  const rules = bullets(await readFile(source, "utf8"));
  assert.ok(rules.length > 5, "the file still has rules");
  for (const name of optional) {
    const naming = rules.filter((rule) => rule.includes(name));
    assert.ok(naming.length > 0, `no rule names ${name}; update this list`);
    for (const rule of naming) {
      assert.match(rule, /\bif\b/i, `a rule names ${name} without a condition: ${rule}`);
    }
  }
});

test("global Pi rules contain no machine-specific paths", async () => {
  const markdown = await readFile(source, "utf8");
  assert.doesNotMatch(markdown, /\/Users\/|\/home\/[a-z]|\/nix\/store\//);
});

test("linker links ~/.pi/agent/AGENTS.md to the dotfiles copy", async (t) => {
  const home = await mkdtemp(path.join(os.tmpdir(), "pi-agents-md-"));
  t.after(() => rm(home, { recursive: true, force: true }));
  const result = spawnSync("sh", [path.join(repo, "scripts/linker.sh")], {
    cwd: os.tmpdir(), env: { ...process.env, HOME: home }, encoding: "utf8", input: "",
  });
  assert.equal(result.status, 0, result.stderr || result.stdout);
  const target = path.join(home, ".pi/agent/AGENTS.md");
  assert.ok((await lstat(target)).isSymbolicLink(), "AGENTS.md is a symlink, so edits in dotfiles apply at once");
  assert.equal(await readlink(target), source);
});
