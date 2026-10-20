// Prepare an Amethyst preference profile without snapshot machine state.
//
// Usage: node amethyst_preferences.mjs SNAPSHOT OUTPUT CURRENT
// CURRENT may be an empty string when there are no existing preferences.

import { writeFileSync } from "node:fs";
import { formatPlist, readPlist } from "./plist.mjs";

function machineState(key) {
  return key === "EncodedWindowManager" || key.startsWith("NS") || key.startsWith("SU");
}

function prepare(snapshot, current) {
  // Replace the entire modern shortcut namespace, including stock-only binds.
  const result = new Map([...current].filter(([key]) => !key.startsWith("KeyboardShortcuts_")));
  for (const [key, value] of snapshot) {
    if (!machineState(key)) result.set(key, value);
  }
  return result;
}

const args = process.argv.slice(2);
if (args.length !== 3) {
  process.stderr.write("usage: amethyst_preferences.mjs SNAPSHOT OUTPUT CURRENT\n");
  process.exit(2);
}
const [snapshotPath, outputPath, currentPath] = args;
const snapshot = readPlist(snapshotPath);
const current = currentPath ? readPlist(currentPath) : new Map();
writeFileSync(outputPath, formatPlist(prepare(snapshot, current)));
