import assert from "node:assert/strict";
import { lstat, mkdir, mkdtemp, readFile, readdir, readlink, realpath, rm, stat, symlink, writeFile } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import os from "node:os";
import path from "node:path";
import test from "node:test";

const repo = process.cwd();
const baseline = JSON.parse(await readFile(path.join(repo, "apps/pi/packages.json"), "utf8"));
const herdSource = baseline.packages[3];
const roles = ["generalist", "implementer", "researcher", "reviewer", "scout"];
// Native command mock (pi, git, npm, node, herdr), implemented in Node.
const mock = "#!" + process.execPath + "\n" + String.raw`const fs = require('fs'), path = require('path'), assert = require('assert'), cp = require('child_process');
const home = process.env.HOME;
const name = path.basename(process.argv[1]);
const args = process.argv.slice(2);
// pi.sh runs the provisioner through the first node on PATH, which is this mock.
if (name === 'node' && args[0] && path.basename(args[0]) === 'pi_packages.mjs') {
  process.exit(cp.spawnSync(process.execPath, args, { stdio: 'inherit' }).status ?? 1);
}
fs.appendFileSync(path.join(home, 'calls'), JSON.stringify({name, args, cwd: process.cwd(), agent: process.env.PI_CODING_AGENT_DIR ?? null}) + '\n');
const agent = path.join(home, '.pi/agent');
const write = (file, text) => fs.writeFileSync(file, text);
const mkdirp = (dir) => fs.mkdirSync(dir, { recursive: true });
function artifact(source) {
  if (source.startsWith('/') || source.startsWith('~/')) return source.replace('~', () => home);
  if (source.startsWith('npm:')) {
    let name = source.slice(4);
    if (name.slice(1).includes('@')) name = name.slice(0, name.lastIndexOf('@'));
    return path.join(agent, 'npm/node_modules', name);
  }
  // Pi accepts SCP/shorthand only with git:, or explicit protocol URLs.
  assert.ok(source.startsWith('git:') || ['https://', 'http://', 'ssh://', 'git://'].some(p => source.startsWith(p)));
  if (source.startsWith('git:')) source = source.slice(4);
  source = source.replace(/^(https?:\/\/github.com\/|ssh:\/\/git@github.com\/|git:\/\/github.com\/|git@github.com:|github.com\/)/, '');
  source = source.split('@')[0];
  if (source.endsWith('.git')) source = source.slice(0, -4);
  return path.join(agent, 'git/github.com', source);
}
if (name === 'pi') {
  assert.ok(args[0] === 'install' && args.length === 3 && args[2] === '--no-approve');
  assert.equal(process.cwd(), home);
  assert.equal(process.env.PI_CODING_AGENT_DIR, agent);
  const source = args[1];
  mkdirp(agent);
  const settings = path.join(agent, 'settings.json');
  const data = fs.existsSync(settings) ? JSON.parse(fs.readFileSync(settings, 'utf8')) : {};
  if (!data.packages) data.packages = [];
  if (!data.packages.some(e => (typeof e === 'string' ? e : e.source) === source)) data.packages.push(source);
  write(settings, JSON.stringify(data));
  if (process.env.FAIL_PI && source.includes(process.env.FAIL_PI)) process.exit(8);
  const target = artifact(source);
  mkdirp(target);
  write(path.join(target, 'package.json'), '{}');
  const marker = path.join(path.dirname(target), '.' + path.basename(target) + '.pi-update-incomplete');
  if (!process.env.KEEP_MARKER && fs.existsSync(marker)) fs.unlinkSync(marker);
  if (target.toLowerCase().includes('pi-herdsman')) {
    mkdirp(path.join(target, 'scripts'));
    write(path.join(target, 'scripts/build.mjs'), '// upstream build fixture');
  }
} else if (name === 'git') {
  assert.deepEqual([args[0], ...args.slice(2)], ['-C', 'config', '--get', 'remote.origin.url']);
  if (path.basename(args[1]) === 'legacy-herdsman') console.log('git@github.com:boadij/pi-herdsman.git');
  else process.exit(1);
} else if (name === 'npm' && args.includes('--global')) {
  assert.deepEqual(args, ['install', '--global', '--prefix', path.join(home, '.local'), '--ignore-scripts', '--no-audit', '--no-fund', '@earendil-works/pi-coding-agent']);
  if (process.env.FAIL_INSTALL) process.exit(7);
  mkdirp(path.join(home, '.local/bin'));
  fs.copyFileSync(process.argv[1], path.join(home, '.local/bin/pi'));
  fs.chmodSync(path.join(home, '.local/bin/pi'), 0o755);
} else if (name === 'npm') {
  assert.deepEqual(args, ['install', '--prefix', path.join(home, '.cache/pi-herdsman-build'), '--no-audit', '--no-fund', 'esbuild@0.28.2']);
  const target = path.join(home, '.cache/pi-herdsman-build/node_modules/esbuild');
  mkdirp(target);
  write(path.join(target, 'package.json'), '{}');
} else if (name === 'node') {
  assert.deepEqual(args, [path.join(process.cwd(), 'scripts/build.mjs')]);
  if (process.env.FAIL_BUILD) process.exit(9);
  assert.ok(fs.statSync(path.join(process.cwd(), 'node_modules/esbuild/package.json')).isFile());
  const target = path.join(process.cwd(), 'dist');
  mkdirp(path.join(target, 'agent-definitions'));
  write(path.join(target, 'index.js'), '// bundled');
  for (const role of ['generalist', 'implementer', 'researcher', 'reviewer', 'scout']) write(path.join(target, 'agent-definitions', role + '.md'), role);
} else if (name === 'herdr') {
  assert.deepEqual(args, ['integration', 'install', 'pi']);
} else throw new Error('unexpected native command');
`;

