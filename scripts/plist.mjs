// Read and write the top-level dictionary of an XML property list.
//
// Node has no plist parser, and the preferences that setup edits only need
// top-level keys replaced. Each value stays as its exact XML text, so data,
// dates and nested dictionaries pass through unchanged.

import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";

const HEADER = `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
`;
const TOKEN = /<!--[\s\S]*?-->|<!\[CDATA\[[\s\S]*?\]\]>|<[?!][^>]*>|<(\/?)([A-Za-z][\w.-]*)[^>]*?(\/?)>|[^<]+/g;
const ENTITY = /&(?:#x([0-9A-Fa-f]+)|#([0-9]+)|(amp|lt|gt|quot|apos));/g;
const NAMED = { amp: "&", lt: "<", gt: ">", quot: '"', apos: "'" };

export function decodeText(text) {
  return text.replace(ENTITY, (_match, hex, decimal, name) =>
    name ? NAMED[name] : String.fromCodePoint(Number.parseInt(hex ?? decimal, hex ? 16 : 10)));
}

export function encodeText(text) {
  return text.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;");
}

// Returns a Map of key -> exact XML of the value, in document order.
export function parsePlist(xml) {
  const stack = [];
  const children = [];
  let start = -1;
  let root = false;
  for (const match of xml.matchAll(TOKEN)) {
    const [token, closing, name, selfClosing] = match;
    if (!name) {
      if (!token.startsWith("<") && stack.length === 2 && token.trim()) throw new Error("plist: text outside a value");
      continue;
    }
    if (closing) {
      if (stack.pop() !== name) throw new Error(`plist: unexpected </${name}>`);
      if (stack.length === 2) children.push(xml.slice(start, match.index + token.length));
      continue;
    }
    if (stack.length === 0 && name !== "plist") throw new Error("plist: missing <plist> root");
    if (stack.length === 1) {
      if (name !== "dict" || root) throw new Error("plist: the root value must be one dictionary");
      root = true;
    }
    if (stack.length === 2 && selfClosing) children.push(token);
    if (selfClosing) continue;
    if (stack.length === 2) start = match.index;
    stack.push(name);
  }
  if (stack.length || !root) throw new Error("plist: incomplete document");
  if (children.length % 2) throw new Error("plist: key without a value");
  const entries = new Map();
  for (let index = 0; index < children.length; index += 2) {
    const key = /^<key>([^<]*)<\/key>$/.exec(children[index]);
    if (!key) throw new Error("plist: expected <key>");
    entries.set(decodeText(key[1]), children[index + 1]);
  }
  return entries;
}

// Keys are sorted, as the former Python version of setup wrote them.
export function formatPlist(entries) {
  const keys = [...entries.keys()].sort();
  if (!keys.length) return `${HEADER}<dict/>\n</plist>\n`;
  const body = keys.map((key) => `\t<key>${encodeText(key)}</key>\n\t${entries.get(key)}\n`).join("");
  return `${HEADER}<dict>\n${body}</dict>\n</plist>\n`;
}

export function readPlist(file) {
  const source = readFileSync(file);
  // Binary plists come from tools other than `defaults export`; only macOS
  // has a converter, and only macOS has such files.
  const xml = source.subarray(0, 6).toString() === "bplist"
    ? execFileSync("plutil", ["-convert", "xml1", "-o", "-", file], { encoding: "utf8" })
    : source.toString("utf8");
  return parsePlist(xml);
}
