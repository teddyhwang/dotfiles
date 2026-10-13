import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

test("Homebrew trust grants match third-party artifacts in the personal and work manifests", async () => {
  const manifests = await Promise.all(["Brewfile", "Brewfile.work"].map((file) => readFile(file, "utf8")));
  const declared = { formula: new Set(), cask: new Set() };
  for (const manifest of manifests) {
    for (const [, kind, name] of manifest.matchAll(/^(brew|cask) "([^"]+)"/gm)) {
      if (name.split("/").length === 3) declared[kind === "brew" ? "formula" : "cask"].add(name);
    }
  }

  const setup = await readFile("scripts/packages_mac.sh", "utf8");
  const trusted = { formula: new Set(), cask: new Set() };
  for (const [, kind, argumentsText] of setup.matchAll(/"\$BREW_BIN" trust --(formula|cask)\s+([^>]+)>\/dev\/null/g)) {
    const names = argumentsText.replaceAll("\\\n", " ").trim().split(/\s+/);
    for (const name of names) {
      assert.ok(declared[kind].has(name), `Undeclared ${kind} trust grant: ${name}`);
      assert.ok(!trusted[kind].has(name), `Duplicate ${kind} trust grant: ${name}`);
      trusted[kind].add(name);
    }
  }
  for (const kind of ["formula", "cask"]) {
    assert.deepEqual([...trusted[kind]].sort(), [...declared[kind]].sort(), `Missing ${kind} trust grants`);
  }
});