async function fixture(t, { pi = "path", herdr = true, node = true } = {}) {
  const base = await realpath(await mkdtemp(path.join(os.tmpdir(), "dotfiles-pi-")));
  t.after(() => rm(base, { recursive: true, force: true }));
  const home = path.join(base, "home");
  const bin = path.join(base, "bin");
  await mkdir(home);
  await mkdir(bin);
  await symlink("/usr/bin/dirname", path.join(bin, "dirname"));
  // The mock `node` hands pi_packages.mjs to the real Node (process.execPath).
  const commands = ["npm", "git", ...(node ? ["node"] : []), ...(herdr ? ["herdr"] : [])];
  if (pi === "path") commands.push("pi");
  for (const name of commands) await writeFile(path.join(bin, name), mock, { mode: 0o755 });
  if (pi === "local" || pi === "agent") {
    const filename = path.join(home, pi === "local" ? ".local/bin/pi" : ".pi/agent/bin/pi");
    await mkdir(path.dirname(filename), { recursive: true });
    await writeFile(filename, mock, { mode: 0o755 });
  }
  const settings = path.join(home, ".pi/agent/settings.json");
  async function set(data) {
    await mkdir(path.dirname(settings), { recursive: true });
    await writeFile(settings, typeof data === "string" ? data : JSON.stringify(data));
  }
  function run(extra = {}, args = []) {
    return spawnSync("/bin/sh", [path.join(repo, "scripts/pi.sh"), ...args], {
      cwd: base, encoding: "utf8", timeout: 10_000,
      env: { HOME: home, PATH: bin, PI_CODING_AGENT_DIR: "/wrong-agent", ...extra },
    });
  }
  async function calls() {
    try { return (await readFile(path.join(home, "calls"), "utf8")).trim().split("\n").filter(Boolean).map(JSON.parse); }
    catch (error) { if (error.code === "ENOENT") return []; throw error; }
  }
  return { home, bin, settings, set, run, calls,
    data: async () => JSON.parse(await readFile(settings, "utf8")),
    clear: () => writeFile(path.join(home, "calls"), "") };
}
function ok(result) { assert.equal(result.status, 0, result.stderr || result.stdout); }
function herdPath(f) { return path.join(f.home, ".pi/agent/git/github.com/boadij/pi-herdsman"); }
async function completeHerd(checkout) {
  await mkdir(path.join(checkout, "scripts"), { recursive: true });
  await writeFile(path.join(checkout, "scripts/build.mjs"), "// upstream fixture\n");
  await writeFile(path.join(checkout, "package.json"), "{}");
}

