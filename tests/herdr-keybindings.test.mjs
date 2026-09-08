import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmod, mkdir, mkdtemp, readFile, rm, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

const parsed = spawnSync("python3", ["-c", `
import json, pathlib, tomllib
config = tomllib.loads(pathlib.Path("home/config/herdr/config.toml").read_text())
print(json.dumps(config["keys"]["command"]))
`], { encoding: "utf8" });
assert.equal(parsed.status, 0, parsed.stderr);
const bindings = JSON.parse(parsed.stdout);
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
} else if (args[1] === "list") {
  result = {
    panes: [{ pane_id: "w1:p2", workspace_id: "w1", tab_id: "w1:t2", cwd: "/test" }],
    workspaces: [{ workspace_id: "w1", label: "test", tab_count: 2, pane_count: 2, agent_status: "unknown" }],
    agents: [{ pane_id: "w1:p2", workspace_id: "w1", agent: "pi", agent_status: "idle" }],
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
  await executable(path.join(bin, "fzf"), "#!/bin/sh\nhead -n 1\n");
  await executable(path.join(bin, "pbpaste"), "#!/bin/sh\nprintf 'clipboard text'\n");
  const log = path.join(home, "calls.jsonl");
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
const cases = [
  ["ctrl+x", shell, [processInfo, sendKeys("ctrl+l")]],
  ["ctrl+x", vim, [processInfo, sendKeys("ctrl+x")]],
  ["ctrl+x", [{ name: "vim" }], [processInfo, sendKeys("ctrl+x")]],
  ["ctrl+x", [], [processInfo, sendKeys("ctrl+l")]],
  ["prefix+shift+v", shell, [["pane", "list"], ["pane", "move", "w1:p2", "--tab", "w1:t1", "--split", "right", "--focus"]]],
  ["prefix+a", shell, [["workspace", "list"], ["agent", "list"], ["agent", "focus", "w1:p2"]]],
  ["prefix+s", shell, [["workspace", "list"], ["workspace", "focus", "w1"]]],
  ["prefix+shift+b", shell, [["pane", "move", "w1:p1", "--new-tab", "--focus"]]],
  ["prefix+shift+t", shell, [["pane", "move", "w1:p1", "--new-tab", "--focus"]]],
  ["prefix+x", shell, [["pane", "close", "w1:p1"]]],
  ["prefix+shift+p", shell, [["pane", "send-text", "w1:p1", "clipboard text"]]],
];
for (const [key, direction] of [["ctrl+j", "down"], ["ctrl+k", "up"]]) {
  cases.push([key, shell, [processInfo, ["plugin", "action", "invoke", `herdr-splits.nav-${direction}`]]]);
  for (const name of ["fzf", "atuin", "tv"]) {
    cases.push([key, [{ argv0: `/usr/local/bin/${name}`, name }], [processInfo, sendKeys(key)]]);
  }
}
for (const [key, direction] of [["h", "left"], ["j", "down"], ["k", "up"], ["l", "right"]]) {
  cases.push([`ctrl+alt+${key}`, shell, [processInfo, ["pane", "resize", "--pane", "w1:p1", "--direction", direction, "--amount", "0.01"]]]);
  cases.push([`ctrl+alt+${key}`, vim, [processInfo, sendKeys(`ctrl+alt+${key}`)]]);
}

for (const mode of ["provided", "unset", "empty"]) {
  test(`Herdr bindings use the running binary or PATH fallback (${mode})`, async (t) => {
    const { env, log } = await fixture(t, mode);
    for (const [key, processes, expected] of cases) {
      await t.test(`${key} with ${JSON.stringify(processes)}`, async () => {
        await writeFile(log, "");
        const binding = bindings.find((entry) => entry.key === key);
        assert.ok(binding, `missing binding: ${key}`);
        const result = spawnSync("/bin/sh", ["-c", binding.command], {
          env: { ...env, HERDR_TEST_PROCESSES: JSON.stringify(processes) },
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

test("all Herdr shell commands parse and CLI-backed bindings have regression coverage", () => {
  const coveredKeys = new Set(cases.map(([key]) => key));
  for (const binding of bindings) {
    if (binding.type === "plugin_action") continue;
    const result = spawnSync("/bin/sh", ["-n", "-c", binding.command], { encoding: "utf8" });
    assert.equal(result.status, 0, `${binding.key}: ${result.stderr}`);
    if (/\bherdr\s|HERDR_BIN_PATH/.test(binding.command)) {
      assert.ok(coveredKeys.has(binding.key), `untested Herdr CLI binding: ${binding.key}`);
    }
  }
});
