import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmod, mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

const pluginRoot = path.resolve("plugins/herdr-pickers");
const picker = path.join(pluginRoot, "picker.sh");
const parsed = spawnSync("python3", ["-c", `
import json, pathlib, tomllib
print(json.dumps({
    "manifest": tomllib.loads(pathlib.Path("plugins/herdr-pickers/herdr-plugin.toml").read_text()),
    "keys": tomllib.loads(pathlib.Path("home/config/herdr/config.toml").read_text())["keys"],
}))
`], { encoding: "utf8" });
assert.equal(parsed.status, 0, parsed.stderr);
const { manifest, keys } = JSON.parse(parsed.stdout);
const commands = keys.command;
const jq = spawnSync("sh", ["-c", "command -v jq"], { encoding: "utf8" });
assert.equal(jq.status, 0, "Herdr picker tests require jq");

const bold = "\u001b[1m";
const unbold = "\u001b[22m";

async function executable(filename, contents) {
  await writeFile(filename, contents);
  await chmod(filename, 0o755);
}

async function fixture(t) {
  const home = await mkdtemp(path.join(tmpdir(), "herdr-pickers-"));
  t.after(() => rm(home, { recursive: true, force: true }));
  const bin = path.join(home, "bin");
  const localBin = path.join(home, ".local/bin");
  await mkdir(bin);
  await mkdir(localBin, { recursive: true });
  const log = path.join(home, "calls.jsonl");
  const fzfLog = path.join(home, "fzf.json");
  const herdr = path.join(bin, "herdr");
  await executable(herdr, `#!${process.execPath}
import { appendFileSync } from "node:fs";
const args = process.argv.slice(2);
appendFileSync(process.env.HERDR_TEST_LOG, JSON.stringify(args) + "\\n");
const home = process.env.HOME;
const results = {
  "workspace list": { workspaces: [
    { workspace_id: "w1", label: "dotfiles", tab_count: 2, pane_count: 3, focused: true, agent_status: "working",
      worktree: { checkout_path: home + "/src/dotfiles" } },
    { workspace_id: "w2", label: "notes\\twith\\ttabs", tab_count: 1, pane_count: 1, focused: false, agent_status: "unknown" },
  ] },
  "tab list": { tabs: [
    { tab_id: "w1:t1", label: "0:dotfiles" },
    { tab_id: "w1:t2", label: "1:🌵 review" },
  ] },
  "agent list": { agents: [
    { pane_id: "w1:p1", workspace_id: "w1", tab_id: "w1:t1", agent: "pi", agent_status: "working", focused: true,
      terminal_title_stripped: "π — fix pickers", cwd: home + "/src/dotfiles" },
    { pane_id: "w1:p2", workspace_id: "w1", tab_id: "w1:t2", agent: "claude", agent_status: "idle", focused: false,
      terminal_title_stripped: "", cwd: home + "/src/review" },
  ] },
  "pane list": { panes: [
    { pane_id: "w1:p1", workspace_id: "w1", tab_id: "w1:t1", cwd: home + "/src/dotfiles" },
    { pane_id: "w1:p2", workspace_id: "w1", tab_id: "w1:t2", cwd: home + "/src/review", agent: "claude", agent_status: "idle" },
    { pane_id: "w1:p3", workspace_id: "w1", tab_id: "w1:t2", cwd: "/tmp", foreground_cwd: "/var/tmp" },
    { pane_id: "w2:p1", workspace_id: "w2", tab_id: "w2:t1", cwd: "/elsewhere" },
  ] },
};
const worktrees = {
  repo: {
    source: { source_workspace_id: "w1", source_checkout_path: home + "/src/dotfiles", repo_root: home + "/src/dotfiles" },
    worktrees: [
      { path: home + "/src/dotfiles", branch: "main", open_workspace_id: "w1", is_linked_worktree: false },
      { path: home + "/.herdr/worktrees/dotfiles/review", branch: "teddyhwang/review", open_workspace_id: "w3", is_linked_worktree: true },
      { path: home + "/.herdr/worktrees/dotfiles/feature", branch: "teddyhwang/feature", is_linked_worktree: true },
      { path: home + "/.herdr/worktrees/dotfiles/gone", branch: "gone", is_linked_worktree: true, is_prunable: true },
      { path: home + "/bare.git", is_bare: true },
    ],
  },
  // World checkouts come from the dev-tree provider and are all labelled "git".
  world: {
    source: { source_workspace_id: null, source_checkout_path: home + "/world/trees/root/src", repo_root: home + "/world/trees/root/src" },
    worktrees: [
      { path: home + "/world/trees/pool-1/src", branch: "group-sort", label: "git", is_linked_worktree: true },
      { path: home + "/world/trees/pool-2/src", label: "git", is_detached: true, is_linked_worktree: true },
      { path: home + "/world/trees/root/src", label: "git", is_detached: true, is_linked_worktree: false },
    ],
  },
  empty: { source: { source_workspace_id: "w1" }, worktrees: [{ path: "/bare.git", is_bare: true }] },
};
if (args[0] === "worktree" && args[1] === "list") {
  if (process.env.HERDR_TEST_WORKTREES === "error") {
    console.error(JSON.stringify({ id: "cli:worktree:list", error: { code: "not_git_worktree", message: "Herdr worktree actions require a workspace inside a Git work tree" } }));
    process.exit(1);
  }
  console.log(JSON.stringify({ result: { type: "worktree_list", ...worktrees[process.env.HERDR_TEST_WORKTREES ?? "repo"] } }));
  process.exit(0);
}
console.log(JSON.stringify({ result: results[args.slice(0, 2).join(" ")] ?? {} }));
`);
  // Record what fzf receives, then choose an item by index or cancel.
  await executable(path.join(bin, "fzf"), `#!${process.execPath}
import { readFileSync, writeFileSync } from "node:fs";
const items = readFileSync(0, "utf8").split("\\0").filter(Boolean);
writeFileSync(process.env.HERDR_TEST_FZF_LOG, JSON.stringify({
  args: process.argv.slice(2),
  defaultOpts: process.env.FZF_DEFAULT_OPTS,
  noun: process.env.HERDR_PICKER_NOUN,
  items,
}));
if (process.env.HERDR_TEST_SELECT === "cancel") process.exit(130);
console.log(items[Number(process.env.HERDR_TEST_SELECT ?? 0)].split("\\t")[0]);
`);
  await executable(path.join(localBin, "herdr-focus-pane"), `#!${process.execPath}
import { appendFileSync } from "node:fs";
appendFileSync(process.env.HERDR_TEST_LOG, JSON.stringify(["pane", "focus", process.argv[2]]) + "\\n");
`);
  const run = async (kind, { select = "0", context, worktrees = "repo" } = {}) => {
    await writeFile(log, "");
    const result = spawnSync(picker, [kind], {
      cwd: pluginRoot,
      env: {
        HOME: home,
        PATH: `${bin}:${path.dirname(jq.stdout.trim())}:/usr/bin:/bin`,
        HERDR_BIN_PATH: herdr,
        HERDR_PICKER_COLUMNS: "40",
        HERDR_PLUGIN_CONTEXT_JSON: JSON.stringify(context ?? { workspace_id: "w1", tab_id: "w1:t1" }),
        HERDR_TEST_LOG: log,
        HERDR_TEST_FZF_LOG: fzfLog,
        HERDR_TEST_SELECT: select,
        HERDR_TEST_WORKTREES: worktrees,
        FZF_DEFAULT_OPTS: "--color=bg:#123456",
        LANG: "en_US.UTF-8",
      },
      encoding: "utf8",
      timeout: 10_000,
    });
    assert.equal(result.status, 0, result.stderr || result.stdout);
    const calls = (await readFile(log, "utf8")).trim().split("\n").filter(Boolean).map((line) => JSON.parse(line));
    let fzf;
    try {
      fzf = JSON.parse(await readFile(fzfLog, "utf8"));
    } catch {
      fzf = undefined;
    }
    await rm(fzfLog, { force: true });
    return { calls, fzf };
  };
  return { home, run };
}