test("fresh provisioning installs five packages, filters and defaults, builds upstream and integrates", async (t) => {
  const f = await fixture(t);
  // Untouched even when malformed: these files are not provisioning inputs.
  const auth = path.join(f.home, ".pi/agent/auth.json");
  await mkdir(path.dirname(auth), { recursive: true });
  for (const name of ["auth.json", "mcp.json", "trust.json"]) {
    await writeFile(path.join(path.dirname(auth), name), "PRIVATE invalid JSON");
  }
  ok(f.run());
  assert.deepEqual(await f.data(), baseline);
  const calls = await f.calls();
  assert.deepEqual(calls.filter(c => c.name === "pi").map(c => c.args[1]), baseline.packages.map(e => typeof e === "string" ? e : e.source));
  assert.equal(calls.filter(c => c.name === "npm").length, 1);
  assert.equal(calls.filter(c => c.name === "node").length, 1);
  assert.deepEqual(calls.at(-1).args, ["integration", "install", "pi"]);
  assert.equal((await stat(f.settings)).mode & 0o777, 0o600);
  for (const role of roles) await stat(path.join(herdPath(f), `dist/agent-definitions/${role}.md`));
  for (const name of ["auth.json", "mcp.json", "trust.json"]) {
    assert.equal(await readFile(path.join(path.dirname(auth), name), "utf8"), "PRIVATE invalid JSON");
  }
  const before = await stat(f.settings);
  const backups = path.join(f.home, ".local/state/dotfiles/backups");
  const backupCount = (await readdir(backups)).length;
  await f.clear();
  ok(f.run());
  assert.deepEqual((await f.calls()).map(c => c.name), ["herdr"]);
  assert.equal((await stat(f.settings)).mtimeMs, before.mtimeMs);
  assert.equal((await readdir(backups)).length, backupCount);
});

test("existing machine values, SSH equivalents, pinned refs, package filters and unrelated packages survive repair", async (t) => {
  const f = await fixture(t);
  const existing = {
    packages: [
      "npm:pi-vim@1.2.3",
      { source: "git:git@github.com:teddyhwang/pi-extensions.git@custom", extensions: [], skills: ["mine"] },
      { source: "ssh://git@github.com/davebcn87/pi-autoresearch.git@pin", skills: ["custom"] },
      { source: "git:github.com/boadij/pi-herdsman@other-pin", extensions: ["only"] },
      "npm:@gotgenes/pi-anthropic-auth@9.9.9", "npm:unrelated",
    ],
    extensions: [], skills: ["custom"], defaultTools: ["read"],
    defaultProvider: "private", models: { custom: true }, credentials: { secret: "not-output" }, unknown: [1, 2],
  };
  await f.set(existing);
  ok(f.run());
  assert.deepEqual(await f.data(), existing);
  assert.deepEqual((await f.calls()).filter(c => c.name === "pi").map(c => c.args[1]), existing.packages.slice(0, 5).map(e => typeof e === "string" ? e : e.source));
  await f.clear();
  const bytes = await readFile(f.settings);
  const mtime = (await stat(f.settings)).mtimeMs;
  const rerun = f.run();
  ok(rerun);
  assert.doesNotMatch(rerun.stdout + rerun.stderr, /not-output/);
  assert.deepEqual(await readFile(f.settings), bytes);
  assert.equal((await stat(f.settings)).mtimeMs, mtime);
  assert.deepEqual((await f.calls()).map(c => c.name), ["herdr"]);
});

