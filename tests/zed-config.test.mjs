import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, statSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";

const repo = path.resolve(import.meta.dirname, "..");
const zedDir = path.join(repo, "home/config/zed");

// Zed reads these files as JSON with comments and trailing commas.
function parseJsonc(source) {
  let output = "";
  let inString = false;
  for (let index = 0; index < source.length; index += 1) {
    const char = source[index];
    if (inString) {
      output += char;
      if (char === "\\") output += source[++index];
      else if (char === '"') inString = false;
    } else if (char === '"') {
      inString = true;
      output += char;
    } else if (char === "/" && source[index + 1] === "/") {
      while (index < source.length && source[index] !== "\n") index += 1;
      output += "\n";
    } else if (char === "/" && source[index + 1] === "*") {
      index = source.indexOf("*/", index + 2) + 1;
    } else {
      output += char;
    }
  }
  return JSON.parse(output.replace(/,(\s*[}\]])/g, "$1"));
}

const readZed = (name) => parseJsonc(readFileSync(path.join(zedDir, name), "utf8"));
const settings = readZed("settings.json");
const keymap = readZed("keymap.json");
const tasks = readZed("tasks.json");

function bindings(context) {
  const block = keymap.find((entry) => entry.context === context);
  assert.ok(block, `keymap has a "${context}" block`);
  return block.bindings;
}

const normal = bindings("vim_mode == normal && !menu");
const seti = {
  base00: "151718", base01: "282a2b", base02: "3b758c", base03: "41535b",
  base04: "43a5d5", base05: "d6d6d6", base06: "eeeeee", base07: "ffffff",
  base08: "cd3f45", base09: "db7b55", base0A: "e6cd69", base0B: "9fca56",
  base0C: "55dbbe", base0D: "55b5db", base0E: "a074c4", base0F: "8a553f",
};

function palette(colors) {
  const env = {};
  for (const [base, hex] of Object.entries(colors)) {
    for (const [index, channel] of ["R", "G", "B"].entries()) {
      env[`TINTY_SCHEME_PALETTE_${base.toUpperCase()}_HEX_${channel}`] = hex.slice(index * 2, index * 2 + 2);
    }
  }
  return env;
}

function tintedZedTheme(name) {
  const color = (hex) => ({ color: `#${hex}ff`, font_style: null, font_weight: null });
  return {
    $schema: "https://zed.dev/schema/themes/v0.2.0.json",
    name,
    author: "Tinted Theming",
    themes: [{
      name,
      appearance: "dark",
      style: {
        background: "#151718ff",
        "editor.line_number": "#41535bff",
        players: [{ cursor: "#55b5dbff", background: "#55b5db20", selection: "#55b5db30" }],
        syntax: { function: color(seti.base0D), keyword: color(seti.base0E), comment: color(seti.base03) },
      },
    }],
  };
}

function runHook(home, env, themeFile) {
  return spawnSync("python3", [path.join(repo, "home/local/bin/tinty-zed-hook"), themeFile], {
    encoding: "utf8",
    env: { PATH: process.env.PATH, HOME: home, ...env },
  });
}

test("Zed uses vim mode with Neovim's editor options", () => {
  assert.equal(settings.vim_mode, true);
  assert.equal(settings.theme, "Tinted Theming");
  assert.equal(settings.vim.toggle_relative_line_numbers, true);
  assert.equal(settings.relative_line_numbers, "enabled");
  assert.equal(settings.vertical_scroll_margin, 3);
  assert.equal(settings.tab_size, 2);
  assert.equal(settings.soft_wrap, "none");
  assert.deepEqual(settings.wrap_guides, [80, 120]);
  assert.equal(settings.pane_split_direction_vertical, "left");
  assert.equal(settings.pane_split_direction_horizontal, "up");
  assert.equal(settings.format_on_save, "on");
  assert.equal(settings.diagnostics.inline.enabled, true);
  assert.equal(settings.which_key.enabled, true);
});

test("Zed keeps Neovim's command aliases and filetype mappings", () => {
  for (const [alias, command] of Object.entries({ W: "w", Q: "q", Wq: "wq", WQ: "wq", Wa: "wa", Qa: "qa" })) {
    assert.equal(settings.command_aliases[alias], command, alias);
  }
  assert.deepEqual(settings.file_types.Ruby, ["rbi"]);
  assert.deepEqual(settings.file_types.JSON, ["ejson"]);
  assert.equal(settings.languages.Ruby.language_servers[0], "ruby-lsp");
});

