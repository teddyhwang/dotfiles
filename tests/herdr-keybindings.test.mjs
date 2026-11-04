import assert from "node:assert/strict";
import { spawn, spawnSync } from "node:child_process";
import { chmod, mkdir, mkdtemp, readFile, rm, symlink, writeFile } from "node:fs/promises";
import { createServer } from "node:net";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import { readToml } from "./helpers/toml.mjs";

const config = readToml("home/config/herdr/config.toml");
const bindings = config.keys.command;
assert.equal(config.ui.prompt_new_tab_name, false, "one-based new-tab prompt must be disabled");
assert.equal(config.keys.switch_tab, "", "native one-based tab switching must be disabled");
const jq = spawnSync("sh", ["-c", "command -v jq"], { encoding: "utf8" });
assert.equal(jq.status, 0, "Herdr keybinding tests require jq");

async function executable(filename, contents) {
  await writeFile(filename, contents);
  await chmod(filename, 0o755);
}

async function fixture(t, mode) {
  const home = await mkdtemp(path.join(tmpdir(), "herdr-keybindings-"));
  t.after(() => rm(home, { recursive: true, force: true }));
  const bin = path.join(home, "bin");
  const currentBin = path.join(home, "current version");
  await mkdir(bin);
  await mkdir(currentBin);
  const currentHerdr = path.join(currentBin, "herdr");
  await executable(currentHerdr, `#!${process.execPath}
import { appendFileSync } from "node:fs";
const args = process.argv.slice(2);
appendFileSync(process.env.HERDR_TEST_LOG, JSON.stringify(args) + "\\n");
let result = {};
if (args[0] === "pane" && args[1] === "process-info") {
  result = { process_info: { foreground_processes: JSON.parse(process.env.HERDR_TEST_PROCESSES) } };
} else if (args[0] === "pane" && args[1] === "edges") {
  result = { edges: JSON.parse(process.env.HERDR_TEST_EDGES ?? "{}") };
} else if (args[1] === "list") {
  result = {
    panes: [{ pane_id: "w1:p2", workspace_id: "w1", tab_id: "w1:t2", cwd: "/test" }],
    workspaces: [{ workspace_id: "w1", label: "test", tab_count: 2, pane_count: 2, agent_status: "unknown" }],
    agents: [{ pane_id: "w1:p2", workspace_id: "w1", tab_id: "w1:t2", agent: "pi", agent_status: "idle" }],
  };
}
console.log(JSON.stringify({ result }));
`);
  if (mode === "provided") {
    await executable(path.join(bin, "herdr"), "#!/bin/sh\necho 'wrong Herdr version from PATH' >&2\nexit 91\n");
  } else {
    await symlink(currentHerdr, path.join(bin, "herdr"));
  }
  await symlink(jq.stdout.trim(), path.join(bin, "jq"));
  await symlink(path.resolve("home/local/bin/herdr-nav"), path.join(bin, "herdr-nav"));
  await executable(path.join(bin, "fzf"), "#!/bin/sh\nhead -n 1\n");
  await executable(path.join(bin, "pbpaste"), "#!/bin/sh\nprintf 'clipboard text'\n");
  const log = path.join(home, "calls.jsonl");
  const localBin = path.join(home, ".local/bin");
  await mkdir(localBin, { recursive: true });
  await executable(path.join(localBin, "herdr-focus-pane"), `#!${process.execPath}
import { appendFileSync } from "node:fs";
appendFileSync(process.env.HERDR_TEST_LOG, JSON.stringify(["pane", "focus", process.argv[2]]) + "\\n");
`);
  // Model PATH after the login shell has selected the wrong installation.
  // Do not inherit any live Herdr context; every CLI invocation is mocked.
  const env = {
    HOME: home,
    PATH: `${bin}:/usr/bin:/bin`,
    HERDR_TEST_LOG: log,
    HERDR_ACTIVE_WORKSPACE_ID: "w1",
    HERDR_ACTIVE_TAB_ID: "w1:t1",
    HERDR_ACTIVE_PANE_ID: "w1:p1",
  };
  if (mode === "provided") env.HERDR_BIN_PATH = currentHerdr;
  if (mode === "empty") env.HERDR_BIN_PATH = "";
  return { env, log };
}

