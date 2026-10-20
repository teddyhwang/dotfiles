import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, statSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";

const hook = path.resolve("home/local/bin/tinty-opencode-hook");

function fixture(t) {
  const home = mkdtempSync(path.join(os.tmpdir(), "tinty-opencode-hook-"));
  t.after(() => rmSync(home, { recursive: true, force: true }));
  const config = path.join(home, ".config/opencode");
  const theme = path.join(home, "theme.json");
  writeFileSync(theme, [
    "{",
    '  "backgroundElement": { "dark": "base02", "light": "base02" },',
    '  "diffAddedBg": { "dark": "#123456" }, "diffRemovedBg": { "dark": "x" },',
    '  "diffAddedLineNumberBg": { "dark": "a" }, "diffAddedLineNumberBg": { "dark": "b" },',
    '  "diffRemovedLineNumberBg": { "dark": "" }',
    "}",
    "",
  ].join("\n"));
  // killall is stubbed so the test never signals a real opencode.
  const bin = path.join(home, "bin");
  mkdirSync(bin);
  writeFileSync(path.join(bin, "killall"), "#!/bin/sh\nexit 1\n", { mode: 0o755 });
  const run = (...args) => spawnSync(hook, args, {
    env: { ...process.env, HOME: home, PATH: `${bin}:${process.env.PATH}` }, encoding: "utf8",
  });
  return { config, theme, run };
}

test("tinty-opencode-hook installs the adjusted theme and creates a config that selects it", (t) => {
  const { config, theme, run } = fixture(t);
  const result = run(theme);
  assert.equal(result.status, 0, result.stderr);
  const installed = path.join(config, "themes/tinty-current.json");
  assert.equal(readFileSync(installed, "utf8"), [
    "{",
    '  "backgroundElement": { "dark": "base01", "light": "base02" },',
    '  "diffAddedBg": { "dark": "#1a2e1a" }, "diffRemovedBg": { "dark": "#2e1a1a" },',
    '  "diffAddedLineNumberBg": { "dark": "#1a2e1a" }, "diffAddedLineNumberBg": { "dark": "b" },',
    '  "diffRemovedLineNumberBg": { "dark": "#2e1a1a" }',
    "}",
    "",
  ].join("\n"));
  assert.equal(statSync(installed).mode & 0o777, 0o600);
  assert.equal(readFileSync(path.join(config, "opencode.json"), "utf8"), '{ "theme": "tinty-current" }\n');
});

test("tinty-opencode-hook replaces only the first theme key and never adds one", (t) => {
  const { config, theme, run } = fixture(t);
  mkdirSync(config, { recursive: true });
  writeFileSync(path.join(config, "opencode.jsonc"), '// comment\n{ "theme"\n  : "old", "x": { "theme": "nested" } }\n');
  writeFileSync(path.join(config, "opencode.json"), '{ "theme": "json" }\n');
  assert.equal(run(theme).status, 0);
  assert.equal(readFileSync(path.join(config, "opencode.jsonc"), "utf8"),
    '// comment\n{ "theme": "tinty-current", "x": { "theme": "nested" } }\n');
  assert.equal(readFileSync(path.join(config, "opencode.json"), "utf8"), '{ "theme": "json" }\n', "the .jsonc file wins");

  rmSync(path.join(config, "opencode.jsonc"));
  writeFileSync(path.join(config, "opencode.json"), '{ "a": 1 }\n');
  assert.equal(run(theme).status, 0);
  assert.equal(readFileSync(path.join(config, "opencode.json"), "utf8"), '{ "a": 1 }\n');
});

test("tinty-opencode-hook ignores a missing theme argument or file", (t) => {
  const { config, run } = fixture(t);
  for (const args of [[], [""], ["/nonexistent/theme.json"]]) {
    const result = run(...args);
    assert.equal(result.status, 0, result.stderr);
  }
  assert.throws(() => statSync(config), { code: "ENOENT" });
});