test("the leader key is backslash and custom Neovim mappings are bound", () => {
  const expected = {
    "\\ e": "project_panel::ToggleFocus",
    "-": "pane::RevealInProjectPanel",
    "ctrl-p": "file_finder::Toggle",
    "ctrl-b": "tab_switcher::ToggleAll",
    "\\ f f": "file_finder::Toggle",
    "\\ f g": "pane::DeploySearch",
    ", f f": "pane::DeploySearch",
    "\\ f y": "workspace::CopyRelativePath",
    "\\ f shift-y": "workspace::CopyPath",
    "\\ f t": "terminal_panel::ToggleFocus",
    "\\ g b": "git::Branch",
    "\\ g d": "git::Diff",
    "\\ g s": "git_panel::ToggleFocus",
    "\\ g y": "editor::CopyPermalinkToLine",
    "\\ g shift-y": "editor::OpenPermalinkToLine",
    "g r": "editor::FindAllReferences",
    "\\ c a": "editor::ToggleCodeActions",
    "\\ r n": "editor::Rename",
    "\\ q": "pane::CloseActiveItem",
    "\\ u shift-m": "editor::ToggleMinimap",
    "\\ t": "editor::SpawnNearestTask",
    "shift-h": "pane::ActivatePreviousItem",
    "shift-l": "pane::ActivateNextItem",
    "shift-x": "pane::CloseActiveItem",
    "<": "pane::SwapItemLeft",
    ">": "pane::SwapItemRight",
    "backspace": "buffer_search::Dismiss",
    "\\ +": "vim::Increment",
    "\\ -": "vim::Decrement",
    "ctrl-h": "workspace::ActivatePaneLeft",
    "ctrl-j": "workspace::ActivatePaneDown",
    "ctrl-k": "workspace::ActivatePaneUp",
    "ctrl-l": "workspace::ActivatePaneRight",
  };
  for (const [keys, action] of Object.entries(expected)) {
    assert.deepEqual(normal[keys], action, keys);
  }
  // Space is not a leader in this config.
  assert.ok(!Object.keys(normal).some((keys) => keys.startsWith("space ")));
});

test("every spawned task exists in tasks.json", () => {
  const labels = new Set(tasks.map((task) => task.label));
  const spawned = keymap.flatMap((entry) => Object.values(entry.bindings))
    .filter((action) => Array.isArray(action) && action[0] === "task::Spawn" && action[1]?.task_name)
    .map((action) => action[1].task_name);
  assert.ok(spawned.length >= 7);
  for (const name of spawned) assert.ok(labels.has(name), name);
  for (const name of ["\\ l g", "\\ f r", "\\ o o", "\\ shift-t", "\\ a c", "\\ a o", "\\ a p", "\\ f s"]) {
    assert.equal(normal[name][0], "task::Spawn", name);
  }
});

test("bindings use namespaced actions", () => {
  for (const entry of keymap) {
    for (const [keys, action] of Object.entries(entry.bindings)) {
      if (action === null) continue;
      const name = Array.isArray(action) ? action[0] : action;
      assert.match(name, /^[a-z_]+::[A-Z][A-Za-z]+$/, `${entry.context}: ${keys}`);
    }
  }
});

test("tinty installs the Zed theme through the Neovim-matching hook", () => {
  const config = readFileSync(path.join(repo, "home/config/tinted-theming/tinty/config.toml"), "utf8");
  assert.match(config, /^hook = 'tinty-zed-hook "\$TINTY_THEME_FILE_PATH"'$/m);
  assert.equal(statSync(path.join(repo, "home/local/bin/tinty-zed-hook")).mode & 0o111, 0o111);
});

