import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync, statSync } from "node:fs";
import path from "node:path";
import test from "node:test";

// AGENTS.md: the repository's own code is shell or Node. Other languages are
// allowed only where an application requires them for its configuration.
const files = execFileSync("git", ["ls-files", "--cached", "--others", "--exclude-standard"], { encoding: "utf8" })
  .split("\n").filter((file) => file && existsSync(file) && statSync(file).isFile());
const text = (file) => {
  try {
    return new TextDecoder("utf-8", { fatal: true }).decode(readFileSync(file));
  } catch {
    return null;
  }
};

const FORBIDDEN_EXTENSIONS = new Set([".py", ".pyw", ".rb", ".pl", ".pm", ".php", ".go", ".rs", ".java", ".kt", ".tcl", ".exp", ".r"]);
const APP_LANGUAGES = [
  // Lua: Neovim, Hammerspoon, WezTerm, Hyprland and Rex read it.
  { extension: ".lua", allowed: /^(home\/config\/nvim\/|home\/\.hammerspoon\/|home\/\.wezterm\.lua$|home\/hypr\/|home\/config\/rex\/init\.lua$)/ },
  // QML and JavaScript: Omarchy plugins, Amethyst layouts and opensessions plugins.
  { extension: ".qml", allowed: /^home\/omarchy\/plugins\// },
  { extension: ".js", allowed: /^(home\/omarchy\/plugins\/|apps\/amethyst\/|home\/config\/opensessions\/plugins\/)/ },
  // Swift: only wavelink-bt-bridge, which the user approved because it needs
  // real-time CoreAudio callbacks that JavaScript for Automation cannot run.
  { extension: ".swift", allowed: /^apps\/wavelink-bt-bridge\// },
];
const SHEBANG_INTERPRETERS = new Set(["sh", "bash", "zsh", "node", "awk"]);

test("no tracked file uses a language outside shell, Node and app-required configuration", () => {
  const offenders = files.filter((file) => FORBIDDEN_EXTENSIONS.has(path.extname(file).toLowerCase()));
  for (const { extension, allowed } of APP_LANGUAGES) {
    offenders.push(...files.filter((file) => path.extname(file) === extension && !allowed.test(file)));
  }
  assert.deepEqual(offenders, []);
});

test("every script's shebang names shell, Node or awk", () => {
  const offenders = [];
  for (const file of files) {
    const first = text(file)?.split("\n", 1)[0] ?? "";
    if (!first.startsWith("#!")) continue;
    const words = first.slice(2).trim().split(/\s+/);
    const program = path.basename(words[0]) === "env" ? words.find((word, index) => index && !word.startsWith("-")) : words[0];
    if (!SHEBANG_INTERPRETERS.has(path.basename(program ?? ""))) offenders.push(`${file}: ${first}`);
  }
  assert.deepEqual(offenders, []);
});

test("repository code does not shell out to another language", () => {
  // zed-test-file runs a project's own test runner (pytest, rspec), which is
  // not repository code; zed-config.test.mjs checks the commands it prints.
  const exempt = new Set(["home/local/bin/zed-test-file", "tests/language-policy.test.mjs"]);
  const exemptLine = /bundle exec ruby/;
  const scanned = /^(scripts\/|tests\/|plugins\/|home\/local\/bin\/|home\/config\/zed\/|setup\.sh$|bootstrap\.sh$|\.github\/)/;
  const languages = "python[0-9.]*|ruby|perl|php|swift|tclsh|expect|lua(?:jit)?|deno|bun";
  const calls = [
    // A shell command: `python3 -c …`, `perl -pe …`, `ruby - <<EOF`.
    new RegExp(`(?:^|[\\s;|&(\`$])(?:${languages})\\s+(?:-|<<)`),
    // A Node child process: spawnSync("ruby", …).
    new RegExp(`(?:spawn|exec)\\w*\\(\\s*["'\`](?:${languages})["'\`]`),
    /actions\/setup-(?:python|ruby)|\btomllib\b|\bplistlib\b/,
  ];
  const offenders = files.filter((file) => scanned.test(file) && !exempt.has(file)).flatMap((file) => {
    const source = text(file);
    if (source === null) return [];
    return source.split("\n").flatMap((line, index) => {
      if (exemptLine.test(line)) return [];
      // osascript is allowed only as JavaScript for Automation, not AppleScript.
      const appleScript = /\bosascript\b/.test(line) && !/JavaScript/.test(line);
      return appleScript || calls.some((call) => call.test(line)) ? [`${file}:${index + 1}: ${line.trim()}`] : [];
    });
  });
  assert.deepEqual(offenders, []);
});

test("there is no npm package manifest or dependency tree", () => {
  assert.deepEqual(files.filter((file) => /(^|\/)(package\.json|package-lock\.json|node_modules\/)/.test(file) &&
    !file.startsWith("home/config/opensessions/")), []);
});

test("Node runs only after the package step, behind a clear error", () => {
  // Before packages are installed there is no Node, so these must stay sh.
  for (const file of ["bootstrap.sh", "setup.sh", "scripts/verify_dependencies.sh", "scripts/brew.sh", "scripts/utils.sh"]) {
    assert.doesNotMatch(readFileSync(file, "utf8"), /(^|[\s;|&(])node\s/m, `${file} must not run node`);
  }
  const setup = readFileSync("setup.sh", "utf8");
  for (const packages of ["scripts/packages_mac.sh", "scripts/packages_linux.sh"]) {
    assert.ok(setup.indexOf(packages) < setup.indexOf("scripts/pi.sh"), `${packages} must run before pi.sh`);
  }
  const mac = readFileSync("scripts/packages_mac.sh", "utf8");
  assert.ok(mac.indexOf("bundle install") < mac.indexOf("amethyst.sh"), "Homebrew must install node before amethyst.sh");
  for (const file of files.filter((name) => /^scripts\/[^/]+\.sh$/.test(name) && name !== "scripts/check.sh")) {
    const source = readFileSync(file, "utf8");
    if (/(^|[\s;|&(!])node\s+"/m.test(source)) {
      assert.match(source, /command -v node/, `${file} runs node and must stop with a clear error when it is missing`);
    }
  }
});
