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

function compileKeymap(layout) {
  const result = spawnSync(
    "xkbcli",
    ["compile-keymap", "--include", "home/config/xkb", "--include-defaults", "--layout", layout],
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
  // With Shift held, WayVNC takes the first such keycode whose Shift level
  // (level 2) has the keysym.
  const shiftedKeyFor = (keysym) =>
    keys.filter((key) => key.symbols[1] === keysym).sort((a, b) => a.code - b.code)[0];
  const keyAt = (code) => keys.find((key) => key.code === code);
  return { keyFor, shiftedKeyFor, keyAt };
}

const skip = !xkbcli && "xkbcli is not installed";

test("macvnc maps Command to Super and Option to Alt", { skip }, () => {
  const { keyFor } = compileKeymap("macvnc");
  for (const keysym of ["Alt_L", "Alt_R"]) {
    assert.match(keyFor(keysym)?.actions ?? "", /SetMods\(modifiers=Mod4\)/, `${keysym} (Command) types Super`);
  }
  for (const keysym of ["Meta_L", "Meta_R"]) {
    assert.match(keyFor(keysym)?.actions ?? "", /SetMods\(modifiers=Mod1\)/, `${keysym} (Option) types Alt`);
  }
  assert.deepEqual(keyFor("Tab").symbols, ["Tab", "Tab"], "Shift stays held for Shift+Tab");
});

// Screen Sharing sends Cmd+Shift+] as Shift plus bracketright. If that keysym
// sat only on the unshifted level, WayVNC would release Shift and Command.
// Spare keycodes that Chrome, Ghostty and Hyprland all handle as plain text,
// tested over WayVNC; see the macvnc comments before changing this list. 94
// is the ISO <LSGT> key, which already carries > on its Shift level.
const SAFE_SPARES = new Set([94, 128, 152, 158, 163, 164, 177, 179, 182, 187, 188, 189, 190, 212, 214, 217, 235, 239, 240, 241, 243]);

test("macvnc keeps Shift held for unshifted punctuation and types shifted symbols", { skip }, () => {
  const vnc = compileKeymap("macvnc");
  const us = compileKeymap("us");
  const pairs = [
    ["1", "exclam"], ["2", "at"], ["3", "numbersign"], ["4", "dollar"], ["5", "percent"],
    ["6", "asciicircum"], ["7", "ampersand"], ["8", "asterisk"], ["9", "parenleft"], ["0", "parenright"],
    ["minus", "underscore"], ["equal", "plus"], ["grave", "asciitilde"], ["bracketleft", "braceleft"],
    ["bracketright", "braceright"], ["backslash", "bar"], ["semicolon", "colon"], ["apostrophe", "quotedbl"],
    ["comma", "less"], ["period", "greater"], ["slash", "question"],
  ];
  const spares = new Set();
  for (const [plain, shifted] of pairs) {
    const real = vnc.keyFor(plain);
    assert.equal(real.code, us.keyFor(plain).code, `${plain} stays on its US key, so Hyprland binds match`);
    assert.deepEqual(real.symbols, [plain, plain], `Shift+${plain} keeps Shift held`);

    // inet(evdev) may put a launcher symbol back on level 1 of a spare;
    // WayVNC holds Shift for these keys, so only level 2 matters.
    const spare = vnc.shiftedKeyFor(shifted);
    assert.ok(spare, `${shifted} types with Shift held`);
    assert.ok(SAFE_SPARES.has(spare.code), `${shifted} uses a tested spare keycode, not ${spare.code}`);
    const usSymbol = us.keyAt(spare.code)?.symbols.find((s) => s !== "NoSymbol");
    assert.ok(usSymbol, `${shifted}: Hyprland matches an empty US keysym against every code:N bind`);
    assert.ok(!spares.has(spare.code), `${shifted} shares keycode ${spare.code}`);
    spares.add(spare.code);
  }
});
