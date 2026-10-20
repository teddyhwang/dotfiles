import assert from "node:assert/strict";
import { chmod, mkdir, mkdtemp, readFile, rm, stat, writeFile } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

const repo = process.cwd();
const script = path.join(repo, "scripts/wavelink_bt_bridge.sh");
const label = "localhost.wavelink-bt-bridge";

// Fake uname, xcrun, codesign and launchctl, so the install flow runs on any
// platform without building or loading anything.
async function fixture(t) {
  const root = await mkdtemp(path.join(tmpdir(), "wavelink-bt-bridge-"));
  t.after(() => rm(root, { recursive: true, force: true }));
  const home = path.join(root, "home");
  const bin = path.join(root, "bin");
  await mkdir(path.join(root, "loaded"), { recursive: true });
  await mkdir(home, { recursive: true });
  await mkdir(bin);
  const tools = {
    uname: `case "$1" in -s) echo "\${FAKE_SYSTEM:-Darwin}" ;; -m) echo arm64 ;; esac`,
    xcrun: `[ "$1" = --find ] && exit 0
printf '%s\\n' "$*" >>"${root}/swiftc"
while [ "$#" -gt 0 ]; do [ "$1" = -o ] && out=$2; shift; done
printf '#!/bin/sh\\n# build %s\\n[ "$1" = --self-test ] && exit %s\\n' "\${BUILD:-1}" "\${SELF_TEST:-0}" >"$out"
chmod +x "$out"`,
    codesign: `printf '%s\\n' "$*" >>"${root}/codesign"`,
    launchctl: `printf '%s\\n' "$*" >>"${root}/calls"
case "$1" in
  print) test -f "${root}/loaded/\${2##*/}" ;;
  bootstrap) touch "${root}/loaded/${label}" ;;
  bootout) rm -f "${root}/loaded/\${2##*/}" ;;
  kickstart) ;;
  *) exit 1 ;;
esac`,
  };
  for (const [name, body] of Object.entries(tools)) {
    await writeFile(path.join(bin, name), `#!/bin/sh\n${body}\n`);
    await chmod(path.join(bin, name), 0o755);
  }
  const run = (args = [], env = {}) => spawnSync("sh", [script, ...args], {
    env: { ...process.env, HOME: home, PATH: `${bin}:/usr/bin:/bin`, ...env },
    encoding: "utf8", input: "", timeout: 20_000,
  });
  const read = (name) => readFile(path.join(root, name), "utf8").catch(() => "");
  const takeCalls = async () => {
    const calls = await read("calls");
    await rm(path.join(root, "calls"), { force: true });
    return calls;
  };
  return {
    home, run, read, takeCalls,
    binary: path.join(home, ".local/bin/wavelink-bt-bridge"),
    agent: path.join(home, `Library/LaunchAgents/${label}.plist`),
  };
}

function ok(result) {
  assert.equal(result.status, 0, result.stderr || result.stdout);
}

const exists = (file) => stat(file).then(() => true, () => false);

test("install builds and self-tests the helper, then loads its launch agent", async (t) => {
  const { home, run, read, takeCalls, binary, agent } = await fixture(t);
  ok(run(["install"]));
  assert.match(await read("swiftc"), /^swiftc -O .*-parse-as-library -target arm64-apple-macos15 .*__info_plist .*apps\/wavelink-bt-bridge\/Info\.plist .*apps\/wavelink-bt-bridge\/wavelink-bt-bridge\.swift$/m);
  assert.match(await read("codesign"), new RegExp(`--sign - --identifier ${label.replaceAll(".", "\\.")} `));
  assert.ok((await stat(binary)).mode & 0o100, "the helper is executable");

  const template = await readFile(path.join(repo, "apps/wavelink-bt-bridge/launch-agent.plist"), "utf8");
  assert.equal(await readFile(agent, "utf8"), template.replaceAll("@HOME@", home));
  assert.match(template, /<string>@HOME@\/\.local\/bin\/wavelink-bt-bridge<\/string>/);
  assert.match(template, /<key>KeepAlive<\/key>\s*<true\/>/);
  assert.match(await takeCalls(), new RegExp(`^bootstrap gui/\\d+ ${agent.replaceAll(".", "\\.")}$`, "m"));

  // Nothing changed, so nothing restarts.
  ok(run(["install"]));
  assert.doesNotMatch(await takeCalls(), /bootstrap|bootout|kickstart/);

  // A new binary restarts the loaded agent instead of loading it twice.
  ok(run(["install"], { BUILD: "2" }));
  const calls = await takeCalls();
  assert.match(calls, new RegExp(`^kickstart -k gui/\\d+/${label.replaceAll(".", "\\.")}$`, "m"));
  assert.doesNotMatch(calls, /bootstrap/);
});

test("a failing self-test installs nothing", async (t) => {
  const { run, takeCalls, binary, agent } = await fixture(t);
  const result = run(["install"], { SELF_TEST: "1" });
  assert.notEqual(result.status, 0);
  assert.match(result.stdout, /failed its self-test; nothing was installed/);
  assert.equal(await exists(binary), false);
  assert.equal(await exists(agent), false);
  assert.equal(await takeCalls(), "");
});

test("uninstall unloads the agent and removes its files", async (t) => {
  const { run, takeCalls, binary, agent } = await fixture(t);
  ok(run(["install"]));
  await takeCalls();
  ok(run(["uninstall"]));
  assert.match(await takeCalls(), new RegExp(`^bootout gui/\\d+/${label.replaceAll(".", "\\.")}$`, "m"));
  assert.equal(await exists(binary), false);
  assert.equal(await exists(agent), false);

  const again = run(["uninstall"]);
  ok(again);
  assert.match(again.stdout, /already configured, no changes needed/);
});

test("the installer refuses other systems and unknown commands", async (t) => {
  const { run, takeCalls } = await fixture(t);
  const linux = run(["install"], { FAKE_SYSTEM: "Linux" });
  assert.notEqual(linux.status, 0);
  assert.match(linux.stdout, /runs only on macOS/);
  const unknown = run(["start"]);
  assert.equal(unknown.status, 2);
  assert.match(unknown.stderr, /Usage: .* \[install\|build\|uninstall\]/);
  assert.equal(await takeCalls(), "");
});

// Builds the real helper and runs its self-test, which simulates both audio
// clocks and checks the device choices. Needs macOS with the Command Line Tools.
const canBuild = process.platform === "darwin" &&
  spawnSync("xcrun", ["--find", "swiftc"], { encoding: "utf8" }).status === 0;
test("the helper builds and passes its self-test", { skip: !canBuild && "needs macOS with swiftc", timeout: 600_000 }, async (t) => {
  const home = await mkdtemp(path.join(tmpdir(), "wavelink-bt-bridge-build-"));
  t.after(() => rm(home, { recursive: true, force: true }));
  ok(spawnSync("sh", [script, "build"], { env: { ...process.env, HOME: home }, encoding: "utf8", timeout: 600_000 }));
  const result = spawnSync(path.join(home, ".local/bin/wavelink-bt-bridge"), ["--self-test"], { encoding: "utf8" });
  ok(result);
  assert.match(result.stdout, /^Self-test passed$/m);
  assert.doesNotMatch(result.stdout, /FAIL/);
});
