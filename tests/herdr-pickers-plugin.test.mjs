import assert from "node:assert/strict";
import { spawn, spawnSync } from "node:child_process";
import { createServer } from "node:net";
import { chmod, mkdir, mkdtemp, readdir, readFile, rm, writeFile } from "node:fs/promises";
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
  const temporary = path.join(home, "tmp");
  const stateDir = path.join(home, "state");
  await mkdir(bin);
  await mkdir(localBin, { recursive: true });
  await mkdir(temporary);
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
const repoSource = { source_workspace_id: "w1", source_checkout_path: home + "/src/dotfiles", repo_root: home + "/src/dotfiles" };
const worktrees = {
  repo: {
    source: repoSource,
    worktrees: [
      { path: home + "/src/dotfiles", branch: "main", open_workspace_id: "w1", is_linked_worktree: false },
      { path: home + "/.herdr/worktrees/dotfiles/review", branch: "teddyhwang/review", open_workspace_id: "w3", is_linked_worktree: true },
      { path: home + "/.herdr/worktrees/dotfiles/feature", branch: "teddyhwang/feature", is_linked_worktree: true },
      { path: home + "/.herdr/worktrees/dotfiles/gone", branch: "gone", is_linked_worktree: true, is_prunable: true },
      { path: home + "/bare.git", is_bare: true },
    ],
  },
  // The same repo later: review was removed and feature was opened elsewhere.
  changed: {
    source: repoSource,
    worktrees: [
      { path: home + "/src/dotfiles", branch: "main", open_workspace_id: "w1", is_linked_worktree: false },
      { path: home + "/.herdr/worktrees/dotfiles/feature", branch: "teddyhwang/feature", open_workspace_id: "w4", is_linked_worktree: true },
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
if (process.env.HERDR_TEST_AGENTS) results["agent list"] = { agents: JSON.parse(process.env.HERDR_TEST_AGENTS) };
if (process.env.HERDR_TEST_WORKSPACES) results["workspace list"] = { workspaces: JSON.parse(process.env.HERDR_TEST_WORKSPACES) };
console.log(JSON.stringify({ result: results[args.slice(0, 2).join(" ")] ?? {} }));
`);
  // Behaves like fzf for what the pickers use: it shows the items on stdin,
  // runs the load-time bg-transform refresh, follows its reload-sync or abort,
  // then accepts an item by index. HERDR_TEST_ENTER_EARLY accepts before the
  // refresh runs, which fzf does when Enter beats the refresh.
  await executable(path.join(bin, "fzf"), `#!${process.execPath}
import { execFileSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
const args = process.argv.slice(2);
const split = (text) => text.split("\\0").filter(Boolean);
const initial = split(readFileSync(0, "utf8"));
let items = initial;
let aborted = false;
const bind = args.find((arg) => arg.startsWith("load:"));
if (bind && process.env.HERDR_TEST_ENTER_EARLY !== "1") {
  const command = bind.slice(bind.indexOf("bg-transform:") + "bg-transform:".length);
  const actions = execFileSync("bash", ["-c", command], { encoding: "utf8" }).trim();
  const reload = actions.match(/^track-current\\+reload-sync:(.*)$/);
  if (actions === "abort") aborted = true;
  else if (reload) items = split(execFileSync("bash", ["-c", reload[1]], { encoding: "utf8" }));
  else throw new Error("unexpected fzf actions: " + actions);
}
writeFileSync(process.env.HERDR_TEST_FZF_LOG, JSON.stringify({
  args,
  defaultOpts: process.env.FZF_DEFAULT_OPTS,
  noun: process.env.HERDR_PICKER_NOUN,
  initial,
  items,
  aborted,
}));
if (aborted || process.env.HERDR_TEST_SELECT === "cancel") process.exit(130);
const chosen = items[Number(process.env.HERDR_TEST_SELECT ?? 0)];
if (chosen === undefined) process.exit(1);
console.log(chosen.split("\\t")[0]);
`);
  await executable(path.join(localBin, "herdr-focus-pane"), `#!${process.execPath}
import { appendFileSync } from "node:fs";
appendFileSync(process.env.HERDR_TEST_LOG, JSON.stringify(["pane", "focus", process.argv[2]]) + "\\n");
`);
  const run = async (kind, { select = "0", context, worktrees = "repo", early = false, agents, workspaces } = {}) => {
    await writeFile(log, "");
    const result = spawnSync(picker, [kind], {
      cwd: pluginRoot,
      env: {
        HOME: home,
        PATH: `${bin}:${path.dirname(jq.stdout.trim())}:/usr/bin:/bin`,
        TMPDIR: temporary,
        HERDR_BIN_PATH: herdr,
        HERDR_SESSION: "test session",
        HERDR_PLUGIN_STATE_DIR: stateDir,
        HERDR_PICKER_COLUMNS: "40",
        HERDR_PLUGIN_CONTEXT_JSON: JSON.stringify(context ?? { workspace_id: "w1", tab_id: "w1:t1" }),
        HERDR_TEST_LOG: log,
        HERDR_TEST_FZF_LOG: fzfLog,
        HERDR_TEST_SELECT: select,
        HERDR_TEST_WORKTREES: worktrees,
        HERDR_TEST_AGENTS: agents ? JSON.stringify(agents) : "",
        HERDR_TEST_WORKSPACES: workspaces ? JSON.stringify(workspaces) : "",
        HERDR_TEST_ENTER_EARLY: early ? "1" : "",
        HERDR_PICKER_REFRESH_DELAY: "0",
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
    assert.deepEqual(await readdir(temporary), [], "picker run directories are removed");
    return { calls, fzf };
  };
  return { home, stateDir, run };
}

// Mirrors the renderer's cell widths for the characters these tests use.
const cells = (text) => [...text].reduce((width, char) => width + (char.codePointAt(0) >= 0x1f300 ? 2 : 1), 0);

function item(key, label, status, detail) {
  const pad = Math.max(40 - 3 - cells(label) - cells(status), 1);
  return `${key}\t${bold} ${label}${unbold}${" ".repeat(pad)}${status}\n ${detail}`;
}

// A row nested under its parent checkout, drawn like Herdr's sidebar.
function childItem(key, label, status, detail, last) {
  const [tree, stem] = last ? ["  └─ ", "     "] : ["  ├─ ", "  │  "];
  const pad = Math.max(40 - 3 - cells(tree) - cells(label) - cells(status), 1);
  return `${key}\t \u001b[90m${tree}\u001b[39;1m${label}${unbold}${" ".repeat(pad)}${status}\n \u001b[90m${stem}\u001b[39m${detail}`;
}

// Reads run in parallel, so only their set is fixed; actions follow in order.
function assertCalls(calls, reads, actions = []) {
  const sorted = (list) => list.map((call) => JSON.stringify(call)).sort();
  assert.deepEqual(sorted(calls.slice(0, reads.length)), sorted(reads));
  assert.deepEqual(calls.slice(reads.length), actions);
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
  for (const option of ["--read0", "--ansi", "--accept-nth=1", "--with-nth=2..", "--highlight-line", "--ghost=filter workspaces", "--with-shell=bash -c"]) {
    assert.ok(fzf.args.includes(option), `missing fzf option: ${option}`);
  }
  const footer = fzf.args.find((arg) => arg.startsWith("--footer="));
  assert.match(footer, /↵ switch .* esc cancel /);
});

test("the agent picker labels agents by tab and focuses the exact pane", async (t) => {
  const { run } = await fixture(t);
  const { calls, fzf } = await run("agent", { select: "1" });
  assertCalls(calls, [["workspace", "list"], ["tab", "list"], ["agent", "list"]], [["pane", "focus", "w1:p1"]]);
  assert.deepEqual(fzf.items, [
    item("w1:p2", "1:🌵 review", "claude · idle", "dotfiles · ~/src/review"),
    item("w1:p1", "0:dotfiles", "current · pi · working", "dotfiles · π — fix pickers"),
  ]);
});

test("the agent picker lists blocked, then finished, then working agents, newest first", async (t) => {
  const { run } = await fixture(t);
  const agent = (pane, agent_status, state_change_seq) => ({
    pane_id: `w1:${pane}`, workspace_id: "w1", tab_id: "w1:t1", agent: "pi", agent_status, state_change_seq,
    focused: false, terminal_title_stripped: "", cwd: "/src",
  });
  const { calls, fzf } = await run("agent", {
    agents: [
      agent("p1", "idle", 20),
      agent("p2", "working", 19),
      agent("p3", "done", 5),
      agent("p4", "blocked", 2),
      agent("p5", "done", 11),
      agent("p6", "unknown", 30),
      agent("p7", "blocked", 7),
      agent("p8", "working", 3),
      { ...agent("p9", "working"), agent_status: undefined, state_change_seq: undefined },
    ],
  });
  // The picker opens on the first row, so Enter goes to the most urgent agent.
  assertCalls(calls, [["workspace", "list"], ["tab", "list"], ["agent", "list"]], [["pane", "focus", "w1:p7"]]);
  assert.deepEqual(
    fzf.items.map((row) => row.split("\t")[0]),
    ["w1:p7", "w1:p4", "w1:p5", "w1:p3", "w1:p1", "w1:p6", "w1:p2", "w1:p8", "w1:p9"],
  );
});

test("the workspace picker nests linked worktrees under their open parent checkout", async (t) => {
  const { home, run } = await fixture(t);
  const checkout = async (name, head, linked = true) => {
    const directory = path.join(home, name);
    const gitDir = linked ? path.join(home, "git/worktrees", name.replaceAll("/", "-")) : path.join(directory, ".git");
    await mkdir(directory, { recursive: true });
    await mkdir(gitDir, { recursive: true });
    if (linked) await writeFile(path.join(directory, ".git"), `gitdir: ${gitDir}\n`);
    await writeFile(path.join(gitDir, "HEAD"), `${head}\n`);
    return directory;
  };
  const root = await checkout("trees/root/src", "ref: refs/heads/main", false);
  const pool = await checkout("trees/pool-1/src", "ref: refs/heads/worktree/feature-x");
  const review = await checkout("trees/pool-2/src", "ref: refs/heads/review");
  const detached = await checkout("trees/pool-3/src", "0123456789abcdef0123456789abcdef01234567");
  const orphan = await checkout("other/linked", "ref: refs/heads/solo");
  const worktree = (checkout_path, is_linked_worktree, repo_key = "/world/git") => ({ checkout_path, is_linked_worktree, repo_key });
  const workspace = (workspace_id, label, extra = {}) => ({
    workspace_id, label, tab_count: 1, pane_count: 1, focused: false, agent_status: "unknown", ...extra,
  });

  const { calls, fzf } = await run("workspace", {
    select: "2",
    workspaces: [
      workspace("w1", "dotfiles"),
      workspace("w2", "src", { worktree: worktree(pool, true) }),
      workspace("w3", "notes"),
      workspace("w4", "shopify", { worktree: worktree(root, false), agent_status: "working" }),
      workspace("w5", "Review", { worktree: worktree(review, true) }),
      workspace("w6", "src", { worktree: worktree(detached, true) }),
      // A linked worktree whose parent checkout is not open stays top level.
      workspace("w7", "linked", { worktree: worktree(orphan, true, "/other/.git") }),
    ],
  });
  assertCalls(calls, [["workspace", "list"]], [["workspace", "focus", "w2"]]);
  const detail = (directory) => `1 tab · 1 pane · ${directory.replace(home, "~")}`;
  assert.deepEqual(fzf.items, [
    item("w1", "dotfiles", "", "1 tab · 1 pane"),
    item("w4", "shopify", "working", detail(root)),
    // Unnamed children take their branch; a hand-picked name is kept.
    childItem("w2", "feature-x", "", detail(pool), false),
    childItem("w5", "Review", "", detail(review), false),
    childItem("w6", "src", "", detail(detached), true),
    item("w3", "notes", "", "1 tab · 1 pane"),
    item("w7", "linked", "", detail(orphan)),
  ]);
});

test("the pickers plugin sets the attention-first agent view on startup", async (t) => {
  assert.deepEqual(manifest.startup, [{ command: ["./agent-view.py"] }]);
  const directory = await mkdtemp(path.join(tmpdir(), "herdr-agent-view-"));
  t.after(() => rm(directory, { recursive: true, force: true }));
  const socketPath = path.join(directory, "herdr.sock");
  let request;
  const server = createServer((connection) => {
    let buffer = "";
    connection.setEncoding("utf8");
    connection.on("data", (chunk) => {
      buffer += chunk;
      const newline = buffer.indexOf("\n");
      if (newline === -1) return;
      request = JSON.parse(buffer.slice(0, newline));
      connection.end(`${JSON.stringify({ id: request.id, result: { type: "agent_view", active: true } })}\n`);
    });
  });
  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(socketPath, resolve);
  });
  t.after(() => new Promise((resolve) => server.close(resolve)));

  const result = await new Promise((resolve) => {
    const child = spawn(path.join(pluginRoot, "agent-view.py"), [], {
      cwd: pluginRoot,
      env: { ...process.env, HERDR_SOCKET_PATH: socketPath },
    });
    let stderr = "";
    child.stderr.setEncoding("utf8");
    child.stderr.on("data", (chunk) => {
      stderr += chunk;
    });
    child.on("close", (status) => resolve({ status, stderr }));
  });
  assert.deepEqual(result, { status: 0, stderr: "" });
  assert.equal(request.method, "agent.view.set");
  assert.deepEqual(request.params, {
    source: "plugin:teddyhwang.pickers",
    label: "priority",
    sort: [
      { field: "status", order: "asc" },
      { field: "state_change_seq", order: "desc" },
    ],
  });
});

test("the join-pane picker lists other tabs in the workspace and joins the choice", async (t) => {
  const { run } = await fixture(t);
  const { calls, fzf } = await run("join-pane", { select: "1" });
  assertCalls(calls, [["pane", "list"], ["tab", "list", "--workspace", "w1"]], [
    ["pane", "move", "w1:p3", "--tab", "w1:t1", "--split", "right", "--focus"],
  ]);
  assert.deepEqual(fzf.items, [
    item("w1:p2", "1:🌵 review", "claude · idle", "~/src/review"),
    item("w1:p3", "1:🌵 review", "shell", "/var/tmp"),
  ]);
});

const repoRows = (home) => [
  item(path.join(home, "src/dotfiles"), "main", "current", "~/src/dotfiles"),
  item(path.join(home, ".herdr/worktrees/dotfiles/review"), "teddyhwang/review", "open", "~/.herdr/worktrees/dotfiles/review"),
  item(path.join(home, ".herdr/worktrees/dotfiles/feature"), "teddyhwang/feature", "", "~/.herdr/worktrees/dotfiles/feature"),
];

test("the worktree picker mirrors Herdr's rows and opens a closed checkout from the repo parent", async (t) => {
  const { home, stateDir, run } = await fixture(t);
  const { calls, fzf } = await run("worktree", { select: "2" });
  assert.deepEqual(fzf.initial, [], "nothing is cached on the first run");
  assert.deepEqual(fzf.items, repoRows(home), "bare and prunable checkouts are hidden like in the native picker");
  assert.equal(fzf.noun, "checkout");
  assert.ok(fzf.args.includes("--ghost=filter worktrees"));
  assert.ok(fzf.args.includes("--id-nth=1"), "the refresh keeps the cursor on the same checkout");
  assert.match(fzf.args.find((arg) => arg.startsWith("--footer=")), /↵ open .* esc cancel /);
  assert.deepEqual(calls, [
    ["worktree", "list", "--workspace", "w1"],
    ["worktree", "open", "--workspace", "w1", "--path", path.join(home, ".herdr/worktrees/dotfiles/feature"), "--focus"],
  ]);
  const cache = JSON.parse(await readFile(path.join(stateDir, "worktrees/test_session.w1.json"), "utf8"));
  assert.equal(cache.result.worktrees.length, 5, "the listing is cached per session and workspace");
});

test("the worktree picker shows cached rows at once and acts on the refreshed ones", async (t) => {
  const { home, run } = await fixture(t);
  await run("worktree", { select: "cancel" });
  const { calls, fzf } = await run("worktree", { select: "1", worktrees: "changed" });
  assert.deepEqual(fzf.initial, repoRows(home), "the last listing renders before Herdr answers");
  assert.deepEqual(fzf.items, [
    item(path.join(home, "src/dotfiles"), "main", "current", "~/src/dotfiles"),
    item(path.join(home, ".herdr/worktrees/dotfiles/feature"), "teddyhwang/feature", "open", "~/.herdr/worktrees/dotfiles/feature"),
  ]);
  assert.deepEqual(calls, [["worktree", "list", "--workspace", "w1"], ["workspace", "focus", "w4"]]);
});

test("the worktree picker lists again when Enter beats the refresh", async (t) => {
  const { home, run } = await fixture(t);
  await run("worktree", { select: "cancel" });
  // The cached row says feature is closed, but it is now open in w4.
  let result = await run("worktree", { select: "2", worktrees: "changed", early: true });
  assert.deepEqual(result.fzf.items, repoRows(home));
  assert.deepEqual(result.calls, [["worktree", "list", "--workspace", "w1"], ["workspace", "focus", "w4"]]);
  // review was cached but has since been removed.
  await run("worktree", { select: "cancel" });
  result = await run("worktree", { select: "1", worktrees: "changed", early: true });
  assert.deepEqual(result.calls, [
    ["worktree", "list", "--workspace", "w1"],
    ["notification", "show", "open worktree", "--body", "That worktree no longer exists."],
  ]);
});

test("the worktree picker names World trees and opens them when the parent is closed", async (t) => {
  const { home, run } = await fixture(t);
  const { calls, fzf } = await run("worktree", { select: "1", worktrees: "world" });
  assert.deepEqual(fzf.items, [
    item(path.join(home, "world/trees/pool-1/src"), "group-sort", "", "~/world/trees/pool-1/src"),
    item(path.join(home, "world/trees/pool-2/src"), "pool-2", "detached", "~/world/trees/pool-2/src"),
    item(path.join(home, "world/trees/root/src"), "root", "root", "~/world/trees/root/src"),
  ]);
  assert.deepEqual(calls, [
    ["worktree", "list", "--workspace", "w1"],
    ["worktree", "open", "--cwd", path.join(home, "world/trees/root/src"), "--path", path.join(home, "world/trees/pool-2/src"), "--focus"],
  ]);
});

test("the worktree picker closes and reports errors as Herdr toasts", async (t) => {
  const { run } = await fixture(t);
  for (const [worktrees, message] of [
    ["error", "Herdr worktree actions require a workspace inside a Git work tree"],
    ["empty", "No Git worktrees found for this repo."],
  ]) {
    const { calls, fzf } = await run("worktree", { worktrees });
    assert.equal(fzf.aborted, true, worktrees);
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
    assertCalls(calls, reads);
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
