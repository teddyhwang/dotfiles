import assert from "node:assert/strict";
import { chmod, mkdir, mkdtemp, readFile, rm, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";

const repo = process.cwd();

// A fake `defaults` keeps one file per key, so tests never touch real prefs.
async function sandbox(t) {
  const home = await mkdtemp(path.join(tmpdir(), "rex-preferences-"));
  t.after(() => rm(home, { recursive: true, force: true }));
  const bin = path.join(home, "bin");
  const store = path.join(home, "store");
  await mkdir(bin);
  await mkdir(store);
  const commands = {
    uname: 'printf "%s\\n" "${MOCK_OS:-Darwin}"',
    pgrep: "exit 1",
    defaults: `test "$2" = com.superlogical.rex || exit 98
case "$1" in
  read) cat "$HOME/store/$3" 2>/dev/null ;;
  write)
    printf '%s\\n' "$3" >>"$HOME/writes.log"
    case "$4:$5" in
      -bool:true) printf '1\\n' ;;
      -bool:false) printf '0\\n' ;;
      *) printf '%s\\n' "$5" ;;
    esac >"$HOME/store/$3" ;;
  *) exit 99 ;;
esac`,
  };
  for (const [name, body] of Object.entries(commands)) {
    await writeFile(path.join(bin, name), `#!/bin/sh\n${body}\n`);
    await chmod(path.join(bin, name), 0o755);
  }
  const run = (env = {}) => spawnSync("sh", [path.join(repo, "scripts/rex.sh")], {
    cwd: home, encoding: "utf8", input: "",
    env: { ...process.env, HOME: home, PATH: `${bin}:/usr/bin:/bin`, ...env },
  });
  const value = (key) => readFile(path.join(store, key), "utf8");
  const writes = async () => (await readFile(path.join(home, "writes.log"), "utf8").catch(() => "")).split("\n").filter(Boolean);
  return { home, store, run, value, writes };
}

test("writes Rex font and theme preferences, then is idempotent", async (t) => {
  const s = await sandbox(t);
  let result = s.run();
  assert.equal(result.status, 0, result.stderr || result.stdout);
  assert.equal(await s.value("Workspace.terminalFontName"), "JetBrainsMono Nerd Font\n");
  assert.equal(await s.value("Workspace.terminalFontPointSize"), "12\n");
  assert.equal(await s.value("Workspace.terminalFontSmoothing"), "1\n");
  assert.equal(await s.value("Workspace.darkThemeID"), "merino-dark\n");
  assert.equal(await s.value("Workspace.lightThemeID"), "merino-light\n");
  assert.equal((await s.writes()).length, 7);
  assert.match(result.stdout, /Rex preferences setup complete/);

  result = s.run();
  assert.equal(result.status, 0, result.stderr || result.stdout);
  assert.equal((await s.writes()).length, 7, "a rerun must not rewrite matching keys");
  assert.match(result.stdout, /Rex preferences already configured/);
});

test("rewrites only keys that differ", async (t) => {
  const s = await sandbox(t);
  assert.equal(s.run().status, 0);
  await writeFile(path.join(s.store, "Workspace.terminalFontPointSize"), "14\n");
  const result = s.run();
  assert.equal(result.status, 0, result.stderr || result.stdout);
  assert.deepEqual((await s.writes()).slice(7), ["Workspace.terminalFontPointSize"]);
  assert.equal(await s.value("Workspace.terminalFontPointSize"), "12\n");
});

test("skips on Linux and refuses a symlinked preferences file", async (t) => {
  const s = await sandbox(t);
  let result = s.run({ MOCK_OS: "Linux" });
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /macOS-only/);
  assert.deepEqual(await s.writes(), []);

  const prefs = path.join(s.home, "Library/Preferences");
  await mkdir(prefs, { recursive: true });
  await symlink(path.join(s.home, "elsewhere.plist"), path.join(prefs, "com.superlogical.rex.plist"));
  result = s.run();
  assert.notEqual(result.status, 0);
  assert.match(result.stdout, /Refusing a symlinked Rex preferences file/);
  assert.deepEqual(await s.writes(), []);
});
