import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import test from "node:test";

const parsed = spawnSync("python3", ["-c", `
import json, pathlib, tomllib
print(json.dumps(tomllib.loads(pathlib.Path("home/config/superfile/hotkeys.toml").read_text())))
`], { encoding: "utf8" });
assert.equal(parsed.status, 0, parsed.stderr);
const hotkeys = JSON.parse(parsed.stdout);

const typingActions = ["confirm_typing", "cancel_typing"];
const normalActions = ["parent_directory", "search_bar"];
const selectionActions = [
  "file_panel_select_mode_items_select_down",
  "file_panel_select_mode_items_select_up",
  "file_panel_select_all_items",
];
const nonglobalActions = new Set([...typingActions, ...normalActions, ...selectionActions]);
const globalActions = Object.keys(hotkeys).filter((action) => !nonglobalActions.has(action));

function assertUniqueBindings(actions) {
  const owners = new Map();
  for (const action of actions) {
    const keys = hotkeys[action];
    assert.ok(Array.isArray(keys) && keys.length > 0, `${action} must have key bindings`);
    assert.ok(keys.every((key) => typeof key === "string"), `${action} keys must be strings`);
    assert.notEqual(keys[0], "", `${action} must have a nonempty primary key`);
    for (const key of keys.filter(Boolean)) {
      assert.ok(!owners.has(key), `${key} conflicts between ${owners.get(key)} and ${action}`);
      owners.set(key, action);
    }
  }
}

test("Superfile uses customized Vim panel, navigation, and file-operation bindings", () => {
  const expected = {
    confirm: ["enter", "l"],
    quit: ["ctrl+c", ""],
    cd_quit: ["Q", ""],
    close_file_panel: ["q", ""],
    toggle_file_preview_panel: ["f", ""],
    list_up: ["k", ""],
    list_down: ["j", ""],
    next_file_panel: ["tab", ""],
    previous_file_panel: ["shift+tab", ""],
    parent_directory: ["h", "backspace"],
    change_panel_mode: ["m", ""],
    focus_on_process_bar: ["ctrl+p", ""],
    focus_on_sidebar: ["ctrl+s", ""],
    focus_on_metadata: ["ctrl+d", ""],
    file_panel_item_create: ["a", ""],
    file_panel_item_rename: ["r", ""],
    copy_items: ["y", ""],
    cut_items: ["x", ""],
    paste_items: ["p", ""],
    delete_items: ["d", ""],
  };
  for (const [action, keys] of Object.entries(expected)) {
    assert.deepEqual(hotkeys[action], keys, action);
  }
});

test("Superfile keeps typing confirmation separate from folder navigation", () => {
  assert.deepEqual(hotkeys.confirm_typing, ["enter", ""]);
  assert.deepEqual(hotkeys.cancel_typing, ["esc", ""]);
});

test("Superfile global hotkeys do not conflict", () => {
  assertUniqueBindings(globalActions);
});

test("Superfile mode-specific hotkeys do not conflict with global hotkeys", () => {
  assertUniqueBindings([...globalActions, ...normalActions]);
  assertUniqueBindings([...globalActions, ...selectionActions]);
  // Typing bindings deliberately override global actions, e.g. Enter to confirm.
  assertUniqueBindings(typingActions);
});
