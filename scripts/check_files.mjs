// File checks for check.sh: permissions, whitespace, JSON/JSONC syntax and
// Node syntax. TOML, YAML and plists are checked by taplo, yq and plutil.

import { execFileSync, spawnSync } from "node:child_process";
import { accessSync, constants, readFileSync, statSync } from "node:fs";
import path from "node:path";

const CONFIG_SUFFIXES = new Set([".json", ".jsonc", ".plist", ".toml", ".yaml", ".yml"]);
const NODE_SHEBANG = /^#!(?:\/usr\/bin\/env -S |\/usr\/bin\/env |\S*\/)node(?:\s|$)/;
const decoder = new TextDecoder("utf-8", { fatal: true });

function stripJsonc(source) {
  let output = "";
  let index = 0;
  let inString = false;
  let escaped = false;
  while (index < source.length) {
    const char = source[index];
    const next = source[index + 1] ?? "";
    if (inString) {
      output += char;
      if (escaped) escaped = false;
      else if (char === "\\") escaped = true;
      else if (char === '"') inString = false;
      index += 1;
    } else if (char === '"') {
      inString = true;
      output += char;
      index += 1;
    } else if (char === "/" && next === "/") {
      index += 2;
      while (index < source.length && source[index] !== "\n") index += 1;
    } else if (char === "/" && next === "*") {
      index += 2;
      while (index + 1 < source.length && source.slice(index, index + 2) !== "*/") {
        if (source[index] === "\n") output += "\n";
        index += 1;
      }
      index += 2;
    } else {
      output += char;
      index += 1;
    }
  }

  // Drop trailing commas outside strings.
  source = output;
  output = "";
  inString = false;
  escaped = false;
  for (let position = 0; position < source.length; position += 1) {
    const char = source[position];
    if (inString) {
      if (escaped) escaped = false;
      else if (char === "\\") escaped = true;
      else if (char === '"') inString = false;
    } else if (char === '"') {
      inString = true;
    } else if (char === ",") {
      let lookahead = position + 1;
      while (lookahead < source.length && /\s/.test(source[lookahead])) lookahead += 1;
      if (lookahead < source.length && "}]".includes(source[lookahead])) continue;
    }
    output += char;
  }
  return output;
}

function isExecutable(file) {
  try {
    accessSync(file, constants.X_OK);
    return true;
  } catch {
    return false;
  }
}

function nodeSyntaxError(file, source) {
  // `node --check` silently accepts files without an extension, so check
  // those as ES modules through standard input.
  const result = path.extname(file)
    ? spawnSync(process.execPath, ["--check", file], { encoding: "utf8" })
    : spawnSync(process.execPath, ["--input-type=module", "--check"], { input: source, encoding: "utf8" });
  if (result.status === 0) return null;
  const message = result.stderr.split("\n").filter((line) => !/^\s+at |^Node\.js v/.test(line));
  return message.join("\n").trim() || `node --check exited ${result.status}`;
}

const files = execFileSync("git", ["ls-files", "--cached", "--others", "--exclude-standard"], { encoding: "utf8" })
  .split("\n").filter(Boolean);
const errors = [];
for (const file of files) {
  let stats;
  try {
    stats = statSync(file);
  } catch {
    continue; // Deleted in the working tree but not yet staged.
  }
  if (!stats.isFile()) continue;
  const suffix = path.extname(file);
  if (CONFIG_SUFFIXES.has(suffix) && isExecutable(file)) {
    errors.push(`${file}: configuration files must not be executable`);
  }

  let source;
  try {
    source = decoder.decode(readFileSync(file));
  } catch {
    continue; // Binary file.
  }

  if (source && !source.endsWith("\n")) errors.push(`${file}: missing final newline`);
  source.split(/\r\n|[\n\r\v\f\x1c-\x1e\x85\u2028\u2029]/).forEach((line, index) => {
    if (line.endsWith(" ") || line.endsWith("\t")) errors.push(`${file}:${index + 1}: trailing whitespace`);
  });

  if (suffix === ".json" || suffix === ".jsonc") {
    // Zed reads its settings, keymap and tasks files as JSON with comments.
    const isJsonc = suffix === ".jsonc" || path.posix.dirname(file) === "home/config/zed";
    try {
      JSON.parse(isJsonc ? stripJsonc(source) : source);
    } catch (error) {
      errors.push(`${file}: ${error.message}`);
    }
  }

  // Node 24 releases differ on whether `--check` strips TypeScript types, so
  // .ts files are left to the tests that run them.
  const isNodeScript = suffix !== ".ts" && (NODE_SHEBANG.test(source.split("\n", 1)[0]) ||
    (suffix === ".mjs" && (file.startsWith("scripts/") || file.startsWith("tests/helpers/"))));
  if (isNodeScript) {
    const error = nodeSyntaxError(file, source);
    if (error) errors.push(`${file}: ${error}`);
  }
}

if (errors.length) {
  for (const error of errors) process.stderr.write(`check: ${error}\n`);
  process.exit(1);
}
