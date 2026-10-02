import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import test from "node:test";

const parsed = spawnSync("python3", ["-c", `
import json, pathlib, tomllib
root = pathlib.Path("home/config")
print(json.dumps({
    "config": tomllib.loads((root / "superfile/config.toml").read_text()),
    "theme": tomllib.loads((root / "superfile/theme/seti.toml").read_text()),
    "tinty": tomllib.loads((root / "tinted-theming/tinty/config.toml").read_text()),
}))
`], { encoding: "utf8" });
assert.equal(parsed.status, 0, parsed.stderr);
const { config, theme, tinty } = JSON.parse(parsed.stdout);

// Base16 Seti UI, from tinted-theming/schemes base16/seti.yaml.
const seti = {
  base00: "#151718", base01: "#282a2b", base02: "#3b758c", base03: "#41535b",
  base04: "#43a5d5", base05: "#d6d6d6", base06: "#eeeeee", base07: "#ffffff",
  base08: "#cd3f45", base09: "#db7b55", base0A: "#e6cd69", base0B: "#9fca56",
  base0C: "#55dbbe", base0D: "#55b5db", base0E: "#a074c4", base0F: "#8a553f",
};

// Every color field in ThemeType at Superfile v1.6.0, including directory icons.
const roles = {
  full_screen_fg: "base05", full_screen_bg: "base00",
  directory_icon_color: "base0D",
  file_panel_fg: "base05", file_panel_bg: "base00",
  file_panel_border: "base03", file_panel_border_active: "base0D",
  file_panel_top_directory_icon: "base0D", file_panel_top_path: "base0C",
  file_panel_item_selected_fg: "base0B", file_panel_item_selected_bg: "base01",
  footer_fg: "base05", footer_bg: "base00",
  footer_border: "base03", footer_border_active: "base0D",
  sidebar_fg: "base05", sidebar_bg: "base00", sidebar_title: "base0E",
  sidebar_border: "base03", sidebar_border_active: "base0D",
  sidebar_item_selected_fg: "base0B", sidebar_item_selected_bg: "base01",
  sidebar_divider: "base03",
  modal_fg: "base05", modal_bg: "base00", modal_border_active: "base0D",
  modal_cancel_fg: "base05", modal_cancel_bg: "base01",
  modal_confirm_fg: "base00", modal_confirm_bg: "base0D",
  help_menu_hotkey: "base0A", help_menu_title: "base0E",
  cursor: "base0C", correct: "base0B", error: "base08", hint: "base0D", cancel: "base09",
};

test("Superfile selects the same Seti scheme as the default terminal theme", () => {
  assert.equal(config.theme, "seti");
  assert.equal(tinty["default-scheme"], "base16-seti");
});

test("Seti defines the complete Superfile v1.6 theme using the canonical palette", () => {
  assert.deepEqual(Object.keys(theme).sort(), [
    ...Object.keys(roles), "gradient_color", "code_syntax_highlight",
  ].sort());
  for (const [field, base] of Object.entries(roles)) {
    assert.match(theme[field], /^#[0-9a-f]{6}$/, field);
    assert.equal(theme[field], seti[base], field);
  }
  assert.deepEqual(theme.gradient_color, [seti.base0D, seti.base0E]);
});

test("Seti keeps selected text and modal actions distinct from their backgrounds", () => {
  for (const prefix of ["file_panel_item_selected", "sidebar_item_selected", "modal_cancel", "modal_confirm"]) {
    assert.notEqual(theme[`${prefix}_fg`], theme[`${prefix}_bg`], prefix);
  }
  assert.notEqual(theme.file_panel_border, theme.file_panel_border_active);
});

test("Superfile previews use the existing terminal-palette-aware bat theme", () => {
  assert.equal(config.code_previewer, "bat");
  const bat = readFileSync("home/config/bat/config", "utf8");
  assert.match(bat, /^--theme="base16-256"$/m);
  // Valid built-in Chroma style, used only if bat is disabled manually.
  assert.equal(theme.code_syntax_highlight, "base16-snazzy");
});
