import assert from "node:assert/strict";
import { lstat, mkdir, mkdtemp, readFile, readdir, readlink, rm, symlink, writeFile } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import os from "node:os";
import path from "node:path";
import test from "node:test";

const repo = process.cwd();
const canonicalRepository = "https://github.com/teddyhwang/pi-extensions";

async function implementationFiles(directory) {
  const found = [];
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const file = path.join(directory, entry.name);
    if (entry.isDirectory()) found.push(...await implementationFiles(file));
    else if (/\.(?:[cm]?[jt]s|[jt]sx)$/.test(entry.name)) found.push(file);
  }
  return found;
}

test("Pi extension implementation stays in the canonical package, not dotfiles", async () => {
  const files = await implementationFiles(path.join(repo, "home/pi-agent"));
  assert.deepEqual(files, [], `Move Pi extension code and its tests to ${canonicalRepository}`);
  const entries = await readdir(path.join(repo, "home/pi-agent"));
  assert.ok(!entries.includes("extensions"), `Pi extensions belong in ${canonicalRepository}`);
});

test("agent instructions state the canonical Pi extension ownership guardrail", async () => {
  const instructions = await readFile(path.join(repo, "AGENTS.md"), "utf8");
  assert.ok(instructions.includes(canonicalRepository));
  assert.match(instructions, /Implement Pi extension features, fixes, and their regression tests in that repository/);
});

test("linker preserves user-owned agent definitions", async (t) => {
  const home = await mkdtemp(path.join(os.tmpdir(), "pi-agent-definitions-"));
  t.after(() => rm(home, { recursive: true, force: true }));
  const agents = path.join(home, ".pi/agent/agents");
  await mkdir(agents, { recursive: true });
  await writeFile(path.join(agents, "custom.md"), "user-owned definition\n");
  const result = spawnSync("sh", [path.join(repo, "scripts/linker.sh")], {
    cwd: os.tmpdir(), env: { ...process.env, HOME: home }, encoding: "utf8", input: "",
  });
  assert.equal(result.status, 0, result.stderr || result.stdout);
  assert.equal(await readFile(path.join(agents, "custom.md"), "utf8"), "user-owned definition\n");
});

const allowedAgentModels = new Set([
  "anthropic/claude-sonnet-5-5",
  "anthropic/claude-opus-5-5",
  "anthropic/claude-fable-5-1",
]);
const systemPath = "/usr/bin:/bin:/usr/sbin:/sbin";
const workAgents = ["researcher.md", "reviewer.md", "scout.md"];
// The bundled scout and reviewer set noExtensions, so a pinned model needs the
// proxy loaded explicitly. The bundled researcher keeps extension discovery.
const proxyLoadingAgents = new Set(["reviewer.md", "scout.md"]);

async function runLinker(t, home, { work }) {
  let PATH = systemPath;
  if (work) {
    const bin = await mkdtemp(path.join(os.tmpdir(), "fake-devx-"));
    t.after(() => rm(bin, { recursive: true, force: true }));
    await writeFile(path.join(bin, "devx"), "#!/bin/sh\n", { mode: 0o755 });
    PATH = `${bin}:${systemPath}`;
  }
  const result = spawnSync("sh", [path.join(repo, "scripts/linker.sh")], {
    cwd: os.tmpdir(), env: { ...process.env, HOME: home, PATH }, encoding: "utf8", input: "",
  });
  assert.equal(result.status, 0, result.stderr || result.stdout);
  return result;
}

async function agentHome(t) {
  const home = await mkdtemp(path.join(os.tmpdir(), "pi-work-agents-"));
  t.after(() => rm(home, { recursive: true, force: true }));
  const agents = path.join(home, ".pi/agent/agents");
  await mkdir(agents, { recursive: true });
  return agents;
}

test("work Herdsman overrides keep the bundled prompt and load the proxy for their pinned model", async () => {
  for (const name of workAgents) {
    const source = await readFile(path.join(repo, "home/pi-agent/agents/work", name), "utf8");
    assert.ok(source.startsWith(`---\n# Managed by dotfiles: home/pi-agent/agents/work/${name}\n`));
    assert.ok(source.endsWith("\n---\n"), "an empty body inherits the bundled prompt");
    assert.match(source, new RegExp(`^name: ${name.replace(".md", "")}$`, "m"));
    // Quality floor: Claude Sonnet 5.5. No 4.x or Haiku models for delegated work.
    const model = source.match(/^model: (.+)$/m)?.[1];
    assert.ok(allowedAgentModels.has(model), `${name} pins ${model}; use Sonnet 5.5 or stronger`);
    if (name === "researcher.md") {
      assert.equal(model, "anthropic/claude-fable-5-1", "research uses the strongest model");
      assert.match(source, /^thinking: (xhigh|max)$/m, "Fable accepts only xhigh or max");
      for (const tool of ["web_search", "web_fetch", "perplexity_fetch"]) {
        assert.match(source, new RegExp(`^  - ${tool}$`, "m"), `researcher needs ${tool} to read primary sources`);
      }
      assert.doesNotMatch(source, /^  - (bash|edit|write)$/m, "researcher stays read-only");
    }
    if (proxyLoadingAgents.has(name)) {
      assert.match(source, /^extensions: \["~\/\.pi\/agent\/extensions\/shopify-proxy", "builtin:mcp"\]$/m);
    } else {
      assert.doesNotMatch(source, /^(extensions|noExtensions):/m, `${name} must keep extension discovery`);
    }
  }
});