const processInfo = ["pane", "process-info", "--pane", "w1:p1"];
const shell = [{ argv0: "/bin/zsh", name: "zsh" }];
const vim = [{ argv0: "/usr/local/bin/nvim", name: "nvim" }];
const sendKeys = (key) => ["pane", "send-keys", "w1:p1", key];
const edges = ["pane", "edges", "--pane", "w1:p1"];
const focus = (direction) => ["pane", "focus", "--direction", direction, "--pane", "w1:p1"];
const zoom = (flag) => ["pane", "zoom", flag, "--pane", "w1:p1"];
const resize = (direction) => ["pane", "resize", "--pane", "w1:p1", "--direction", direction, "--amount", "0.01"];
const openPicker = (entrypoint) => ["plugin", "pane", "open", "--plugin", "teddyhwang.pickers", "--entrypoint", entrypoint];
const cases = [];
for (let index = 0; index <= 9; index += 1) {
  cases.push([
    `prefix+${index}`,
    shell,
    [["tab", "focus", `w1:${index + 1}`]],
  ]);
}
cases.push(
  ["ctrl+x", shell, [processInfo, sendKeys("ctrl+l")]],
  ["ctrl+x", vim, [processInfo, sendKeys("ctrl+x")]],
  ["ctrl+x", [{ name: "vim" }], [processInfo, sendKeys("ctrl+x")]],
  ["ctrl+x", [], [processInfo, sendKeys("ctrl+l")]],
  // The pickers themselves are covered by herdr-pickers-plugin.test.mjs.
  ["prefix+shift+v", shell, [openPicker("join-pane")]],
  ["prefix+a", shell, [openPicker("agent")]],
  ["prefix+s", shell, [openPicker("workspace")]],
  ["prefix+g", shell, [openPicker("worktree")]],
  ["prefix+shift+b", shell, [["pane", "move", "w1:p1", "--new-tab", "--focus"]]],
  ["prefix+shift+t", shell, [["pane", "move", "w1:p1", "--new-tab", "--focus"]]],
  ["prefix+x", shell, [["pane", "close", "w1:p1"]]],
  ["prefix+shift+p", shell, [["pane", "send-text", "w1:p1", "clipboard text"]]],
);
for (const [key, direction] of [["h", "left"], ["j", "down"], ["k", "up"], ["l", "right"]]) {
  const chord = `ctrl+${key}`;
  cases.push(
    [chord, shell, [processInfo, edges, focus(direction)]],
    [chord, vim, [processInfo, sendKeys(chord)]],
    [chord, [{ name: "vim" }], [processInfo, sendKeys(chord)]],
    [chord, shell, [processInfo, edges], { [direction]: true }],
    [chord, shell, [processInfo, edges, zoom("--off"), edges, focus(direction)], { layout: { zoomed: true } }],
    [chord, shell, [processInfo, edges, zoom("--off"), edges, zoom("--on")], { [direction]: true, layout: { zoomed: true } }],
  );
  for (const name of ["fzf", "atuin", "tv"]) {
    const passes = direction === "up" || direction === "down";
    cases.push([chord, [{ argv0: `/usr/local/bin/${name}`, name }], passes ? [processInfo, sendKeys(chord)] : [processInfo, edges, focus(direction)]]);
  }
  cases.push([`ctrl+alt+${key}`, shell, [processInfo, resize(direction)]]);
  cases.push([`ctrl+alt+${key}`, vim, [processInfo, sendKeys(`ctrl+alt+${key}`)]]);
}

