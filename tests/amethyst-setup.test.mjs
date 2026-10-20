import assert from "node:assert/strict";
import { chmod, mkdir, mkdtemp, readFile, readlink, readdir, rm, stat, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { pathToFileURL } from "node:url";
import test from "node:test";
import { decodeText, encodeText, formatPlist, readPlist } from "../scripts/plist.mjs";

const repo = process.cwd();
const plistModule = pathToFileURL(path.join(repo, "scripts/plist.mjs")).href;

function plistValue(value) {
  if (typeof value === "boolean") return value ? "<true/>" : "<false/>";
  return `<string>${encodeText(value)}</string>`;
}

function plistScalar(raw) {
  const string = /^<string>([^<]*)<\/string>$/.exec(raw);
  if (string) return decodeText(string[1]);
  if (raw === "<string/>") return "";
  if (raw === "<true/>") return true;
  if (raw === "<false/>") return false;
  return raw;
}

async function sandbox(t) {
  const home = await mkdtemp(path.join(tmpdir(), "amethyst-setup-"));
  t.after(() => rm(home, { recursive: true, force: true }));
  const bin = path.join(home, "bin");
  await mkdir(bin);
  const executable = async (name, body) => {
    await writeFile(path.join(bin, name), `#!/bin/sh\n${body}\n`);
    await chmod(path.join(bin, name), 0o755);
  };
  await symlink(process.execPath, path.join(bin, "node"));
  await executable("pgrep", 'exit "${RUNNING:-1}"');
  // Native defaults import merges keys; only delete clears the domain.
  await writeFile(path.join(bin, "mock-defaults.mjs"), `import { appendFileSync, copyFileSync, existsSync, readFileSync, unlinkSync, writeFileSync } from "node:fs";
import path from "node:path";
import { formatPlist, readPlist } from ${JSON.stringify(plistModule)};
const home = process.env.HOME;
const current = path.join(home, "current.plist");
const args = process.argv.slice(2);
appendFileSync(path.join(home, "calls"), args.join(" ") + "\\n");
const operation = args[0];
if (operation === "read") {
  process.exit(existsSync(current) ? 0 : 1);
} else if (operation === "export") {
  if (process.env.EXPORT_FAIL === "1" || !existsSync(current)) process.exit(1);
  copyFileSync(current, args[2]);
} else if (operation === "delete") {
  if (process.env.DELETE_FAIL === "1" || !existsSync(current)) process.exit(1);
  unlinkSync(current);
} else if (operation === "import") {
  const counter = path.join(home, "import-count");
  const count = existsSync(counter) ? Number(readFileSync(counter, "utf8")) + 1 : 1;
  writeFileSync(counter, String(count));
  if (count > 1 && process.env.ROLLBACK_FAIL === "1") process.exit(1);
  if (count === 1 && process.env.IMPORT_FAIL_BEFORE_WRITE === "1") process.exit(1);
  const merged = existsSync(current) ? readPlist(current) : new Map();
  for (const [key, value] of readPlist(args[2])) merged.set(key, value);
  writeFileSync(current, formatPlist(merged));
  copyFileSync(current, path.join(home, "imported.plist"));
  // Simulate an import failure after partial/complete writes, not just before.
  if (count === 1 && process.env.IMPORT_FAIL === "1") process.exit(1);
} else {
  process.exit(99);
}
`);
  await executable("defaults", `exec '${process.execPath}' "$HOME/bin/mock-defaults.mjs" "$@"`);
  await executable("brew", `case "$1" in
  shellenv) exit 0 ;;
  --prefix) printf '%s/no-fzf\\n' "$HOME" ;;
  *) exit 0 ;;
esac`);
  await executable("herdr", "exit 0");
  const env = { ...process.env, HOME: home, PATH: `${bin}:/usr/bin:/bin`, EXPORT_FAIL: "0", IMPORT_FAIL: "0", IMPORT_FAIL_BEFORE_WRITE: "0", DELETE_FAIL: "0", ROLLBACK_FAIL: "0" };
  const run = (args = [], extra = {}, script = "amethyst.sh") => spawnSync("sh", [path.join(repo, "scripts", script), ...args], {
    env: { ...env, ...extra }, encoding: "utf8", input: "", timeout: 15000,
  });
  const plist = async (filename, value) => {
    const entries = new Map(Object.entries(value).map(([key, item]) => [key, plistValue(item)]));
    await writeFile(path.join(home, filename), formatPlist(entries));
  };
  return { home, bin, env, run, plist };
}

// Load only scalar/profile keys selected below; the saved snapshot contains data values.
function profile(home, filename) {
  const selected = [...readPlist(path.join(home, filename))].filter(([key]) =>
    ["KeyboardShortcuts_", "NS", "SU", "migrated-"].some((prefix) => key.startsWith(prefix)) ||
    ["EncodedWindowManager", "unrelated"].includes(key));
  return Object.fromEntries(selected.map(([key, raw]) => [key, plistScalar(raw)]));
}

for (const packaged of [false, true]) {
  test(`fresh HOME provisions both links and imports filtered preferences (packages=${packaged})`, async (t) => {
    const s = await sandbox(t);
    const result = s.run([], {}, packaged ? "packages_mac.sh" : "amethyst.sh");
    assert.equal(result.status, 0, result.stderr || result.stdout);
    assert.equal(await readlink(path.join(s.home, ".amethyst.yml")), path.join(repo, "apps/amethyst/amethyst.yml"));
    assert.equal(await readlink(path.join(s.home, "Library/Application Support/Amethyst/Layouts/uniform-columns.js")), path.join(repo, "apps/amethyst/uniform-columns.js"));
    const saved = readPlist(path.join(repo, "apps/amethyst/com.amethyst.Amethyst.plist"));
    assert.deepEqual(readPlist(path.join(s.home, "imported.plist")), new Map([...saved].filter(([key]) =>
      key !== "EncodedWindowManager" && !key.startsWith("NS") && !key.startsWith("SU"))));
    const imported = profile(s.home, "imported.plist");
    assert.ok(imported["KeyboardShortcuts_cycle-layout"]);
    assert.equal(imported["migrated-toggle-float"], true);
    assert.ok(!Object.keys(imported).some((key) => key.startsWith("NS") || key.startsWith("SU") || key === "EncodedWindowManager"));
    assert.equal(s.run().status, 0);
    const calls = await readFile(path.join(s.home, "calls"), "utf8");
    assert.equal(calls.match(/^import /gm).length, 1);
    assert.doesNotMatch(calls, /^delete /m);
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
  assert.ok(calls.indexOf("export ") < calls.indexOf("delete "));
  assert.ok(calls.indexOf("delete ") < calls.indexOf("import "));
});

for (const existing of [false, true]) {
  test(`running app prevents import (existing=${existing})`, async (t) => {
    const s = await sandbox(t);
    if (existing) await s.plist("current.plist", { stock: true });
    const result = s.run(["--restore-preferences"], { RUNNING: "0" });
    assert.notEqual(result.status, 0);
    assert.match(result.stdout, /Quit Amethyst/);
    assert.doesNotMatch(await readFile(path.join(s.home, "calls"), "utf8"), /export |delete |import /);
  });
}

for (const failure of ["EXPORT_FAIL", "IMPORT_FAIL", "IMPORT_FAIL_BEFORE_WRITE"]) {
  test(`${failure} is reported without discarding backup`, async (t) => {
    const s = await sandbox(t);
    await s.plist("current.plist", { stock: true });
    const result = s.run(["--restore-preferences"], { [failure]: "1" });
    assert.notEqual(result.status, 0);
    assert.match(result.stdout, /Could not (export|import)/);
    if (failure === "EXPORT_FAIL") assert.doesNotMatch(await readFile(path.join(s.home, "calls"), "utf8"), /delete |import /);
    else {
      const backups = await readdir(path.join(s.home, ".local/state/dotfiles/backups"));
      assert.equal(backups.length, 1);
      assert.match(result.stdout, /Rollback succeeded/);
      assert.deepEqual(await readFile(path.join(s.home, "current.plist")),
        await readFile(path.join(s.home, ".local/state/dotfiles/backups", backups[0], "preferences.plist")));
      const calls = await readFile(path.join(s.home, "calls"), "utf8");
      assert.equal(calls.match(/^delete /gm).length, failure === "IMPORT_FAIL_BEFORE_WRITE" ? 1 : 2);
      assert.equal(calls.match(/^import /gm).length, 2);
    }
  });
}

test("delete failure refuses reset and preserves the original domain and backup", async (t) => {
  const s = await sandbox(t);
  await s.plist("current.plist", { KeyboardShortcuts_stockOnly: "stock", NSWindow: "keep" });
  const before = await readFile(path.join(s.home, "current.plist"));
  const result = s.run(["--restore-preferences"], { DELETE_FAIL: "1" });
  assert.notEqual(result.status, 0);
  assert.match(result.stdout, /Could not delete.*refusing import/);
  assert.deepEqual(await readFile(path.join(s.home, "current.plist")), before);
  assert.doesNotMatch(await readFile(path.join(s.home, "calls"), "utf8"), /import /);
  const backups = await readdir(path.join(s.home, ".local/state/dotfiles/backups"));
  assert.deepEqual(await readFile(path.join(s.home, ".local/state/dotfiles/backups", backups[0], "preferences.plist")), before);
});

test("rollback import failure reports the preserved recovery backup", async (t) => {
  const s = await sandbox(t);
  await s.plist("current.plist", { KeyboardShortcuts_stockOnly: "original" });
  const before = await readFile(path.join(s.home, "current.plist"));
  const result = s.run(["--restore-preferences"], { IMPORT_FAIL: "1", ROLLBACK_FAIL: "1" });
  assert.notEqual(result.status, 0);
  assert.match(result.stdout, /Rollback failed.*Keep Amethyst closed.*preserved backup:/);
  assert.doesNotMatch(result.stdout, /Rollback succeeded/);
  const backups = await readdir(path.join(s.home, ".local/state/dotfiles/backups"));
  assert.deepEqual(await readFile(path.join(s.home, ".local/state/dotfiles/backups", backups[0], "preferences.plist")), before);
});

test("explicit restore initializes an absent domain without deleting it", async (t) => {
  const s = await sandbox(t);
  const result = s.run(["--restore-preferences"]);
  assert.equal(result.status, 0, result.stderr || result.stdout);
  assert.doesNotMatch(await readFile(path.join(s.home, "calls"), "utf8"), /delete |export /);
});

test("explicit restore of an absent domain never deletes; failed fresh import has no rollback", async (t) => {
  const s = await sandbox(t);
  const result = s.run(["--restore-preferences"], { IMPORT_FAIL: "1" });
  assert.notEqual(result.status, 0);
  assert.match(result.stdout, /Could not import/);
  assert.doesNotMatch(result.stdout, /Rollback/);
  const calls = await readFile(path.join(s.home, "calls"), "utf8");
  assert.doesNotMatch(calls, /delete |export /);
  assert.equal(calls.match(/^import /gm).length, 1);
});

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

test("plist helper keeps nested, data and date values verbatim and sorts keys", async () => {
  const { parsePlist } = await import("../scripts/plist.mjs");
  const source = `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<!-- comment -->
	<key>z &amp; &lt;key&gt;</key>
	<dict>
		<key>a</key>
		<array><dict><key>b</key><true/></dict><dict/></array>
	</dict>
	<key>data</key>
	<data>AAE=</data>
	<key>date</key>
	<date>2024-01-02T03:04:05Z</date>
	<key>empty</key>
	<string/>
</dict>
</plist>
`;
  const entries = parsePlist(source);
  assert.deepEqual([...entries.keys()], ["z & <key>", "data", "date", "empty"]);
  assert.equal(entries.get("z & <key>"), "<dict>\n\t\t<key>a</key>\n\t\t<array><dict><key>b</key><true/></dict><dict/></array>\n\t</dict>");
  assert.deepEqual(parsePlist(formatPlist(entries)), entries);
  assert.match(formatPlist(entries), /<key>data<\/key>[\s\S]*<key>date<\/key>[\s\S]*<key>empty<\/key>[\s\S]*<key>z &amp; &lt;key&gt;<\/key>/);
  assert.equal(parsePlist(formatPlist(new Map())).size, 0);
  for (const invalid of ["<plist><array/></plist>", "<plist><dict><key>a</key></dict></plist>", "<plist><dict><string>a</string><true/></dict></plist>", "<plist><dict>"]) {
    assert.throws(() => parsePlist(invalid), /plist:/);
  }
});

test("a missing node stops the import before any defaults change", { skip: ["/usr/bin/node", "/bin/node"].some(existsSync) && "node is installed in a system directory" }, async (t) => {
  const s = await sandbox(t);
  await rm(path.join(s.bin, "node"));
  const result = s.run(["--restore-preferences"]);
  assert.notEqual(result.status, 0);
  assert.match(result.stdout + result.stderr, /node is required.*run setup\.sh/);
  assert.doesNotMatch(await readFile(path.join(s.home, "calls"), "utf8"), /export |delete |import /);
});
