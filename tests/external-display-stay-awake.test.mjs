import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { chmod, mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

const repo = process.cwd();
const helper = path.join(repo, "home/local/bin/external-display-stay-awake");

async function waitFor(predicate, message, timeout = 3_000) {
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    if (await predicate()) return;
    await new Promise((resolve) => setTimeout(resolve, 20));
  }
  assert.fail(message);
}

async function logLines(filename) {
  try {
    return (await readFile(filename, "utf8")).trim().split("\n").filter(Boolean);
  } catch (error) {
    if (error.code === "ENOENT") return [];
    throw error;
  }
}

test("external display helper holds and releases the sleep inhibitor", async (t) => {
  const directory = await mkdtemp(path.join(tmpdir(), "external-display-stay-awake-"));
  const bin = path.join(directory, "bin");
  const runtime = path.join(directory, "runtime");
  const status = path.join(directory, "status");
  const log = path.join(directory, "inhibitor.log");
  await mkdir(bin);
  await mkdir(runtime);
  await writeFile(status, "connected\n");

  await writeFile(
    path.join(bin, "omarchy"),
    `#!/bin/sh
[ "$*" = "hw external monitors" ] || exit 2
[ "$(cat "$DISPLAY_STATUS")" = connected ]
`,
  );
  await writeFile(
    path.join(bin, "systemd-inhibit"),
    `#!/bin/sh
printf 'start %s\n' "$*" >>"$INHIBITOR_LOG"
trap 'printf "stop\\n" >>"$INHIBITOR_LOG"; exit 0' HUP INT TERM
while :; do sleep 0.02; done
`,
  );
  await Promise.all([
    chmod(path.join(bin, "omarchy"), 0o755),
    chmod(path.join(bin, "systemd-inhibit"), 0o755),
  ]);

  const child = spawn(helper, [], {
    env: {
      ...process.env,
      DISPLAY_STATUS: status,
      EXTERNAL_DISPLAY_STAY_AWAKE_INTERVAL: "0.02",
      INHIBITOR_LOG: log,
      PATH: `${bin}:/usr/bin:/bin`,
      XDG_RUNTIME_DIR: runtime,
    },
    stdio: "ignore",
  });
  let exited = false;
  child.once("exit", () => {
    exited = true;
  });
  t.after(async () => {
    if (!exited) child.kill("SIGTERM");
    await rm(directory, { recursive: true, force: true });
  });

  await waitFor(async () => (await logLines(log)).filter((line) => line.startsWith("start ")).length === 1, "inhibitor did not start");
  let lines = await logLines(log);
  assert.match(lines[0], /--what=sleep:handle-lid-switch/);
  assert.match(lines[0], /--mode=block/);

  await writeFile(status, "disconnected\n");
  await waitFor(async () => (await logLines(log)).filter((line) => line === "stop").length === 1, "inhibitor did not stop after disconnect");

  await writeFile(status, "connected\n");
  await waitFor(async () => (await logLines(log)).filter((line) => line.startsWith("start ")).length === 2, "inhibitor did not restart after reconnect");

  child.kill("SIGTERM");
  await new Promise((resolve, reject) => {
    child.once("exit", resolve);
    child.once("error", reject);
  });
  lines = await logLines(log);
  assert.equal(lines.filter((line) => line === "stop").length, 2, "shutdown should release the inhibitor");
});