test("legacy local Herdsman is identified by read-only origin and built in place without a duplicate", async (t) => {
  const f = await fixture(t);
  const local = path.join(f.home, "src/legacy-herdsman");
  await completeHerd(local);
  const entry = { source: local, extensions: ["mine"], skills: [] };
  await f.set({ packages: [entry] });
  ok(f.run());
  const data = await f.data();
  assert.deepEqual(data.packages[0], entry);
  assert.equal(data.packages.length, 5);
  const calls = await f.calls();
  assert.equal(calls.filter(c => c.name === "pi").length, 4);
  assert.equal(calls.find(c => c.name === "node").cwd, local);
  assert.ok(!calls.some(c => c.name === "pi" && c.args.includes(herdSource)));
});

for (const location of ["missing", "local", "agent"]) {
  test(`Pi discovery: ${location}`, async (t) => {
    const f = await fixture(t, { pi: location, herdr: false });
    const result = f.run();
    ok(result);
    if (location === "missing") {
      assert.match(result.stdout, /installing Pi with npm/);
      assert.equal((await f.calls())[0].name, "npm");
      assert.deepEqual(await f.data(), baseline);
      await f.clear();
      ok(f.run());
      assert.deepEqual(await f.calls(), []);
    } else {
      assert.equal((await f.calls()).filter(c => c.name === "pi").length, 5);
      assert.match(result.stdout, /herdr integration install pi/);
    }
  });
}

test("Pi installation failure stops before settings or extension changes", async (t) => {
  const f = await fixture(t, { pi: "missing" });
  const result = f.run({ FAIL_INSTALL: "1" });
  assert.equal(result.status, 1);
  assert.match(result.stderr, /npm failed/);
  await assert.rejects(stat(f.settings), { code: "ENOENT" });
  assert.equal((await f.calls()).length, 1);
});

test("repairs missing artifacts and missing dist outputs without upgrades or replacing existing esbuild", async (t) => {
  const f = await fixture(t);
  ok(f.run());
  const esbuild = path.join(herdPath(f), "node_modules/esbuild");
  await rm(esbuild);
  await mkdir(esbuild);
  await writeFile(path.join(esbuild, "owned"), "keep");
  await writeFile(path.join(esbuild, "package.json"), "{}");
  await rm(path.join(herdPath(f), "dist/agent-definitions/scout.md"));
  await rm(path.join(f.home, ".pi/agent/npm/node_modules/pi-vim"), { recursive: true });
  await f.clear();
  ok(f.run());
  const calls = await f.calls();
  assert.deepEqual(calls.filter(c => c.name === "pi").map(c => c.args[1]), ["npm:pi-vim"]);
  assert.equal(calls.filter(c => c.name === "node").length, 1);
  assert.equal(calls.filter(c => c.name === "npm").length, 0);
  assert.equal(await readFile(path.join(esbuild, "owned"), "utf8"), "keep");
});

test("Pi failure preserves successful filters and retry resumes with baseline filters", async (t) => {
  const f = await fixture(t);
  const result = f.run({ FAIL_PI: "autoresearch" });
  assert.notEqual(result.status, 0);
  let data = await f.data();
  assert.deepEqual(data.packages, baseline.packages.slice(0, 2));
  assert.ok(!(await f.calls()).some(c => c.name === "herdr"));
  await f.clear();
  ok(f.run());
  data = await f.data();
  assert.deepEqual(data, baseline);
  assert.equal((await f.calls()).filter(c => c.name === "pi").length, 3);
});

test("private Git package failures explain machine-local authentication without losing progress", async (t) => {
  const f = await fixture(t);
  const result = f.run({ FAIL_PI: "pi-extensions" });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /repository is private.*gh auth login.*gh auth setup-git/);
  assert.match(result.stderr, /No credentials are copied/);
  assert.deepEqual((await f.data()).packages, baseline.packages.slice(0, 1));
  assert.ok(!(await f.calls()).some(c => c.name === "herdr"));
});

