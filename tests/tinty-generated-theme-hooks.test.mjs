import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readFileSync, readlinkSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";

const parsed = spawnSync("python3", ["-c", `
import json, pathlib, tomllib
config = tomllib.loads(pathlib.Path("home/config/tinted-theming/tinty/config.toml").read_text())
print(json.dumps({item["name"]: item["hook"] for item in config["items"]}))
`], { encoding: "utf8" });
assert.equal(parsed.status, 0, parsed.stderr);
const hooks = JSON.parse(parsed.stdout);

function fixture(t, name) {
  const root = mkdtempSync(path.join(os.tmpdir(), "tinty-generated-theme-"));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const home = path.join(root, "clean home");
  const bin = path.join(root, "bin");
  mkdirSync(home);
  mkdirSync(bin);
  const theme = path.join(root, "fixture theme");
  writeFileSync(theme, "fixture theme contents\n");
  const log = path.join(root, "signals");
  writeFileSync(log, "");
  const stub = (command, body) => writeFileSync(path.join(bin, command), `#!/bin/sh\n${body}\n`, { mode: 0o755 });
  // Never signal real applications. pkill's status 1 means no matching process.
  for (const command of ["killall", "pkill"]) {
    stub(command, 'printf "%s\\n" "$*" >> "$SIGNAL_LOG"\nexit "${SIGNAL_STATUS:-1}"');
  }
  const run = (extraEnv = {}) => spawnSync("zsh", ["-f", "-c", hooks[name]], {
    encoding: "utf8",
    env: {
      ...process.env,
      HOME: home,
      ZDOTDIR: home,
      PATH: `${bin}:/usr/bin:/bin`,
      TINTY_THEME_FILE_PATH: theme,
      SIGNAL_LOG: log,
      ...extraEnv,
    },
  });
  return { home, theme, stub, run, signals: () => readFileSync(log, "utf8") };
}

test("Ghostty creates its theme directory, skips unchanged reloads, and copies changed themes", (t) => {
  const f = fixture(t, "tinted-terminal");
  const destination = path.join(f.home, ".config/ghostty/themes/tinted-theming");
  for (let i = 0; i < 2; i++) {
    const result = f.run();
    assert.equal(result.status, 0, result.stderr);
    assert.equal(readFileSync(destination, "utf8"), "fixture theme contents\n");
    assert.equal(f.signals(), "-SIGUSR2 ghostty\n");
  }
  writeFileSync(f.theme, "changed theme\n");
  const result = f.run();
  assert.equal(result.status, 0, result.stderr);
  assert.equal(readFileSync(destination, "utf8"), "changed theme\n");
  assert.equal(f.signals(), "-SIGUSR2 ghostty\n-SIGUSR2 ghostty\n");
});

test("btop creates and refreshes its theme link even when no btop is running", (t) => {
  const f = fixture(t, "base16-btop");
  const destination = path.join(f.home, ".config/btop/themes/current.theme");
  for (let i = 0; i < 2; i++) {
    const result = f.run();
    assert.equal(result.status, 0, result.stderr);
    assert.equal(readlinkSync(destination), f.theme);
    assert.equal(readFileSync(destination, "utf8"), "fixture theme contents\n");
  }
  assert.equal(f.signals(), "-SIGUSR2 btop\n-SIGUSR2 btop\n");
  // Replace a stale theme link on a later invocation.
  f.theme = path.join(path.dirname(f.theme), "replacement theme");
  writeFileSync(f.theme, "replacement\n");
  const result = f.run({ TINTY_THEME_FILE_PATH: f.theme, SIGNAL_STATUS: "0" });
  assert.equal(result.status, 0, result.stderr);
  assert.equal(readlinkSync(destination), f.theme);
  assert.equal(readFileSync(destination, "utf8"), "replacement\n");
});

for (const name of ["tinted-terminal", "base16-btop"]) {
  test(`${name} fails when a clean-home parent cannot be created`, (t) => {
    const f = fixture(t, name);
    writeFileSync(path.join(f.home, ".config"), "not a directory\n");
    assert.notEqual(f.run().status, 0);
    assert.equal(f.signals(), "");
  });

  for (const command of ["mkdir", name === "tinted-terminal" ? "cp" : "ln"]) {
    test(`${name} propagates ${command} failure without attempting reload`, (t) => {
      const f = fixture(t, name);
      f.stub(command, "exit 23");
      const result = f.run();
      assert.equal(result.status, 23, result.stderr);
      assert.equal(f.signals(), "");
    });
  }
}

test("btop does not treat a pkill error as an absent process", (t) => {
  const f = fixture(t, "base16-btop");
  assert.notEqual(f.run({ SIGNAL_STATUS: "2" }).status, 0);
  assert.equal(f.signals(), "-SIGUSR2 btop\n");
});
