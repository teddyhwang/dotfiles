import assert from "node:assert/strict";
import { mkdir, mkdtemp, readFile, readdir, readlink, rm, symlink, writeFile } from "node:fs/promises";
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

test("Herdsman researcher uses the installed search tool without unrelated extensions", async () => {
  const overlay = await readFile(path.join(repo, "home/pi-agent/agents/researcher.md"), "utf8");
  assert.match(overlay, /^---\nname: researcher\n/);
  assert.match(overlay, /noExtensions: true/);
  assert.match(overlay, /extensions: \["npm:pi-perplexity"\]/);
  assert.match(overlay, /  - perplexity_search\n/);
  assert.doesNotMatch(overlay, /  - (?:bash|write|edit|codemode)\n/);
});

test("linker preserves other agent definitions when installing the researcher overlay", async (t) => {
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
  assert.equal(await readlink(path.join(agents, "researcher.md")), path.join(repo, "home/pi-agent/agents/researcher.md"));
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
