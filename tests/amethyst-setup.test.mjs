import assert from "node:assert/strict";
import { chmod, mkdir, mkdtemp, readFile, readlink, readdir, rm, stat, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";

const repo = process.cwd();
const python = spawnSync("sh", ["-c", "command -v python3"], { encoding: "utf8" }).stdout.trim();
async function sandbox(t) {
  const home = await mkdtemp(path.join(tmpdir(), "amethyst-setup-"));
  t.after(() => rm(home, { recursive: true, force: true }));
  const bin = path.join(home, "bin");
  await mkdir(bin);
  const executable = async (name, body) => {
    await writeFile(path.join(bin, name), `#!/bin/sh\n${body}\n`);
    await chmod(path.join(bin, name), 0o755);
  };
  await symlink(python, path.join(bin, "python3"));
  await executable("pgrep", 'exit "${RUNNING:-1}"');
  await executable("defaults", `printf '%s\\n' "$*" >>"$HOME/calls"
case "$1" in
  read) test -f "$HOME/current.plist" ;;
  export) test "$EXPORT_FAIL" != 1 || exit 1; cp "$HOME/current.plist" "$3" ;;
  import) test "$IMPORT_FAIL" != 1 || exit 1; cp "$3" "$HOME/imported.plist"; cp "$3" "$HOME/current.plist" ;;
  *) exit 99 ;;
esac`);
  await executable("brew", `case "$1" in
  shellenv) exit 0 ;;
  --prefix) printf '%s/no-fzf\\n' "$HOME" ;;
  *) exit 0 ;;
esac`);
  await executable("herdr", "exit 0");
  const env = { ...process.env, HOME: home, PATH: `${bin}:/usr/bin:/bin`, EXPORT_FAIL: "0", IMPORT_FAIL: "0" };
  const run = (args = [], extra = {}, script = "amethyst.sh") => spawnSync("sh", [path.join(repo, "scripts", script), ...args], {
    env: { ...env, ...extra }, encoding: "utf8", input: "", timeout: 15000,
  });
  const plist = async (filename, value) => {
    const result = spawnSync(python, ["-c", "import plistlib,json,sys; plistlib.dump(json.loads(sys.argv[2]),open(sys.argv[1],'wb'))", path.join(home, filename), JSON.stringify(value)]);
    assert.equal(result.status, 0);
  };
  return { home, run, plist };
}

// Load only scalar/profile keys selected below; the saved snapshot contains data values.
function profile(home, filename) {
  const result = spawnSync(python, ["-c", `import plistlib,json,sys
p=plistlib.load(open(sys.argv[1],'rb'))
print(json.dumps({k:v for k,v in p.items() if k.startswith(('KeyboardShortcuts_', 'NS', 'SU', 'migrated-')) or k in ('EncodedWindowManager','unrelated')}))`, path.join(home, filename)], { encoding: "utf8" });
  assert.equal(result.status, 0, result.stderr);
  return JSON.parse(result.stdout);
}

for (const packaged of [false, true]) {
  test(`fresh HOME provisions both links and imports filtered preferences (packages=${packaged})`, async (t) => {
    const s = await sandbox(t);
    const result = s.run([], {}, packaged ? "packages_mac.sh" : "amethyst.sh");
    assert.equal(result.status, 0, result.stderr || result.stdout);
    assert.equal(await readlink(path.join(s.home, ".amethyst.yml")), path.join(repo, "apps/amethyst/amethyst.yml"));
    assert.equal(await readlink(path.join(s.home, "Library/Application Support/Amethyst/Layouts/uniform-columns.js")), path.join(repo, "apps/amethyst/uniform-columns.js"));
    const exactProfile = spawnSync(python, ["-c", `import plistlib,sys
saved=plistlib.load(open(sys.argv[1],'rb'))
actual=plistlib.load(open(sys.argv[2],'rb'))
assert actual == {k:v for k,v in saved.items() if k != 'EncodedWindowManager' and not k.startswith(('NS','SU'))}`, path.join(repo, "apps/amethyst/com.amethyst.Amethyst.plist"), path.join(s.home, "imported.plist")]);
    assert.equal(exactProfile.status, 0, exactProfile.stderr.toString());
    const imported = profile(s.home, "imported.plist");
    assert.ok(imported["KeyboardShortcuts_cycle-layout"]);
    assert.equal(imported["migrated-toggle-float"], true);
    assert.ok(!Object.keys(imported).some((key) => key.startsWith("NS") || key.startsWith("SU") || key === "EncodedWindowManager"));
    assert.equal(s.run().status, 0);
    assert.equal((await readFile(path.join(s.home, "calls"), "utf8")).match(/^import /gm).length, 1);
    assert.deepEqual((await readdir(path.join(s.home, ".local/state/dotfiles"))).filter((name) => name.startsWith("amethyst.")), []);
  });
}

test("existing stock domain is preserved; explicit restore backs up and merges profile", async (t) => {
  const s = await sandbox(t);
  const current = { KeyboardShortcuts_stockOnly: "stock", "KeyboardShortcuts_cycle-layout": "custom", NSWindow: "current", SUFeedURL: "current", EncodedWindowManager: "current", unrelated: "keep" };
  await s.plist("current.plist", current);
  let result = s.run();
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /amethyst.sh.*--restore-preferences/);
  assert.doesNotMatch(await readFile(path.join(s.home, "calls"), "utf8"), /import /);
  result = s.run(["--restore-preferences"]);
  assert.equal(result.status, 0, result.stderr || result.stdout);
  const imported = profile(s.home, "imported.plist");
  assert.equal(imported.KeyboardShortcuts_stockOnly, undefined);
  assert.notEqual(imported["KeyboardShortcuts_cycle-layout"], "custom");
  for (const key of ["NSWindow", "SUFeedURL", "EncodedWindowManager", "unrelated"]) assert.equal(imported[key], current[key]);
  const backups = await readdir(path.join(s.home, ".local/state/dotfiles/backups"));
  assert.equal(backups.length, 1);
  const backupDir = path.join(s.home, ".local/state/dotfiles/backups", backups[0]);
  assert.equal((await stat(backupDir)).mode & 0o777, 0o700);
  assert.equal((await stat(path.join(backupDir, "preferences.plist"))).mode & 0o777, 0o600);
  assert.deepEqual(profile(s.home, `.local/state/dotfiles/backups/${backups[0]}/preferences.plist`), current);
  const calls = await readFile(path.join(s.home, "calls"), "utf8");
  assert.ok(calls.indexOf("export ") < calls.indexOf("import "));
});

