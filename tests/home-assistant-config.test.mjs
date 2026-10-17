import assert from "node:assert/strict";
import { mkdir, mkdtemp, readFile, readlink, readdir, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";

const repo = process.cwd();
const configRoot = path.join(repo, "home/config/home-assistant");

test("Home Assistant site configuration contains only nonsecret connection settings", async () => {
  const settings = JSON.parse(await readFile(path.join(configRoot, "agent.json"), "utf8"));
  assert.deepEqual(Object.keys(settings).sort(), ["authClientId", "remoteConfigDir", "sshTarget", "url"]);
  const url = new URL(settings.url);
  const client = new URL(settings.authClientId);
  assert.ok(["http:", "https:"].includes(url.protocol));
  assert.equal(url.username + url.password + url.search + url.hash, "");
  assert.ok(["http:", "https:"].includes(client.protocol));
  assert.equal(client.username + client.password + client.search + client.hash, "");
  assert.equal(settings.sshTarget, `root@${url.hostname}`);
  assert.equal(settings.remoteConfigDir, "/homeassistant");
  assert.deepEqual((await readdir(configRoot)).sort(), ["agent.json", "site.md"]);
});

test("Home Assistant site runbook preserves the approved lock estimate and current dashboard workflow", async () => {
  const notes = await readFile(path.join(configRoot, "site.md"), "utf8");
  for (const text of ["home-assistant", "scripts/ha-api.mjs", "lovelace/config/save", "input_select.lyriq_door_estimate", "README-LYRIQ.md", "README-DASHBOARD.md", "one TPI client", "23 real HA Jinja tests"]) {
    assert.ok(notes.includes(text), `Missing maintained workflow: ${text}`);
  }
  assert.match(notes, /Do not send vehicle start\/stop\/lock\/unlock\/charging/);
  assert.match(notes, /Do not reset it on startup\/redeploy/);
  assert.match(notes, /Never repeat that seed/);
  assert.match(notes, /not live door-lock telemetry/i);
  assert.match(notes, /Do not add a timer to assume re-locking/);
  assert.match(notes, /cannot observe that door cycle/);
  assert.match(notes, /core\.config_entries|integration\/auth-storage/);
});

test("normal config linker installs the HA site without replacing foreign Pi skills", async (t) => {
  const home = await mkdtemp(path.join(tmpdir(), "dotfiles-ha-home-"));
  t.after(() => rm(home, { recursive: true, force: true }));
  const foreign = path.join(home, ".pi/agent/skills/foreign/SKILL.md");
  await mkdir(path.dirname(foreign), { recursive: true });
  await writeFile(foreign, "user/installer-owned skill\n");
  for (let pass = 0; pass < 2; pass++) {
    const result = spawnSync("sh", [path.join(repo, "scripts/linker.sh")], {
      cwd: tmpdir(), env: { ...process.env, HOME: home }, encoding: "utf8", input: "",
    });
    assert.equal(result.status, 0, result.stderr || result.stdout);
    assert.equal(await readlink(path.join(home, ".config/home-assistant")), configRoot);
    assert.deepEqual(
      JSON.parse(await readFile(path.join(home, ".config/home-assistant/agent.json"), "utf8")),
      JSON.parse(await readFile(path.join(configRoot, "agent.json"), "utf8")),
    );
    assert.equal(await readFile(foreign, "utf8"), "user/installer-owned skill\n");
  }
});
