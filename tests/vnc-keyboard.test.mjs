// WayVNC and Deskflow type through virtual keyboards that bypass evdev
// remappers such as keyd, so macOS-style shortcuts must live in Hyprland, and
// the WayVNC keymap must turn Screen Sharing's Command into Super.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import test from "node:test";

test("macOS-style shortcuts are Hyprland binds, not keyd remaps", () => {
  assert.equal(existsSync("home/keyd"), false, "keyd never sees WayVNC or Deskflow keys");
  const bindings = readFileSync("home/hypr/bindings.lua", "utf8");
  for (const chord of [
    "SUPER + SHIFT + bracketleft",
    "SUPER + SHIFT + bracketright",
    "SUPER + T",
    "SUPER + R",
    "SUPER + W",
    "SUPER + A",
  ]) {
    assert.match(bindings, new RegExp(`o\\.bind\\("${chord.replace(/[+]/g, "\\+")}"`), chord);
  }
  assert.match(bindings, /for _, arrow in ipairs\(\{ "LEFT", "RIGHT", "UP", "DOWN" \}\)/);
});

const xkbcli = spawnSync("sh", ["-c", "command -v xkbcli"]).status === 0;

test("macvnc maps Command to Super and Option to Alt", { skip: !xkbcli && "xkbcli is not installed" }, () => {
  const result = spawnSync(
    "xkbcli",
    ["compile-keymap", "--include", "home/config/xkb", "--include-defaults", "--layout", "macvnc"],
    { encoding: "utf8" },
  );
  assert.equal(result.status, 0, result.stderr);
  const keymap = result.stdout;

  const keycodes = new Map();
  for (const [, name, code] of keymap.matchAll(/^\s*<(\w+)>\s*=\s*(\d+);/gm)) keycodes.set(name, Number(code));
  const keys = [];
  for (const [, name, body] of keymap.matchAll(/^\s*key <(\w+)>\s*\{([^}]*)\}/gm)) {
    const symbols = /symbols\[1\]\s*=\s*\[([^\]]*)\]/.exec(body)?.[1] ?? /\[([^\]]*)\]/.exec(body)?.[1] ?? "";
    const actions = /actions\[1\]\s*=\s*\[([^\]]*)\]/.exec(body)?.[1] ?? "";
    keys.push({ name, code: keycodes.get(name), symbols: symbols.split(",").map((s) => s.trim()), actions });
  }

  // WayVNC presses the lowest keycode that carries the requested keysym.
  const keyFor = (keysym) =>
    keys.filter((key) => key.symbols.includes(keysym)).sort((a, b) => a.code - b.code)[0];

  for (const keysym of ["Alt_L", "Alt_R"]) {
    assert.match(keyFor(keysym)?.actions ?? "", /SetMods\(modifiers=Mod4\)/, `${keysym} (Command) types Super`);
  }
  for (const keysym of ["Meta_L", "Meta_R"]) {
    assert.match(keyFor(keysym)?.actions ?? "", /SetMods\(modifiers=Mod1\)/, `${keysym} (Option) types Alt`);
  }
  assert.deepEqual(keyFor("Tab").symbols, ["Tab", "Tab"], "Shift stays held for Shift+Tab");
});