for (const existing of [false, true]) {
  test(`running app prevents import (existing=${existing})`, async (t) => {
    const s = await sandbox(t);
    if (existing) await s.plist("current.plist", { stock: true });
    const result = s.run(["--restore-preferences"], { RUNNING: "0" });
    assert.notEqual(result.status, 0);
    assert.match(result.stdout, /Quit Amethyst/);
    assert.doesNotMatch(await readFile(path.join(s.home, "calls"), "utf8"), /export |import /);
  });
}

for (const failure of ["EXPORT_FAIL", "IMPORT_FAIL"]) {
  test(`${failure} is reported without discarding backup`, async (t) => {
    const s = await sandbox(t);
    await s.plist("current.plist", { stock: true });
    const result = s.run(["--restore-preferences"], { [failure]: "1" });
    assert.notEqual(result.status, 0);
    assert.match(result.stdout, /Could not (export|import)/);
    if (failure === "EXPORT_FAIL") assert.doesNotMatch(await readFile(path.join(s.home, "calls"), "utf8"), /import /);
    else {
      const backups = await readdir(path.join(s.home, ".local/state/dotfiles/backups"));
      assert.equal(backups.length, 1);
    }
  });
}

test("an existing preference file is preserved even if defaults read fails", async (t) => {
  const s = await sandbox(t);
  const directory = path.join(s.home, "Library/Preferences");
  await mkdir(directory, { recursive: true });
  const prefs = path.join(directory, "com.amethyst.Amethyst.plist");
  await writeFile(prefs, "existing preferences\n");
  assert.equal(s.run().status, 0);
  assert.equal(await readFile(prefs, "utf8"), "existing preferences\n");
  await assert.rejects(readFile(path.join(s.home, "calls")), { code: "ENOENT" });
  assert.notEqual(s.run(["--restore-preferences"], { EXPORT_FAIL: "1" }).status, 0);
  assert.doesNotMatch(await readFile(path.join(s.home, "calls"), "utf8"), /import /);
});

test("process inspection errors refuse fresh import", async (t) => {
  const s = await sandbox(t);
  const result = s.run([], { RUNNING: "2" });
  assert.notEqual(result.status, 0);
  assert.match(result.stdout, /Could not determine/);
  assert.doesNotMatch(await readFile(path.join(s.home, "calls"), "utf8"), /import /);
});

test("unknown arguments fail before mutations and unsafe destinations are refused", async (t) => {
  const s = await sandbox(t);
  assert.notEqual(s.run(["--unknown"]).status, 0);
  assert.deepEqual(await readdir(s.home), ["bin"]);
  for (const home of ["/", "", "relative"]) assert.notEqual(s.run([], { HOME: home }).status, 0);
  const outside = await mkdtemp(path.join(tmpdir(), "amethyst-outside-"));
  t.after(() => rm(outside, { recursive: true, force: true }));
  await symlink(outside, path.join(s.home, "Library"));
  const result = s.run();
  assert.notEqual(result.status, 0);
  assert.match(result.stdout, /escapes HOME/);
  assert.deepEqual(await readdir(outside), []);
});