test("build failure stops integration; retry builds without reinstalling Herdsman", async (t) => {
  const f = await fixture(t);
  const result = f.run({ FAIL_BUILD: "1" });
  assert.notEqual(result.status, 0);
  assert.ok(!(await f.calls()).some(c => c.name === "herdr"));
  assert.equal((await f.data()).packages.length, 4);
  await f.clear();
  ok(f.run());
  assert.deepEqual((await f.calls()).filter(c => c.name === "pi").map(c => c.args[1]), ["npm:@gotgenes/pi-anthropic-auth"]);
});

for (const bad of ["{broken", "[]", { packages: {} }, { packages: [1] }, { extensions: false },
  { defaultTools: "read" }, { packages: [{ source: "npm:pi-vim", skills: null }] }]) {
  test(`malformed settings fail before native commands or writes: ${JSON.stringify(bad)}`, async (t) => {
    const f = await fixture(t);
    await f.set(bad);
    const before = await readFile(f.settings);
    assert.notEqual(f.run().status, 0);
    assert.deepEqual(await readFile(f.settings), before);
    assert.deepEqual(await f.calls(), []);
  });
}

for (const unsafe of ["settings", ".pi", ".cache", ".local", "dist", "cache-modules", "package-json", "local-herd"]) {
  test(`unsafe ${unsafe} fails before native commands or writes`, async (t) => {
    const f = await fixture(t);
    const outside = path.join(path.dirname(f.home), "outside");
    await mkdir(outside);
    if (unsafe === "settings") {
      const target = path.join(outside, "settings.json");
      await writeFile(target, "{}");
      await mkdir(path.dirname(f.settings), { recursive: true });
      await symlink(target, f.settings);
    } else if (unsafe === "dist") {
      await completeHerd(herdPath(f));
      await symlink(outside, path.join(herdPath(f), "dist"));
    } else if (unsafe === "cache-modules") {
      const cache = path.join(f.home, ".cache/pi-herdsman-build");
      await mkdir(cache, { recursive: true });
      await symlink(outside, path.join(cache, "node_modules"));
    } else if (unsafe === "package-json") {
      const target = path.join(f.home, ".pi/agent/npm/node_modules/pi-vim");
      await mkdir(target, { recursive: true });
      await symlink(path.join(outside, "missing.json"), path.join(target, "package.json"));
    } else if (unsafe === "local-herd") {
      const local = path.join(outside, "legacy-herdsman");
      await completeHerd(local);
      await f.set({ packages: [local] });
    } else {
      await symlink(outside, path.join(f.home, unsafe));
    }
    assert.notEqual(f.run().status, 0);
    const calls = await f.calls();
    // Origin identification is read-only; no install/build/integration may run.
    assert.ok(calls.every(c => c.name === "git"));
    assert.deepEqual(await readdir(outside), unsafe === "settings" ? ["settings.json"] : unsafe === "local-herd" ? ["legacy-herdsman"] : []);
  });
}

for (const home of ["", "/", "relative"]) {
  test(`rejects invalid HOME ${JSON.stringify(home)}`, async (t) => {
    const f = await fixture(t);
    assert.notEqual(f.run({ HOME: home }).status, 0);
    assert.deepEqual(await f.calls(), []);
  });
}

test("settings changes retain an original private backup and unknown configuration", async (t) => {
  const f = await fixture(t);
  const original = '{"unknown": "preserve", "defaultTools": []}\n';
  await f.set(original);
  ok(f.run());
  const backups = path.join(f.home, ".local/state/dotfiles/backups");
  const entries = await readdir(backups);
  const contents = await Promise.all(entries.map(e => readFile(path.join(backups, e, "settings.json"), "utf8")));
  assert.ok(contents.includes(original));
  for (const entry of entries) {
    assert.equal((await stat(path.join(backups, entry))).mode & 0o777, 0o700);
    assert.equal((await stat(path.join(backups, entry, "settings.json"))).mode & 0o777, 0o600);
  }
  assert.equal((await f.data()).unknown, "preserve");
  assert.deepEqual((await f.data()).defaultTools, []);
});