// Mirrors the renderer's cell widths for the characters these tests use.
const cells = (text) => [...text].reduce((width, char) => width + (char.codePointAt(0) >= 0x1f300 ? 2 : 1), 0);

function item(key, label, status, detail) {
  const pad = Math.max(40 - 3 - cells(label) - cells(status), 1);
  return `${key}\t${bold} ${label}${unbold}${" ".repeat(pad)}${status}\n ${detail}`;
}

test("the workspace picker renders two-line rows and focuses the choice", async (t) => {
  const { home, run } = await fixture(t);
  const { calls, fzf } = await run("workspace", { select: "1" });
  assert.deepEqual(calls, [["workspace", "list"], ["workspace", "focus", "w2"]]);
  assert.deepEqual(fzf.items, [
    item("w1", "dotfiles", "current · working", "2 tabs · 3 panes · ~/src/dotfiles"),
    item("w2", "notes with tabs", "", "1 tab · 1 pane"),
  ]);
  assert.ok(!fzf.items.join("").includes(home), "paths under HOME are shown relative to ~");
  assert.equal(fzf.noun, "workspace");
  assert.equal(fzf.defaultOpts, "", "user fzf defaults must not restyle the picker");
  for (const option of ["--read0", "--ansi", "--accept-nth=1", "--with-nth=2..", "--highlight-line", "--ghost=filter workspaces"]) {
    assert.ok(fzf.args.includes(option), `missing fzf option: ${option}`);
  }
  const footer = fzf.args.find((arg) => arg.startsWith("--footer="));
  assert.match(footer, /↵ switch .* esc cancel /);
});

