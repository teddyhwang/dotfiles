import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readdirSync, readFileSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { readToml } from "./helpers/toml.mjs";

const repo = path.resolve(import.meta.dirname, "..");
const bin = path.join(repo, "home/local/bin");
const wrapper = path.join(bin, "with-node");
const realNode = path.dirname(process.execPath);

function fixture(t) {
  const root = realpathSync(mkdtempSync(path.join(os.tmpdir(), "with-node-")));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  // A stand-in for Node 20.10, which runs an extensionless ES module as CommonJS.
  const fakeNode = (name, version) => {
    const dir = path.join(root, name);
    mkdirSync(dir);
    writeFileSync(path.join(dir, "node"), `#!/bin/sh
if [ "$1" = --version ]; then echo ${version}; exit 0; fi
echo "SyntaxError: Cannot use import statement outside a module" >&2
exit 1
`, { mode: 0o755 });
    return dir;
  };
  return { root, fakeNode };
}

const run = (args, env, options = {}) => spawnSync("/bin/sh", [wrapper, ...args], { encoding: "utf8", env, ...options });

test("with-node skips an older Node that comes first on PATH", (t) => {
  const { fakeNode } = fixture(t);
  const old = fakeNode("old", "v20.10.0");
  const newer = fakeNode("newer", "v24.0.0");
  const result = run(["sh", "-c", "command -v node"], { PATH: [old, newer, "/usr/bin", "/bin"].join(":") });
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout, `${newer}/node\n`);
});

test("with-node runs an extensionless ES module that the project's old Node rejects", (t) => {
  const { root, fakeNode } = fixture(t);
  const old = fakeNode("old", "v20.10.0");
  const script = path.join(root, "hook");
  writeFileSync(script, '#!/usr/bin/env node\nimport os from "node:os";\nconsole.log(typeof os.homedir());\n', { mode: 0o755 });
  const env = { PATH: [old, realNode, "/usr/bin", "/bin"].join(":") };
  const direct = spawnSync(script, { encoding: "utf8", env });
  assert.notEqual(direct.status, 0);
  assert.match(direct.stderr, /Cannot use import statement outside a module/);
  const result = run([script], env);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout, "string\n");
});

test("with-node does not use a node in the current directory", (t) => {
  const { fakeNode } = fixture(t);
  const old = fakeNode("old", "v20.10.0");
  const cwd = fakeNode("project", "v99.0.0");
  const result = run(["true"], { PATH: `:project:${old}` }, { cwd: path.dirname(cwd) });
  assert.equal(result.status, 1);
  assert.equal(result.stderr, "with-node: true needs Node 24 or newer, but PATH has only: v20.10.0\n");
});

test("with-node explains a missing Node and a missing command", (t) => {
  const { root } = fixture(t);
  const none = run(["true"], { PATH: root });
  assert.equal(none.status, 1);
  assert.equal(none.stderr, "with-node: true needs Node 24 or newer, but no node is on PATH\n");
  const usage = run([], { PATH: root });
  assert.equal(usage.status, 2);
  assert.match(usage.stderr, /^usage: with-node COMMAND/);
});

test("tinty and Zed run this repo's Node scripts through with-node", () => {
  const nodeScripts = readdirSync(bin).filter((name) =>
    readFileSync(path.join(bin, name), "utf8").startsWith("#!/usr/bin/env node") && !name.endsWith(".ts"));
  assert.ok(nodeScripts.includes("tinty-opencode-hook") && nodeScripts.includes("zed-other-file"));
  const hooks = readToml("home/config/tinted-theming/tinty/config.toml").items.map((item) => item.hook ?? "");
  const tasksSource = readFileSync(path.join(repo, "home/config/zed/tasks.json"), "utf8");
  const tasks = [...tasksSource.matchAll(/^\s*"command": "(.*)",?$/gm)].map((match) => match[1]);
  const offenders = [];
  let calls = 0;
  for (const command of [...hooks, ...tasks]) {
    for (const name of nodeScripts) {
      for (const match of command.matchAll(new RegExp(`(?<![\\w-])${name}(?![\\w-])`, "g"))) {
        calls += 1;
        if (!command.slice(0, match.index).endsWith("with-node ")) offenders.push(command);
      }
    }
  }
  assert.ok(calls >= 3, "tinty runs two Node hooks and Zed runs zed-other-file");
  assert.deepEqual(offenders, []);
});
