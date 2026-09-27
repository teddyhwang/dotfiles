import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { chmod, mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

const repo = process.cwd();
const helper = path.join(repo, "home/local/bin/external-display-stay-awake");
const logindConfig = path.join(repo, "systemd/logind.conf.d/30-stay-awake-on-external-power.conf");

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

test("T2 setup ignores closed-lid suspend on external power", async () => {
  const config = await readFile(logindConfig, "utf8");
  assert.match(config, /^HandleLidSwitchExternalPower=ignore$/m);

  const setup = await readFile(path.join(repo, "scripts/macbook_t2_linux.sh"), "utf8");
  assert.match(setup, /30-stay-awake-on-external-power\.conf/);
  assert.match(setup, /systemctl reload systemd-logind\.service/);
});

test("stay-awake helper follows external power and display connections", async (t) => {
  const directory = await mkdtemp(path.join(tmpdir(), "external-display-stay-awake-"));
  const bin = path.join(directory, "bin");
  const runtime = path.join(directory, "runtime");
  const powerSupplies = path.join(directory, "power-supplies");
  const adapter = path.join(powerSupplies, "ADP1");
  const displayStatus = path.join(directory, "display-status");
  const adapterOnline = path.join(adapter, "online");
  const log = path.join(directory, "inhibitor.log");
  await mkdir(bin);
  await mkdir(runtime);
  await mkdir(adapter, { recursive: true });
  await writeFile(displayStatus, "disconnected\n");
  await writeFile(path.join(adapter, "type"), "Mains\n");
  await writeFile(adapterOnline, "1\n");

  // This test exercises inhibitor lifecycle, not locking. Stub flock as well as
  // the other Linux-only dependencies so the fixture also works on macOS.
  await writeFile(
    path.join(bin, "flock"),
    `#!/bin/sh
[ "$*" = "-n 9" ]
`,
  );
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
    chmod(path.join(bin, "flock"), 0o755),
    chmod(path.join(bin, "omarchy"), 0o755),
    chmod(path.join(bin, "systemd-inhibit"), 0o755),
  ]);

  const child = spawn(helper, [], {
    env: {
      ...process.env,
      DISPLAY_STATUS: displayStatus,
      EXTERNAL_DISPLAY_STAY_AWAKE_INTERVAL: "0.02",
      EXTERNAL_DISPLAY_STAY_AWAKE_POWER_SUPPLY_PATH: powerSupplies,
      INHIBITOR_LOG: log,
      PATH: `${bin}:/usr/bin:/bin`,
      XDG_RUNTIME_DIR: runtime,
    },
    stdio: "ignore",
  });
  let exited = false;
  const exitPromise = new Promise((resolve, reject) => {
    child.once("exit", (...args) => {
      exited = true;
      resolve(args);
    });
    child.once("error", reject);
  });
  t.after(async () => {
    if (!exited) {
      child.kill("SIGTERM");
      await exitPromise;
    }
    await rm(directory, { recursive: true, force: true });
  });

  // External power alone must inhibit sleep even when the KVM drops its display.
  await waitFor(async () => (await logLines(log)).filter((line) => line.startsWith("start ")).length === 1, "inhibitor did not start on external power");
  let lines = await logLines(log);
  assert.match(lines[0], /--what=sleep:handle-lid-switch/);
  assert.match(lines[0], /--mode=block/);

  await writeFile(adapterOnline, "0\n");
  await waitFor(async () => (await logLines(log)).filter((line) => line === "stop").length === 1, "inhibitor did not stop after all connections were removed");

  // A display connection must independently hold the same inhibitor.
  await writeFile(displayStatus, "connected\n");
  await waitFor(async () => (await logLines(log)).filter((line) => line.startsWith("start ")).length === 2, "inhibitor did not start for the external display");

  await writeFile(displayStatus, "disconnected\n");
  await waitFor(async () => (await logLines(log)).filter((line) => line === "stop").length === 2, "inhibitor did not stop after display disconnect");

  // Reconnecting power and terminating the helper both exercise cleanup.
  await writeFile(adapterOnline, "1\n");
  await waitFor(async () => (await logLines(log)).filter((line) => line.startsWith("start ")).length === 3, "inhibitor did not restart after reconnecting power");

  child.kill("SIGTERM");
  await exitPromise;
  lines = await logLines(log);
  assert.equal(lines.filter((line) => line === "stop").length, 3, "shutdown should release the inhibitor");
});