for (const filename of [".gitignore", "package.json", "package-lock.json", "npm-shrinkwrap.json", "node_modules/.package-lock.json", "node_modules/.bin"]) {
  test(`escaping native npm support path ${filename} fails before commands or writes`, async (t) => {
    const f = await fixture(t);
    await f.set({ unknown: "unchanged" });
    const original = await readFile(f.settings);
    const outside = path.join(path.dirname(f.home), "external-state");
    await mkdir(outside);
    const sentinel = path.join(outside, "sentinel");
    await writeFile(sentinel, "do not modify");
    const target = path.join(f.home, ".pi/agent/npm", filename);
    await mkdir(path.dirname(target), { recursive: true });
    await symlink(filename.endsWith(".bin") ? outside : sentinel, target);
    assert.notEqual(f.run().status, 0);
    assert.deepEqual(await f.calls(), []);
    assert.deepEqual(await readFile(f.settings), original);
    assert.equal(await readFile(sentinel, "utf8"), "do not modify");
    await assert.rejects(stat(path.join(f.home, ".local/state/dotfiles/backups")), { code: "ENOENT" });
  });
}

test("surviving manifests with native incomplete-update markers are repaired; failed retry retains progress", async (t) => {
  const f = await fixture(t);
  ok(f.run());
  const checkout = path.join(f.home, ".pi/agent/git/github.com/teddyhwang/pi-extensions");
  const marker = path.join(path.dirname(checkout), ".pi-extensions.pi-update-incomplete");
  await writeFile(marker, "");
  await f.clear();
  const settings = await f.data();
  assert.notEqual(f.run({ FAIL_PI: "pi-extensions" }).status, 0);
  assert.deepEqual(await f.data(), settings);
  await stat(path.join(checkout, "package.json"));
  await stat(marker);
  assert.deepEqual((await f.calls()).map(c => c.name), ["pi"]);
  await f.clear();
  ok(f.run());
  assert.deepEqual((await f.calls()).filter(c => c.name === "pi").map(c => c.args[1]), [baseline.packages[1].source]);
  await assert.rejects(stat(marker), { code: "ENOENT" });
  assert.deepEqual(await f.data(), settings);
  await f.clear();
  ok(f.run());
  assert.deepEqual((await f.calls()).map(c => c.name), ["herdr"]);
});

test("a native install that leaves its incomplete-update marker is not reported healthy", async (t) => {
  const f = await fixture(t);
  ok(f.run());
  const marker = path.join(f.home, ".pi/agent/git/github.com/teddyhwang/.pi-extensions.pi-update-incomplete");
  await writeFile(marker, "");
  await f.clear();
  assert.notEqual(f.run({ KEEP_MARKER: "1" }).status, 0);
  assert.deepEqual((await f.calls()).map(c => c.name), ["pi"]);
});

test("evicted helper esbuild cache is restored behind its original symlink, then reruns are no-ops", async (t) => {
  const f = await fixture(t);
  ok(f.run());
  const esbuild = path.join(herdPath(f), "node_modules/esbuild");
  const link = await readlink(esbuild);
  const inode = (await lstat(esbuild)).ino;
  await rm(path.join(f.home, ".cache/pi-herdsman-build"), { recursive: true });
  await rm(path.join(herdPath(f), "dist/index.js"));
  await f.clear();
  ok(f.run());
  assert.equal(await readlink(esbuild), link);
  assert.equal((await lstat(esbuild)).ino, inode);
  assert.deepEqual((await f.calls()).map(c => c.name), ["npm", "node", "herdr"]);
  await stat(path.join(esbuild, "package.json"));
  await f.clear();
  ok(f.run());
  assert.deepEqual((await f.calls()).map(c => c.name), ["herdr"]);
});

