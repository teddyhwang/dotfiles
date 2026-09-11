import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import test from "node:test";

const configPath = fileURLToPath(new URL("../apps/amethyst/amethyst.yml", import.meta.url));
const parsed = spawnSync("ruby", [
  "-ryaml", "-rjson", "-e",
  "puts JSON.generate(YAML.safe_load(File.read(ARGV.fetch(0))))",
  configPath,
], { encoding: "utf8" });
assert.equal(parsed.status, 0, parsed.stderr);
const config = JSON.parse(parsed.stdout);
const chrome = config.floating.filter((entry) => entry.id === "com.google.Chrome");
assert.equal(config["floating-is-blacklist"], false, "rules must be a tiling allowlist");
assert.equal(chrome.length, 1, "Chrome must have exactly one rule");
assert.ok(chrome[0]["window-titles"].length > 0, "an empty list would tile all Chrome windows");
const patterns = chrome[0]["window-titles"].map((pattern) => new RegExp(pattern));

const cases = [
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
];

for (const [title, shouldTile] of cases) {
  test(`Chrome ${shouldTile ? "tiles" : "floats"}: ${JSON.stringify(title)}`, () => {
    assert.equal(patterns.some((pattern) => pattern.test(title)), shouldTile);
  });
}

// Amethyst uses Foundation/ICU, not JavaScript's regex engine. Exercise the
// exact same parsed YAML and cases in Foundation when running on macOS.
test("Chrome rules agree with Amethyst's Foundation regex engine", {
  skip: process.platform !== "darwin",
}, () => {
  const result = spawnSync("swift", ["-e", `
    import Foundation
    struct Input: Decodable {
        let patterns: [String]
        let cases: [Case]
    }
    struct Case: Decodable {
        let title: String
        let shouldTile: Bool
    }
    let input = try JSONDecoder().decode(Input.self, from: FileHandle.standardInput.readDataToEndOfFile())
    for item in input.cases {
        let tiles = input.patterns.contains {
            item.title.range(of: $0, options: .regularExpression) != nil
        }
        precondition(tiles == item.shouldTile, "Incorrect rule for: \\(item.title)")
    }
  `], {
    encoding: "utf8",
    input: JSON.stringify({
      patterns: chrome[0]["window-titles"],
      cases: cases.map(([title, shouldTile]) => ({ title, shouldTile })),
    }),
    timeout: 60_000,
  });
  assert.equal(result.status, 0, result.error?.message || result.stderr || result.stdout);
});
