import assert from "node:assert/strict";
import { chmod, copyFile, mkdir, mkdtemp, readFile, realpath, rm, writeFile } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

const repo = process.cwd();
const fallbackRef = "94f30cf4e9ac76ddf185a3acd0977be728fa4106";
const localRef = "0123456789abcdef0123456789abcdef01234567";
const actions = ["nav-left", "nav-down", "nav-up", "nav-right", "resize-left", "resize-down", "resize-up", "resize-right"];
const events = ["workspace.focused", "tab.created", "tab.closed", "tab.renamed", "tab.moved", "tab.focused", "pane.created", "pane.closed", "pane.moved", "pane.exited", "pane.agent_detected", "pane.agent_status_changed"];

async function fixture(t, lockfile) {
  const root = await realpath(await mkdtemp(path.join(tmpdir(), "dotfiles-herdr-setup-")));
  t.after(() => rm(root, { recursive: true, force: true }));
  for (const directory of ["scripts", "home/config/nvim", "bin", ".local/bin"]) {
    await mkdir(path.join(root, directory), { recursive: true });
  }
  for (const script of ["herdr.sh", "utils.sh"]) {
    await copyFile(path.join(repo, "scripts", script), path.join(root, "scripts", script));
  }
  const lockPath = path.join(root, "home/config/nvim/lazy-lock.json");
  if (lockfile !== undefined) await writeFile(lockPath, lockfile);
  const worker = path.join(root, ".local/bin/herdr-tab-autoname");
  await writeFile(worker, "#!/bin/sh\nexit 0\n");
  await chmod(worker, 0o755);

  const herdr = path.join(root, "bin/herdr");
  await writeFile(herdr, `#!${process.execPath}
const { appendFileSync, existsSync, readFileSync, writeFileSync } = require("node:fs");
const args = process.argv.slice(2);
const state = process.env.HOME + "/plugins.json";
let plugins = existsSync(state) ? JSON.parse(readFileSync(state, "utf8")) : [];
appendFileSync(process.env.HOME + "/calls", JSON.stringify(args) + "\\n");
if (args[0] !== "plugin") process.exit(1);
switch (args[1]) {
  case "list":
    console.log(JSON.stringify({ result: { plugins } }));
    break;
  case "install":
    plugins = plugins.filter((plugin) => plugin.plugin_id !== "herdr-splits");
    plugins.push({
      plugin_id: "herdr-splits",
      enabled: true,
      source: { kind: "github", owner: "lmilojevicc", repo: "herdr-splits.nvim", resolved_commit: args[4] },
      actions: ${JSON.stringify(actions)}.map((id) => ({ id })),
    });
    break;
  case "link":
    plugins.push({
      plugin_id: "teddyhwang.tab-autoname",
      manifest_path: args[2] + "/herdr-plugin.toml",
      enabled: true,
      actions: [{ id: "refresh" }],
      events: ${JSON.stringify(events)}.map((on) => ({ on })),
      warnings: [],
    });
    break;
  default:
    process.exit(1);
}
writeFileSync(state, JSON.stringify(plugins));
`);
  await chmod(herdr, 0o755);
  return {
    root,
    lockPath,
    run: () => spawnSync("sh", [path.join(root, "scripts/herdr.sh")], {
      cwd: tmpdir(),
      env: {
        ...process.env,
        HOME: root,
        PATH: `${root}/bin:${process.env.PATH}`,
        XDG_CACHE_HOME: path.join(root, ".cache"),
      },
      encoding: "utf8",
      timeout: 10_000,
    }),
  };
}

for (const [name, lockfile, ref] of [
  ["no Neovim lockfile", undefined, fallbackRef],
  ["no splits entry in the Neovim lockfile", "{}\n", fallbackRef],
  ["a local Neovim pin", JSON.stringify({ "herdr-splits.nvim": { commit: localRef } }) + "\n", localRef],
]) {
  test(`Herdr setup installs and reruns with ${name}`, async (t) => {
    const fixtureData = await fixture(t, lockfile);
    for (let index = 0; index < 2; index++) {
      const result = fixtureData.run();
      assert.equal(result.status, 0, result.stderr || result.stdout);
      if (index === 1) assert.match(result.stdout, /Herdr plugins already configured/);
    }
    const calls = (await readFile(path.join(fixtureData.root, "calls"), "utf8")).trim().split("\n").map((line) => JSON.parse(line));
    assert.deepEqual(calls.filter((args) => args[1] === "install"), [
      ["plugin", "install", "lmilojevicc/herdr-splits.nvim", "--ref", ref, "--yes"],
    ]);
    assert.deepEqual(calls.filter((args) => args[1] === "link"), [
      ["plugin", "link", path.join(fixtureData.root, "plugins/herdr-tab-autoname"), "--enabled"],
    ]);
    if (lockfile === undefined) {
      await assert.rejects(readFile(fixtureData.lockPath), { code: "ENOENT" });
    } else {
      assert.equal(await readFile(fixtureData.lockPath, "utf8"), lockfile);
    }
  });
}

test("Herdr setup rejects a malformed local lockfile before changing plugins", async (t) => {
  const fixtureData = await fixture(t, "not JSON\n");
  const result = fixtureData.run();
  assert.notEqual(result.status, 0);
  assert.match(result.stdout, /Could not read Neovim lockfile/);
  await assert.rejects(readFile(path.join(fixtureData.root, "calls")), { code: "ENOENT" });
});