for (const dangling of [false, true]) {
  test(`foreign ${dangling ? "dangling" : "existing"} esbuild symlink is never replaced or populated`, async (t) => {
    const f = await fixture(t);
    ok(f.run());
    const esbuild = path.join(herdPath(f), "node_modules/esbuild");
    const foreign = path.join(f.home, "my-esbuild");
    if (!dangling) {
      await mkdir(foreign);
      await writeFile(path.join(foreign, "package.json"), "{}");
      await writeFile(path.join(foreign, "owned"), "keep");
    }
    await rm(esbuild);
    await symlink(foreign, esbuild);
    await rm(path.join(herdPath(f), "dist/index.js"));
    await rm(path.join(f.home, ".cache/pi-herdsman-build"), { recursive: true });
    await f.clear();
    const result = f.run();
    if (dangling) assert.notEqual(result.status, 0);
    else ok(result);
    assert.equal(await readlink(esbuild), foreign);
    assert.ok(!(await f.calls()).some(c => ["pi", "npm"].includes(c.name)));
    if (dangling) await assert.rejects(stat(foreign), { code: "ENOENT" });
    else assert.equal(await readFile(path.join(foreign, "owned"), "utf8"), "keep");
  });
}

test("case-insensitive GitHub identity preserves native owner/repository checkout spelling", async (t) => {
  const f = await fixture(t);
  const source = "git:https://github.com/BoAdIj/Pi-HeRdSmAn@machine-pin";
  await f.set({ packages: [{ source, extensions: [] }] });
  ok(f.run());
  const checkout = path.join(f.home, ".pi/agent/git/github.com/BoAdIj/Pi-HeRdSmAn");
  assert.ok((await readdir(path.dirname(checkout))).includes("Pi-HeRdSmAn"));
  const calls = await f.calls();
  assert.deepEqual(calls.filter(c => c.name === "pi" && /herdsman/i.test(c.args[1])).map(c => c.args[1]), [source]);
  assert.equal(calls.find(c => c.name === "node").cwd, checkout);
  assert.equal((await f.data()).packages.length, 5);
  assert.deepEqual((await f.data()).packages[0], { source, extensions: [] });
  await f.clear();
  ok(f.run());
  assert.deepEqual((await f.calls()).map(c => c.name), ["herdr"]);
});

test("unknown arguments fail before commands or configuration changes", async (t) => {
  const f = await fixture(t);
  const result = f.run({}, ["--dry-run"]);
  assert.equal(result.status, 2);
  assert.match(result.stderr, /Usage:/);
  assert.deepEqual(await f.calls(), []);
  await assert.rejects(stat(f.settings), { code: "ENOENT" });
});

test("missing node fails with a clear message before commands or configuration changes", async (t) => {
  const f = await fixture(t, { node: false });
  const result = f.run();
  assert.equal(result.status, 1);
  assert.match(result.stderr, /pi\.sh: node is required; install packages first \(run setup\.sh\)/);
  assert.deepEqual(await f.calls(), []);
  await assert.rejects(stat(f.settings), { code: "ENOENT" });
});

test("setup invokes Pi provisioning once at the common end after linking and Herdr", async () => {
  const setup = await readFile(path.join(repo, "setup.sh"), "utf8");
  assert.equal((setup.match(/scripts\/pi\.sh/g) || []).length, 1);
  assert.ok(setup.indexOf("scripts/pi.sh") > setup.lastIndexOf("scripts/herdr.sh"));
  assert.match(setup, /esac\s+sh "\$\{SCRIPT_DIR\}\/scripts\/github.sh"\s+sh "\$\{SCRIPT_DIR\}\/scripts\/pi.sh"\s+print_success/);
});
