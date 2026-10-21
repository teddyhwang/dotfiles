import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { lstat, mkdtemp, readFile, readlink, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";

const repo = process.cwd();
const source = path.join(repo, "home/pi-agent/AGENTS.md");

// Only pi-extensions is installed on every machine. Anything else that a rule
// names (tools from other packages, Herdsman agents, CLIs) must be
// conditional.
const optional = [
  "bg_run",
  "bg_wait",
  "codemode",
  "web_fetch",
  "scout",
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

test("global Pi rules contain nothing work-related", async () => {
  const markdown = await readFile(source, "utf8");
  assert.doesNotMatch(markdown, /shopify|meteorite|buildkite|bk_wait|quick_read|gs pr|data-auditor/i);
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

test("the toil trigger line names a skill and journal that setup provides", async (t) => {
  const markdown = await readFile(source, "utf8");
  const triggers = bullets(markdown).filter((rule) => /toil.tracker/i.test(rule));
  assert.equal(triggers.length, 1, "exactly one trigger line");
  assert.match(triggers[0], /^- Toil Tracker: .*\(~\/\.agents\/skills\/toil-tracker\/SKILL\.md\).* ~\/toil\/index\.md,/);

  const home = await mkdtemp(path.join(os.tmpdir(), "pi-toil-"));
  t.after(() => rm(home, { recursive: true, force: true }));
  const run = () => spawnSync("sh", [path.join(repo, "scripts/linker.sh")], {
    cwd: os.tmpdir(), env: { ...process.env, HOME: home }, encoding: "utf8", input: "",
  });
  let result = run();
  assert.equal(result.status, 0, result.stderr || result.stdout);
  assert.equal(
    await readlink(path.join(home, ".agents/skills/toil-tracker")),
    path.join(repo, ".agents/skills/toil-tracker"),
  );
  const index = path.join(home, "toil/index.md");
  const seeded = await readFile(index, "utf8");
  assert.match(seeded, /^# Toil Journal\n/);
  assert.match(seeded, /\*\*Budget:\*\* 32768 UTF-8 bytes/);
  assert.match(seeded, /## Entries\n$/);
  assert.doesNotMatch(seeded, /```/);

  await writeFile(index, "# Toil Journal\n\nkept\n");
  result = run();
  assert.equal(result.status, 0, result.stderr || result.stdout);
  assert.equal(await readFile(index, "utf8"), "# Toil Journal\n\nkept\n", "an existing journal is never overwritten");
});