test("linker copies work Herdsman overrides as regular files on work machines", async (t) => {
  const agents = await agentHome(t);
  await runLinker(t, path.dirname(path.dirname(path.dirname(agents))), { work: true });
  for (const name of workAgents) {
    const installed = path.join(agents, name);
    assert.ok((await lstat(installed)).isFile(), `${name} must be a regular file; Herdsman skips symlinks`);
    assert.equal(await readFile(installed, "utf8"),
      await readFile(path.join(repo, "home/pi-agent/agents/work", name), "utf8"));
  }
});

test("linker keeps a user-owned definition that shares a work override name", async (t) => {
  const agents = await agentHome(t);
  await writeFile(path.join(agents, "scout.md"), "---\nname: scout\n---\nuser-owned\n");
  await runLinker(t, path.dirname(path.dirname(path.dirname(agents))), { work: true });
  assert.equal(await readFile(path.join(agents, "scout.md"), "utf8"), "---\nname: scout\n---\nuser-owned\n");
});

test("linker refreshes stale managed copies and removes work copies on personal machines", async (t) => {
  const agents = await agentHome(t);
  const home = path.dirname(path.dirname(path.dirname(agents)));
  await writeFile(path.join(agents, "scout.md"), "---\n# Managed by dotfiles: home/pi-agent/agents/work/scout.md\nname: scout\n---\n");
  await writeFile(path.join(agents, "custom.md"), "user-owned definition\n");
  await runLinker(t, home, { work: true });
  assert.equal(await readFile(path.join(agents, "scout.md"), "utf8"),
    await readFile(path.join(repo, "home/pi-agent/agents/work/scout.md"), "utf8"));

  await runLinker(t, home, { work: false });
  assert.deepEqual((await readdir(agents)).sort(), ["custom.md"]);
});

test("linker removes a managed copy whose source no longer exists", async (t) => {
  const agents = await agentHome(t);
  await writeFile(path.join(agents, "gone.md"), "---\n# Managed by dotfiles: home/pi-agent/agents/gone.md\nname: gone\n---\n");
  await runLinker(t, path.dirname(path.dirname(path.dirname(agents))), { work: true });
  assert.ok(!(await readdir(agents)).includes("gone.md"));
});

test("linker keeps a foreign symlink and replaces only its own legacy symlink", async (t) => {
  const agents = await agentHome(t);
  const home = path.dirname(path.dirname(path.dirname(agents)));
  const foreign = path.join(home, "foreign-reviewer.md");
  await writeFile(foreign, "---\nname: reviewer\n---\n");
  await symlink(foreign, path.join(agents, "reviewer.md"));
  await symlink(path.join(repo, "home/pi-agent/agents/work/scout.md"), path.join(agents, "scout.md"));
  await runLinker(t, home, { work: true });
  assert.equal(await readlink(path.join(agents, "reviewer.md")), foreign);
  assert.ok((await lstat(path.join(agents, "scout.md"))).isFile());
  assert.ok(!(await readdir(agents)).some((entry) => entry.endsWith(".dotfiles-tmp")));
});

for (const scenario of ["owned symlink", "other symlink", "ordinary file", "package missing"]) {
  test(`linker retires only its own legacy Pi extension: ${scenario}`, async (t) => {
    const home = await mkdtemp(path.join(os.tmpdir(), "pi-extension-migration-"));
    t.after(() => rm(home, { recursive: true, force: true }));
    const extensions = path.join(home, ".pi/agent/extensions");
    await mkdir(extensions, { recursive: true });
    const legacy = path.join(extensions, "session-tab-name.ts");
    const external = path.join(home, "external-extension.ts");
    if (scenario !== "package missing") {
      const canonical = path.join(home, ".pi/agent/git/github.com/teddyhwang/pi-extensions/extensions/session-tab-name/index.ts");
      await mkdir(path.dirname(canonical), { recursive: true });
      await writeFile(canonical, "// installed canonical extension\n");
    }
    if (scenario === "owned symlink" || scenario === "package missing") {
      await symlink(path.join(repo, "home/pi-agent/extensions/session-tab-name.ts"), legacy);
    } else if (scenario === "other symlink") {
      await writeFile(external, "// user-owned extension\n");
      await symlink(external, legacy);
    } else {
      await writeFile(legacy, "// user-owned extension\n");
    }
    const thirdParty = path.join(extensions, "herdr-agent-state.ts");
    await writeFile(thirdParty, "// managed by Herdr\n");
    const result = spawnSync("sh", [path.join(repo, "scripts/linker.sh")], {
      cwd: os.tmpdir(), env: { ...process.env, HOME: home }, encoding: "utf8", input: "",
    });
    assert.equal(result.status, 0, result.stderr || result.stdout);
    assert.equal(await readFile(thirdParty, "utf8"), "// managed by Herdr\n");
    if (scenario === "owned symlink") {
      assert.ok(!(await readdir(extensions)).includes("session-tab-name.ts"));
    } else if (scenario === "other symlink") {
      assert.equal(await readlink(legacy), external);
    } else if (scenario === "package missing") {
      assert.equal(await readlink(legacy), path.join(repo, "home/pi-agent/extensions/session-tab-name.ts"));
      assert.match(result.stdout, /Install teddyhwang\/pi-extensions before retiring/);
    } else {
      assert.equal(await readFile(legacy, "utf8"), "// user-owned extension\n");
    }
  });
}