test("the agent picker labels agents by tab and focuses the exact pane", async (t) => {
  const { run } = await fixture(t);
  const { calls, fzf } = await run("agent", { select: "1" });
  assert.deepEqual(calls, [["workspace", "list"], ["tab", "list"], ["agent", "list"], ["pane", "focus", "w1:p2"]]);
  assert.deepEqual(fzf.items, [
    item("w1:p1", "0:dotfiles", "current · pi · working", "dotfiles · π — fix pickers"),
    item("w1:p2", "1:🌵 review", "claude · idle", "dotfiles · ~/src/review"),
  ]);
});

test("the join-pane picker lists other tabs in the workspace and joins the choice", async (t) => {
  const { run } = await fixture(t);
  const { calls, fzf } = await run("join-pane", { select: "1" });
  assert.deepEqual(calls, [
    ["pane", "list"],
    ["tab", "list", "--workspace", "w1"],
    ["pane", "move", "w1:p3", "--tab", "w1:t1", "--split", "right", "--focus"],
  ]);
  assert.deepEqual(fzf.items, [
    item("w1:p2", "1:🌵 review", "claude · idle", "~/src/review"),
    item("w1:p3", "1:🌵 review", "shell", "/var/tmp"),
  ]);
});

test("the worktree picker mirrors Herdr's rows and opens a closed checkout from the repo parent", async (t) => {
  const { home, run } = await fixture(t);
  const { calls, fzf } = await run("worktree", { select: "2" });
  assert.deepEqual(fzf.items, [
    item("0", "main", "current", "~/src/dotfiles"),
    item("1", "teddyhwang/review", "open", "~/.herdr/worktrees/dotfiles/review"),
    item("2", "teddyhwang/feature", "", "~/.herdr/worktrees/dotfiles/feature"),
  ], "bare and prunable checkouts are hidden like in the native picker");
  assert.equal(fzf.noun, "checkout");
  assert.ok(fzf.args.includes("--ghost=filter worktrees"));
  assert.match(fzf.args.find((arg) => arg.startsWith("--footer=")), /↵ open .* esc cancel /);
  assert.deepEqual(calls, [
    ["worktree", "list", "--workspace", "w1"],
    ["worktree", "open", "--workspace", "w1", "--path", path.join(home, ".herdr/worktrees/dotfiles/feature"), "--focus"],
  ]);
});