test("tinty-zed-hook installs a stable theme with Neovim's highlight overrides", (t) => {
  const home = mkdtempSync(path.join(os.tmpdir(), "tinty-zed-"));
  t.after(() => rmSync(home, { recursive: true, force: true }));
  const themes = path.join(home, ".config/zed/themes");
  mkdirSync(themes, { recursive: true });
  const legacy = path.join(themes, "tinted-zed-themes-file.json");
  writeFileSync(legacy, "{}\n");
  const source = path.join(home, "generated.json");
  writeFileSync(source, JSON.stringify(tintedZedTheme("Base16 Seti UI")));

  const result = runHook(home, palette(seti), source);
  assert.equal(result.status, 0, result.stderr);
  const installed = path.join(themes, "tinted-theming.json");
  const theme = JSON.parse(readFileSync(installed, "utf8"));
  const style = theme.themes[0].style;

  assert.equal(theme.name, "Tinted Theming");
  assert.equal(theme.themes[0].name, "Tinted Theming");
  assert.equal(theme.themes[0].appearance, "dark");
  assert.equal(existsSync(legacy), false);
  // Values measured from Neovim's highlight groups with base16-seti.
  assert.equal(style.syntax.function.color, "#cd3f45ff"); // @function
  assert.equal(style.syntax.keyword.color, "#a074c4ff"); // untouched
  assert.equal(style.syntax.comment.font_style, "italic"); // Comment
  assert.equal(style.syntax["string.special.symbol"].color, "#db7b55ff"); // @string.special.symbol
  assert.equal(style.players[0].selection, "#21363fff"); // Visual
  assert.equal(style["editor.document_highlight.bracket_background"], "#20333aff"); // MatchParen
  assert.equal(style["editor.indent_guide"], "#1c1e1fff"); // SnacksIndent
  assert.equal(style["editor.indent_guide_active"], "#2e655aff"); // SnacksIndentScope
  assert.equal(style["editor.diff_hunk.added.background"], "#293121ff"); // DiffAdd
  assert.equal(style["editor.diff_hunk.deleted.background"], "#301d1eff"); // DiffDelete
  assert.equal(style.ignored, "#7f8080ff"); // SnacksPickerPathIgnored
  assert.equal(style["pane_group.border"], "#41535bff"); // WinSeparator
  assert.equal(style["vim.insert.background"], "#9fca56ff"); // lualine insert
  assert.equal(statSync(installed).mode & 0o777, 0o644);

  // `tinty init` runs the hook for every shell: unchanged content is not rewritten.
  const before = statSync(installed).mtimeMs;
  const again = runHook(home, palette(seti), source);
  assert.equal(again.status, 0, again.stderr);
  assert.equal(statSync(installed).mtimeMs, before);
});

test("tinty-zed-hook uses base02 for selections in light schemes", (t) => {
  const home = mkdtempSync(path.join(os.tmpdir(), "tinty-zed-"));
  t.after(() => rmSync(home, { recursive: true, force: true }));
  const source = path.join(home, "generated.json");
  writeFileSync(source, JSON.stringify(tintedZedTheme("Base16 One Light")));
  const light = { ...seti, base00: "fafafa", base02: "e5e5e6" };

  const result = runHook(home, palette(light), source);
  assert.equal(result.status, 0, result.stderr);
  const theme = JSON.parse(readFileSync(path.join(home, ".config/zed/themes/tinted-theming.json"), "utf8"));
  assert.equal(theme.themes[0].style.players[0].selection, "#e5e5e6ff");
});

test("tinty-zed-hook installs the renamed theme when the palette is missing", (t) => {
  const home = mkdtempSync(path.join(os.tmpdir(), "tinty-zed-"));
  t.after(() => rmSync(home, { recursive: true, force: true }));
  const source = path.join(home, "generated.json");
  writeFileSync(source, JSON.stringify(tintedZedTheme("Base16 Seti UI")));

  const result = runHook(home, {}, source);
  assert.equal(result.status, 0, result.stderr);
  const theme = JSON.parse(readFileSync(path.join(home, ".config/zed/themes/tinted-theming.json"), "utf8"));
  assert.equal(theme.themes[0].name, "Tinted Theming");
  assert.equal(theme.themes[0].style.syntax.function.color, "#55b5dbff");

  assert.equal(runHook(home, {}, path.join(home, "missing.json")).status, 0);
});

test("zed-test-file runs dev test, else the file type's runner", (t) => {
  const dir = mkdtempSync(path.join(os.tmpdir(), "zed-test-file-"));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const bin = path.join(dir, "bin");
  mkdirSync(bin);
  for (const name of ["dev", "bundle"]) {
    writeFileSync(path.join(bin, name), `#!/bin/sh\necho ${name} "$@"\n`);
    chmodSync(path.join(bin, name), 0o755);
  }
  const run = (file, env = {}) => spawnSync(path.join(repo, "home/local/bin/zed-test-file"), file ? [file] : [], {
    cwd: dir,
    encoding: "utf8",
    env: { PATH: `${bin}:${process.env.PATH}`, ZED_TEST_FILE_DEV: path.join(dir, "no-dev"), ...env },
  });

  const viaDev = run("test/models/user_test.rb", { ZED_TEST_FILE_DEV: path.join(bin, "dev") });
  assert.equal(viaDev.stdout, "dev test test/models/user_test.rb\n");
  assert.equal(run("spec/models/user_spec.rb").stdout, "bundle exec rspec spec/models/user_spec.rb\n");
  assert.equal(run("test/models/user_test.rb").stdout, "bundle exec ruby -Itest test/models/user_test.rb\n");
  const unknown = run("README.md");
  assert.equal(unknown.status, 1);
  assert.match(unknown.stderr, /no test runner/);
  assert.equal(run("").status, 2);
});
