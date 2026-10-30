import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import test from "node:test";
import { readYaml } from "./helpers/yaml.mjs";

const configPath = fileURLToPath(new URL("../apps/amethyst/amethyst.yml", import.meta.url));
const config = readYaml(configPath);
assert.equal(config["floating-is-blacklist"], false, "rules must be a tiling allowlist");

function titleRule(name, id) {
  const entries = config.floating.filter((entry) => entry.id === id);
  assert.equal(entries.length, 1, `${name} must have exactly one rule`);
  const titles = entries[0]["window-titles"];
  assert.ok(titles.length > 0, `an empty list would tile all ${name} windows`);
  return titles;
}

const rules = [
  {
    name: "Chrome",
    patterns: titleRule("Chrome", "com.google.Chrome"),
    cases: [
      ["Google Chrome", true],
      ["New Tab - Google Chrome", true],
      [" - Google Chrome", true],
      ["Example video - YouTube - Google Chrome - Teddy", true],
      ["Example video - Google Chrome (Incognito)", true],
      ["New Tab - Google Chrome (Guest)", true],
      ["News - High memory usage - 943 MB - Google Chrome - Work", true],
      ["Meet - abc-defg-hij - Google Chrome - Teddy", true],
      ["Picture-in-Picture tutorial - Google Chrome", true],
      ["PiP - Google Chrome (Incognito)", true],
      ["영상 🎬 - Google Chrome - 작업", true],
      ["Two\nlines - Google Chrome - Work", true],
      ["Picture in picture", false],
      ["Picture-in-Picture", false],
      ["Picture-in-picture - Teddy", false],
      ["PiP", false],
      ["Meet - abc-defg-hij", false],
      ["Meet - abc-defg-hij - Teddy", false],
      ["Any site's video title", false],
      ["Any site's video title - Teddy", false],
      ["Any site's video title (Incognito)", false],
      ["example.com", false],
      ["Sign in to example.com with google.com", false],
      ["", false],
      ["Google Chrome tutorial", false],
      // Browser popups use the same signature as normal browser windows.
      ["Extension-created browser popup - Google Chrome", true],
    ],
  },
  {
    name: "Rex",
    patterns: titleRule("Rex", "com.superlogical.rex"),
    cases: [
      // Session windows: "<terminal title> - <dir> - <session>".
      ["π - Tile Rex Window in - dotfiles - wandering-orchard", true],
      ["zsh - dotfiles - quiet-river", true],
      ["Settings - dotfiles - quiet-river", true],
      ["Settings - Server - quiet-river", true],
      ["nvim settings.json", true],
      ["Settingsx", true],
      ["Rex", true],
      // Settings window: hidden title bar, AX title "Settings - <Section>".
      ["Settings", false],
      ["Settings - Server", false],
      ["Settings - Interface", false],
      ["Settings - Remote Hosts", false],
      ["Settings - Developer", false],
      ["Settings - Built-in", false],
      // Empty startup titles float, so Amethyst retries classification.
      ["", false],
    ],
  },
];

for (const rule of rules) {
  const patterns = rule.patterns.map((pattern) => new RegExp(pattern));
  for (const [title, shouldTile] of rule.cases) {
    test(`${rule.name} ${shouldTile ? "tiles" : "floats"}: ${JSON.stringify(title)}`, () => {
      assert.equal(patterns.some((pattern) => pattern.test(title)), shouldTile);
    });
  }
}

// Amethyst uses Foundation/ICU, not JavaScript's regex engine. Exercise the
// exact same parsed YAML and cases in Foundation when running on macOS, through
// JavaScript for Automation's Objective-C bridge.
for (const rule of rules) {
  test(`${rule.name} rules agree with Amethyst's Foundation regex engine`, {
    skip: process.platform !== "darwin",
  }, () => {
    const result = spawnSync("osascript", ["-l", "JavaScript", "-e", `
      ObjC.import("Foundation");
      function run(argv) {
        const input = JSON.parse(argv[0]);
        const tiles = (title) => input.patterns.some((pattern) =>
          $(title).rangeOfStringOptions(pattern, $.NSRegularExpressionSearch).location !== $.NSNotFound);
        return JSON.stringify(input.cases.filter((item) => tiles(item.title) !== item.shouldTile).map((item) => item.title));
      }
    `, JSON.stringify({
      patterns: rule.patterns,
      cases: rule.cases.map(([title, shouldTile]) => ({ title, shouldTile })),
    })], { encoding: "utf8", timeout: 60_000 });
    assert.equal(result.status, 0, result.error?.message || result.stderr);
    assert.deepEqual(JSON.parse(result.stdout), [], "Incorrect rules for these titles");
  });
}
