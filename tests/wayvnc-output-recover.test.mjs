import assert from "node:assert/strict";
import { chmod, mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";

const repo = process.cwd();
const helper = path.join(repo, "home/local/bin/wayvnc-output-recover");

async function makeHarness(grimBody, monitors = [{ name: "DP-3", disabled: false, mirrorOf: "none" }]) {
  const root = await mkdtemp(path.join(tmpdir(), "wayvnc-output-recover-"));
  const bin = path.join(root, "bin");
  const log = path.join(root, "commands.log");
  await mkdir(bin);
  await writeFile(log, "");

  await writeFile(
    path.join(bin, "hyprctl"),
    `#!/bin/sh\nprintf '%s\\n' "$*" >>"$COMMAND_LOG"\ncase "$1 $2 $3" in\n  '-j monitors all') printf '%s\\n' "$MONITORS_JSON" ;;\nesac\n`,
  );
  await writeFile(path.join(bin, "grim"), `#!/bin/sh\nprintf 'grim %s\\n' "$*" >>"$COMMAND_LOG"\n${grimBody}\n`);
  await writeFile(path.join(bin, "sleep"), "#!/bin/sh\nexit 0\n");
  await Promise.all(["hyprctl", "grim", "sleep"].map((name) => chmod(path.join(bin, name), 0o755)));

  return {
    root,
    log,
    run: () =>
      spawnSync(helper, [], {
        cwd: repo,
        encoding: "utf8",
        env: {
          ...process.env,
          COMMAND_LOG: log,
          GRIM_COUNT: path.join(root, "grim-count"),
          MONITORS_JSON: JSON.stringify(monitors),
          PATH: `${bin}:/usr/bin:/bin`,
        },
      }),
  };
}

test("WayVNC output recovery leaves a healthy Wayland output alone", async (t) => {
  const harness = await makeHarness("exit 0");
  t.after(() => rm(harness.root, { recursive: true, force: true }));

  const result = harness.run();
  assert.equal(result.status, 0, result.stderr);
  const commands = await readFile(harness.log, "utf8");
  assert.match(commands, /-j monitors all/);
  assert.match(commands, /grim -l 0 -o DP-3 -/);
  assert.doesNotMatch(commands, /eval|reload/);
});

test("WayVNC output recovery recreates a missing wl_output before retrying", async (t) => {
  const harness = await makeHarness(
    `count=0\n[ ! -f "$GRIM_COUNT" ] || count=$(cat "$GRIM_COUNT")\ncount=$((count + 1))\nprintf '%s\\n' "$count" >"$GRIM_COUNT"\n[ "$count" -gt 1 ]`,
  );
  t.after(() => rm(harness.root, { recursive: true, force: true }));

  const result = harness.run();
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stderr, /recreating the missing wl_output for DP-3/);
  const commands = await readFile(harness.log, "utf8");
  assert.match(commands, /eval hl\.monitor\(\{ output = "DP-3", disabled = true \}\)/);
  assert.match(commands, /\nreload\n/);
  assert.equal((commands.match(/^grim /gm) || []).length, 2);
});

test("WayVNC service also restarts after a clean output-removal exit", async () => {
  const service = await readFile(path.join(repo, "home/systemd/user/wayvnc.service"), "utf8");
  assert.match(service, /^ExecStartPre=%h\/\.local\/bin\/wayvnc-output-recover$/m);
  assert.match(service, /^Restart=always$/m);
});
