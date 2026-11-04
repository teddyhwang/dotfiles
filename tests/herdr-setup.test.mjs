import assert from "node:assert/strict";
import { chmod, copyFile, mkdir, mkdtemp, readFile, realpath, rm, writeFile } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

const repo = process.cwd();
const panes = ["workspace", "agent", "join-pane", "worktree"];
const events = ["workspace.focused", "tab.created", "tab.closed", "tab.renamed", "tab.moved", "tab.focused", "pane.created", "pane.closed", "pane.moved", "pane.exited", "pane.agent_detected", "pane.agent_status_changed"];
const legacySplits = {
  plugin_id: "herdr-splits",
  enabled: true,
  source: { kind: "github", owner: "lmilojevicc", repo: "herdr-splits.nvim", resolved_commit: "94f30cf4e9ac76ddf185a3acd0977be728fa4106" },
  actions: [{ id: "nav-left" }],
};

async function fixture(t, plugins) {
  const root = await realpath(await mkdtemp(path.join(tmpdir(), "dotfiles-herdr-setup-")));
  t.after(() => rm(root, { recursive: true, force: true }));
  for (const directory of ["scripts", "bin", ".local/bin"]) {
    await mkdir(path.join(root, directory), { recursive: true });
  }
  for (const script of ["herdr.sh", "utils.sh"]) {
    await copyFile(path.join(repo, "scripts", script), path.join(root, "scripts", script));
  }
  const worker = path.join(root, ".local/bin/herdr-tab-autoname");
  await writeFile(worker, "#!/bin/sh\nexit 0\n");
  await chmod(worker, 0o755);
  await writeFile(path.join(root, "plugins.json"), JSON.stringify(plugins));

  const herdr = path.join(root, "bin/herdr");
  await writeFile(herdr, `#!${process.execPath}
const { appendFileSync, readFileSync, writeFileSync } = require("node:fs");
const args = process.argv.slice(2);
const state = process.env.HOME + "/plugins.json";
let plugins = JSON.parse(readFileSync(state, "utf8"));
appendFileSync(process.env.HOME + "/calls", JSON.stringify(args) + "\\n");
if (args[0] !== "plugin") process.exit(1);
switch (args[1]) {
  case "list":
    console.log(JSON.stringify({ result: { plugins } }));
    break;
  case "uninstall":
    plugins = plugins.filter((plugin) => plugin.plugin_id !== args[2]);
    break;
  case "link":
    if (args[2].endsWith("/herdr-pickers")) {
      plugins.push({
        plugin_id: "teddyhwang.pickers",
        manifest_path: args[2] + "/herdr-plugin.toml",
        enabled: true,
        panes: ${JSON.stringify(panes)}.map((id) => ({ id })),
        warnings: null,
      });
    } else {
      plugins.push({
        plugin_id: "teddyhwang.tab-autoname",
        manifest_path: args[2] + "/herdr-plugin.toml",
        enabled: true,
        actions: [{ id: "refresh" }],
        events: ${JSON.stringify(events)}.map((on) => ({ on })),
        warnings: [],
      });
    }
    break;
  default:
    process.exit(1);
}
writeFileSync(state, JSON.stringify(plugins));
`);
  await chmod(herdr, 0o755);
  return {
    root,
    calls: async () => (await readFile(path.join(root, "calls"), "utf8")).trim().split("\n").map((line) => JSON.parse(line)),
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

for (const [name, plugins, uninstalls] of [
  ["a fresh install", [], []],
  ["a leftover herdr-splits plugin", [legacySplits], [["plugin", "uninstall", "herdr-splits"]]],
]) {
  test(`Herdr setup links local plugins and reruns with ${name}`, async (t) => {
    const fixtureData = await fixture(t, plugins);
    for (let index = 0; index < 2; index++) {
      const result = fixtureData.run();
      assert.equal(result.status, 0, result.stderr || result.stdout);
      if (index === 1) assert.match(result.stdout, /Herdr plugins already configured/);
    }
    const calls = await fixtureData.calls();
    assert.deepEqual(calls.filter((args) => args[1] === "install"), []);
    assert.deepEqual(calls.filter((args) => args[1] === "uninstall"), uninstalls);
    assert.deepEqual(calls.filter((args) => args[1] === "link"), [
      ["plugin", "link", path.join(fixtureData.root, "plugins/herdr-tab-autoname"), "--enabled"],
      ["plugin", "link", path.join(fixtureData.root, "plugins/herdr-pickers"), "--enabled"],
    ]);
  });
}

test("Herdr setup fails when herdr-splits survives the uninstall", async (t) => {
  const fixtureData = await fixture(t, [legacySplits]);
  const herdr = path.join(fixtureData.root, "bin/herdr");
  const source = await readFile(herdr, "utf8");
  await writeFile(herdr, source.replace('plugins = plugins.filter((plugin) => plugin.plugin_id !== args[2]);', ""));
  const result = fixtureData.run();
  assert.notEqual(result.status, 0);
  assert.match(result.stdout + result.stderr, /herdr-splits is still installed/);
});
