import assert from "node:assert/strict";
import { mkdtemp, mkdir, writeFile, readFile, rm } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import os from "node:os";
import path from "node:path";
import test from "node:test";

for (const state of ["authenticated", "missing-login", "missing-gh", "helper-failure"]) {
  test(`GitHub setup: ${state}`, async (t) => {
    const base = await mkdtemp(path.join(os.tmpdir(), "dotfiles-github-"));
    t.after(() => rm(base, { recursive: true, force: true }));
    const bin = path.join(base, "bin");
    await mkdir(bin);
    const log = path.join(base, "calls");
    if (state !== "missing-gh") {
      await writeFile(path.join(bin, "gh"), `#!${process.execPath}
const fs = require('node:fs');
const args = process.argv.slice(2);
fs.appendFileSync(process.env.LOG, JSON.stringify(args) + '\\n');
if (args[1] === 'status' && process.env.STATE === 'missing-login') process.exit(1);
if (args[1] === 'setup-git' && process.env.STATE === 'helper-failure') process.exit(2);
`, { mode: 0o755 });
    }
    const result = spawnSync("/bin/sh", [path.resolve("scripts/github.sh")], {
      encoding: "utf8", env: { PATH: bin, HOME: base, STATE: state, LOG: log },
    });
    if (state === "missing-gh") {
      assert.equal(result.status, 1);
      assert.match(result.stderr, /gh is required/);
      return;
    }
    const calls = (await readFile(log, "utf8")).trim().split("\n").map(JSON.parse);
    assert.deepEqual(calls[0], ["auth", "status", "--hostname", "github.com"]);
    if (state === "missing-login") {
      assert.equal(result.status, 1);
      assert.match(result.stderr, /login required/);
      assert.equal(calls.length, 1);
    } else {
      assert.equal(result.status, state === "helper-failure" ? 2 : 0);
      assert.deepEqual(calls[1], ["auth", "setup-git", "--hostname", "github.com"]);
    }
  });
}
