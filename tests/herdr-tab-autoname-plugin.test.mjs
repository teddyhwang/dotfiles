import assert from "node:assert/strict";
import { chmod, mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import net from "node:net";
import os from "node:os";
import path from "node:path";
import { spawn } from "node:child_process";
import test from "node:test";

const repo = process.cwd();
const pluginRoot = path.join(repo, "plugins/herdr-tab-autoname");
const schedule = path.join(pluginRoot, "schedule.sh");

function runSchedule(env) {
  return new Promise((resolve, reject) => {
    const child = spawn("sh", [schedule], { env, stdio: ["ignore", "pipe", "pipe"] });
    let stderr = "";
    child.stderr.on("data", (chunk) => {
      stderr += chunk;
    });
    child.once("error", reject);
    child.once("exit", (code, signal) => resolve({ code, signal, stderr }));
  });
}

async function listen(server, socketPath) {
  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(socketPath, resolve);
  });
}

test("plugin covers the events that can change tab names", async () => {
  const manifest = await readFile(path.join(pluginRoot, "herdr-plugin.toml"), "utf8");
  const events = [...manifest.matchAll(/^on = "([^"]+)"$/gm)]
    .map((match) => match[1])
    .sort();
  assert.deepEqual(events, [
    "pane.agent_detected",
    "pane.agent_status_changed",
    "pane.closed",
    "pane.created",
    "pane.exited",
    "pane.moved",
    "tab.closed",
    "tab.created",
    "tab.focused",
    "tab.moved",
    "tab.renamed",
    "workspace.focused",
  ]);
  assert.match(manifest, /\[\[startup\]\]\ncommand = \["\.\/schedule\.sh"\]/);
});

test("plugin coalesces concurrent events across Herdr sessions", async (t) => {
  if (process.platform === "win32") return t.skip("Unix socket fixture");

  const directory = await mkdtemp(path.join(os.tmpdir(), "herdr-plugin-"));
  t.after(() => rm(directory, { recursive: true, force: true }));
  const state = path.join(directory, "state");
  const calls = path.join(directory, "calls");
  const worker = path.join(directory, "worker.sh");
  await writeFile(
    worker,
    "#!/bin/sh\n[ \"$*\" = '--once --verbose' ] || exit 1\nprintf '%s\\n' \"$HERDR_SOCKET_PATH\" >>\"$CALL_LOG\"\nsleep 0.05\n",
  );
  await chmod(worker, 0o755);

  const socketA = path.join(directory, "a.sock");
  const socketB = path.join(directory, "b.sock");
  const serverA = net.createServer();
  const serverB = net.createServer();
  await Promise.all([listen(serverA, socketA), listen(serverB, socketB)]);
  t.after(() => {
    serverA.close();
    serverB.close();
  });

  await mkdir(state, { recursive: true });
  const staleLock = path.join(state, "scheduler.lockfile");
  await writeFile(staleLock, "999999999\n");

  const baseEnv = {
    ...process.env,
    HOME: directory,
    HERDR_PLUGIN_ROOT: pluginRoot,
    HERDR_PLUGIN_STATE_DIR: state,
    // Give all spawned hooks time to publish their pending files, including on
    // slower CI runners, before the scheduler drains the burst.
    HERDR_TAB_AUTONAME_SETTLE_SECONDS: "1",
    HERDR_TAB_AUTONAME_WORKER: worker,
    CALL_LOG: calls,
  };
  const runs = [];
  for (let index = 0; index < 8; index += 1) {
    runs.push(runSchedule({ ...baseEnv, HERDR_SOCKET_PATH: socketA }));
  }
  runs.push(runSchedule({ ...baseEnv, HERDR_SOCKET_PATH: socketB }));

  for (const result of await Promise.all(runs)) {
    assert.equal(result.code, 0, result.stderr);
    assert.equal(result.signal, null);
  }
  const invokedSockets = (await readFile(calls, "utf8")).trim().split("\n").sort();
  assert.deepEqual(invokedSockets, [socketA, socketB]);
});