for (const mode of ["provided", "unset", "empty"]) {
  test(`Herdr bindings use the running binary or PATH fallback (${mode})`, async (t) => {
    const { env, log } = await fixture(t, mode);
    for (const [key, processes, expected, paneEdges = {}] of cases) {
      await t.test(`${key} with ${JSON.stringify(processes)} at ${JSON.stringify(paneEdges)}`, async () => {
        await writeFile(log, "");
        const binding = bindings.find((entry) => entry.key === key);
        assert.ok(binding, `missing binding: ${key}`);
        const result = spawnSync("/bin/sh", ["-c", binding.command], {
          env: { ...env, HERDR_TEST_PROCESSES: JSON.stringify(processes), HERDR_TEST_EDGES: JSON.stringify(paneEdges) },
          encoding: "utf8",
          timeout: 5_000,
        });
        assert.equal(result.status, 0, result.stderr || result.stdout);
        const calls = (await readFile(log, "utf8")).trim().split("\n").filter(Boolean).map((line) => JSON.parse(line));
        assert.deepEqual(calls, expected);
      });
    }
  });
}

test("herdr-nav hand-off actions from Neovim never send keys back to it", async (t) => {
  const { env, log } = await fixture(t, "unset");
  const script = path.resolve("home/local/bin/herdr-nav");
  const run = (args, extra = {}) => spawnSync(script, args, {
    env: { ...env, HERDR_TEST_PROCESSES: JSON.stringify(vim), HERDR_TEST_EDGES: "{}", ...extra },
    encoding: "utf8",
    timeout: 5_000,
  });
  const calls = async () => (await readFile(log, "utf8")).trim().split("\n").filter(Boolean).map((line) => JSON.parse(line));
  for (const [args, expected, paneEdges = {}] of [
    [["focus", "left"], [edges, focus("left")]],
    [["focus", "up"], [edges], { up: true }],
    [["focus", "right"], [edges, zoom("--off"), edges, focus("right")], { layout: { zoomed: true } }],
    [["resize-pane", "down"], [resize("down")]],
  ]) {
    await writeFile(log, "");
    const result = run(args, { HERDR_TEST_EDGES: JSON.stringify(paneEdges) });
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(await calls(), expected, args.join(" "));
  }
  await writeFile(log, "");
  assert.equal(run(["move", "sideways"]).status, 2);
  assert.equal(run(["jump", "left"]).status, 2);
  assert.equal(run(["move", "left"], { HERDR_ACTIVE_PANE_ID: "" }).status, 0);
  assert.deepEqual(await calls(), []);
});

test("herdr-focus-pane sends an exact pane.focus socket request", async (t) => {
  const directory = await mkdtemp(path.join(tmpdir(), "herdr-focus-pane-"));
  const socketPath = path.join(directory, "herdr.sock");
  let resolveRequest;
  const requestReceived = new Promise((resolve) => {
    resolveRequest = resolve;
  });
  const server = createServer((connection) => {
    let buffer = "";
    connection.setEncoding("utf8");
    connection.on("data", (chunk) => {
      buffer += chunk;
      const newline = buffer.indexOf("\n");
      if (newline === -1) return;
      const request = JSON.parse(buffer.slice(0, newline));
      resolveRequest(request);
      connection.end(`${JSON.stringify({ id: request.id, result: { type: "pane_info" } })}\n`);
    });
  });
  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(socketPath, resolve);
  });
  t.after(async () => {
    await new Promise((resolve) => server.close(resolve));
    await rm(directory, { recursive: true, force: true });
  });

  const result = await new Promise((resolve) => {
    const child = spawn(path.resolve("home/local/bin/herdr-focus-pane"), ["w9:p3"], {
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
  const request = await requestReceived;
  assert.match(request.id, /^dotfiles:pane-focus:\d+$/);
  assert.equal(request.method, "pane.focus");
  assert.deepEqual(request.params, { pane_id: "w9:p3" });
});

test("all Herdr shell commands parse and CLI-backed bindings have regression coverage", () => {
  const coveredKeys = new Set(cases.map(([key]) => key));
  for (const binding of bindings) {
    if (binding.type === "plugin_action") continue;
    const result = spawnSync("/bin/sh", ["-n", "-c", binding.command], { encoding: "utf8" });
    assert.equal(result.status, 0, `${binding.key}: ${result.stderr}`);
    if (/\bherdr\s|HERDR_BIN_PATH|\bherdr-nav\b/.test(binding.command)) {
      assert.ok(coveredKeys.has(binding.key), `untested Herdr CLI binding: ${binding.key}`);
    }
  }
});