test("the worktree picker focuses a checkout that is already open", async (t) => {
  const { run } = await fixture(t);
  const { calls } = await run("worktree", { select: "1" });
  assert.deepEqual(calls, [["worktree", "list", "--workspace", "w1"], ["workspace", "focus", "w3"]]);
});

test("the worktree picker names World trees and opens them when the parent is closed", async (t) => {
  const { home, run } = await fixture(t);
  const { calls, fzf } = await run("worktree", { select: "1", worktrees: "world" });
  assert.deepEqual(fzf.items, [
    item("0", "group-sort", "", "~/world/trees/pool-1/src"),
    item("1", "pool-2", "detached", "~/world/trees/pool-2/src"),
    item("2", "root", "root", "~/world/trees/root/src"),
  ]);
  assert.deepEqual(calls, [
    ["worktree", "list", "--workspace", "w1"],
    ["worktree", "open", "--cwd", path.join(home, "world/trees/root/src"), "--path", path.join(home, "world/trees/pool-2/src"), "--focus"],
  ]);
});

test("the worktree picker reports errors as Herdr toasts instead of opening fzf", async (t) => {
  const { run } = await fixture(t);
  for (const [worktrees, message] of [
    ["error", "Herdr worktree actions require a workspace inside a Git work tree"],
    ["empty", "No Git worktrees found for this repo."],
  ]) {
    const { calls, fzf } = await run("worktree", { worktrees });
    assert.equal(fzf, undefined, worktrees);
    assert.deepEqual(calls, [
      ["worktree", "list", "--workspace", "w1"],
      ["notification", "show", "open worktree", "--body", message],
    ], worktrees);
  }
});

test("cancelling a picker changes nothing", async (t) => {
  const { run } = await fixture(t);
  for (const [kind, reads] of [
    ["workspace", [["workspace", "list"]]],
    ["agent", [["workspace", "list"], ["tab", "list"], ["agent", "list"]]],
    ["join-pane", [["pane", "list"], ["tab", "list", "--workspace", "w1"]]],
    ["worktree", [["worktree", "list", "--workspace", "w1"]]],
  ]) {
    const { calls } = await run(kind, { select: "cancel" });
    assert.deepEqual(calls, reads, kind);
  }
});

test("the join-pane picker does nothing without a tab context", async (t) => {
  const { run } = await fixture(t);
  const { calls, fzf } = await run("join-pane", { context: {} });
  assert.deepEqual(calls, []);
  assert.equal(fzf, undefined);
});

test("every picker keybinding opens a titled popup pane of the plugin", () => {
  assert.equal(manifest.id, "teddyhwang.pickers");
  const panes = new Map(manifest.panes.map((pane) => [pane.id, pane]));
  for (const pane of panes.values()) {
    assert.equal(pane.placement, "popup", pane.id);
    assert.ok(pane.title && pane.title !== "popup", `${pane.id} needs a border title`);
    assert.deepEqual(pane.command, ["./picker.sh", pane.id]);
  }
  const bound = commands
    .map((binding) => binding.command.match(/plugin pane open --plugin teddyhwang\.pickers --entrypoint (\S+)/)?.[1])
    .filter(Boolean);
  assert.deepEqual(bound.sort(), [...panes.keys()].sort());
  // A bound native action wins over keys.command and would shadow the picker.
  assert.equal(keys.open_worktree, "", "native open_worktree must stay unbound");
});
