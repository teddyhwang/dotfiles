#!/usr/bin/env node
/**
 * Name Herdr tabs after what the tab is actually doing.
 *
 * This transient worker snapshots a Herdr session, formats labels like tmux
 * (`0:name`), applies any changes, and exits. The Herdr plugin coalesces event
 * bursts before invoking it asynchronously. The prefix is the tab's zero-based
 * position in its workspace, so it matches `prefix+0..9` and is recomputed
 * after tabs move or close. The name is the one topic shared by the tab's
 * active agents, falling back to repository + branch. Manual names opt out of
 * automatic naming, but keep the position prefix; renaming a tab back to a
 * bare number opts it in again.
 */

import { execFile } from "node:child_process";
import {
  access,
  chmod,
  mkdir,
  readFile,
  readdir,
  realpath,
  rename,
  unlink,
  writeFile,
} from "node:fs/promises";
import { homedir } from "node:os";
import { basename, dirname, join, normalize, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import net from "node:net";

const CLIENT_SOCKET_SUFFIX = "-client.sock";
const MAX_LABEL = 32;
const MAX_REPLY_BYTES = 64 * 1024;
const GIT_CACHE_MS = 15_000;
const SOCKET_TIMEOUT_MS = 2_000;
const BRANCH_GLYPH = "";
const BRANCH_IMPLIED = new Set(["main", "master"]);
const TITLE_SEPARATORS = [" - ", " — ", " – ", ": ", " | ", " • "];
const GENERIC_TITLES = new Set([
  "claude",
  "claude code",
  "codex",
  "cursor",
  "droid",
  "gemini",
  "opencode",
  "pi",
  "shell",
  "terminal",
  "zsh",
  "bash",
  "fish",
  "sh",
]);

const cacheDirectory = resolve(
  expandHome(process.env.XDG_CACHE_HOME || "~/.cache"),
);
const ownershipStatePath =
  process.env.HERDR_TAB_AUTONAME_STATE_PATH ||
  join(cacheDirectory, "herdr-tab-autoname-state.json");
const configDirectories = [
  process.env.HERDR_CONFIG_DIR,
  "~/.config/herdr",
  "~/Library/Application Support/herdr",
]
  .filter((value): value is string => Boolean(value))
  .map(expandHome);

let verbose = false;
let dryRun = false;

export type JsonRecord = Record<string, unknown>;
export type PaneInfo = {
  pane_id?: string;
  tab_id?: string;
  agent?: string | null;
  cwd?: string | null;
  terminal_title?: string | null;
  terminal_title_stripped?: string | null;
  [key: string]: unknown;
};
export type TabInfo = {
  tab_id?: string;
  workspace_id?: string;
  number?: number;
  label?: string | null;
  [key: string]: unknown;
};
export type Snapshot = {
  tabs?: unknown;
  panes?: unknown;
};

type GitDescription = readonly [string | undefined, string | undefined];
type OwnershipState = {
  labels: Map<string, string>;
  known: boolean;
};
type RenameTab = (tabId: string, label: string) => Promise<boolean>;

export interface GitDescriber {
  describe(cwd: string): Promise<GitDescription>;
  forgetMissing(liveCwds: Set<string>): void;
}

export interface OwnershipRegistry {
  stateFor(sessionPath: string): OwnershipState;
  markKnown(sessionPath: string): Promise<void>;
  set(sessionPath: string, tabId: string, label: string): Promise<void>;
  remove(sessionPath: string, tabId: string): Promise<void>;
  retain(sessionPath: string, liveTabs: Set<string>): Promise<void>;
  flush(): Promise<void>;
}

function expandHome(path: string): string {
  if (path === "~") return homedir();
  if (path.startsWith("~/")) return join(homedir(), path.slice(2));
  return path;
}

function isRecord(value: unknown): value is JsonRecord {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function asString(value: unknown): string | undefined {
  return typeof value === "string" ? value : undefined;
}

function log(message: string): void {
  if (verbose) process.stderr.write(`herdr-tab-autoname: ${message}\n`);
}

export function truncateLabel(label: string): string {
  if (label.length <= MAX_LABEL) return label;
  let cut = label.slice(0, MAX_LABEL - 1);
  if (!/\s/u.test(label[MAX_LABEL - 1] ?? "")) {
    const space = cut.lastIndexOf(" ");
    if (space >= Math.floor(MAX_LABEL / 2)) cut = cut.slice(0, space);
  }
  return `${cut.replace(/[ \-—–:|]+$/u, "")}…`;
}

export function indexedTabLabel(index: number, label: string): string {
  return truncateLabel(`${index}:${label}`);
}

function normalizedManualLabel(index: number, label: string): string {
  const body = label.replace(/^\d+:/u, "");
  return indexedTabLabel(index, body);
}

function nonNegativeTabIndex(value: unknown): number | undefined {
  return typeof value === "number" && Number.isSafeInteger(value) && value >= 0
    ? value
    : undefined;
}

export function paneOrder(pane: PaneInfo): readonly [number, number | string] {
  const paneId = pane.pane_id ?? "";
  const match = paneId.match(/:p(\d+)$/u);
  return match ? [0, Number(match[1])] : [1, paneId];
}

function comparePaneOrder(left: PaneInfo, right: PaneInfo): number {
  const [leftKind, leftValue] = paneOrder(left);
  const [rightKind, rightValue] = paneOrder(right);
  if (leftKind !== rightKind) return leftKind - rightKind;
  if (typeof leftValue === "number" && typeof rightValue === "number") {
    return leftValue - rightValue;
  }
  return String(leftValue).localeCompare(String(rightValue));
}

export function piSessionNameFromTitle(pane: PaneInfo): string | undefined {
  const title = String(
    pane.terminal_title_stripped ?? pane.terminal_title ?? "",
  )
    .split(/\s+/u)
    .filter(Boolean)
    .join(" ");
  if (!title.startsWith("π")) return undefined;

  // session-banner owns current Pi titles and renders them after an em dash.
  // Keep its task emoji, but remove a positional prefix left by older versions
  // of this plugin so the index does not become part of the session topic.
  const modernSeparator = " — ";
  const separatorIndex = title.lastIndexOf(modernSeparator);
  if (separatorIndex >= 0) {
    const modernName = title.slice(separatorIndex + modernSeparator.length);
    const name = modernName.replace(
      /^([^\p{L}\p{N}]*)\d+:/u,
      "$1",
    ).trim();
    return name || undefined;
  }

  const cwd = asString(pane.cwd) ?? "";
  const cwdName = basename(cwd.replace(/\/+$/u, ""));
  const prefix = "π - ";
  const suffix = ` - ${cwdName}`;
  if (!cwdName || !title.startsWith(prefix)) return undefined;
  if (!title.toLocaleLowerCase().endsWith(suffix.toLocaleLowerCase())) {
    return undefined;
  }
  const name = title.slice(prefix.length, title.length - suffix.length).trim();
  return name || undefined;
}

export function piSessionLabelFor(
  panes: readonly PaneInfo[],
): string | undefined {
  for (const pane of [...panes].sort(comparePaneOrder)) {
    if (pane.agent !== "pi") continue;
    const name = piSessionNameFromTitle(pane);
    if (name) return truncateLabel(name);
  }
  return undefined;
}

export function topicFromTitle(pane: PaneInfo): string | undefined {
  let title = String(pane.terminal_title_stripped ?? pane.terminal_title ?? "");
  while (title && !/[\p{L}\p{N}"'#]/u.test(title[0] ?? "")) {
    title = title.slice(1);
  }
  title = title.split(/\s+/u).filter(Boolean).join(" ");
  if (!title) return undefined;

  const folded = title.toLocaleLowerCase();
  if (GENERIC_TITLES.has(folded)) return undefined;
  const agent = String(pane.agent ?? "").toLocaleLowerCase();
  if (agent && folded === agent) return undefined;

  const cwd = asString(pane.cwd) ?? "";
  const cwdName = basename(cwd.replace(/\/+$/u, "")).toLocaleLowerCase();
  let parts = [title];
  for (const separator of TITLE_SEPARATORS) {
    if (title.includes(separator)) {
      parts = title.split(separator).map((part) => part.trim());
      break;
    }
  }

  for (const part of parts) {
    const foldedPart = part.toLocaleLowerCase();
    if (cwdName && foldedPart === cwdName) return undefined;
    if (GENERIC_TITLES.has(foldedPart)) return undefined;
    if (part.includes("/") || part.startsWith("~")) return undefined;
  }
  return title;
}

export function activeTopics(panes: readonly PaneInfo[]): string[] {
  const topics: string[] = [];
  for (const pane of [...panes].sort(comparePaneOrder)) {
    let topic: string | undefined;
    if (pane.agent === "pi") {
      topic = piSessionNameFromTitle(pane);
    } else if (pane.agent) {
      topic = topicFromTitle(pane);
    }
    // A released harness may leave its last terminal title behind. Once Herdr
    // clears `agent`, that title is stale and must not keep naming the shell.
    if (topic && !topics.includes(topic)) topics.push(topic);
  }
  return topics;
}

export class GitCache implements GitDescriber {
  private readonly entries = new Map<
    string,
    { createdAt: number; result: Promise<GitDescription> }
  >();

  async describe(cwd: string): Promise<GitDescription> {
    const now = performance.now();
    const cached = this.entries.get(cwd);
    if (cached && now - cached.createdAt < GIT_CACHE_MS) {
      return cached.result;
    }

    const result = Promise.all([
      this.run(cwd, "rev-parse", "--show-toplevel"),
      this.branch(cwd),
    ]) as Promise<GitDescription>;
    this.entries.set(cwd, { createdAt: now, result });
    return result;
  }

  forgetMissing(liveCwds: Set<string>): void {
    const cutoff = performance.now() - GIT_CACHE_MS;
    for (const [cwd, entry] of this.entries) {
      if (!liveCwds.has(cwd) && entry.createdAt < cutoff) {
        this.entries.delete(cwd);
      }
    }
  }

  private async branch(cwd: string): Promise<string | undefined> {
    return (
      (await this.run(cwd, "symbolic-ref", "--quiet", "--short", "HEAD")) ??
      this.run(cwd, "rev-parse", "--short", "HEAD")
    );
  }

  private run(cwd: string, ...args: string[]): Promise<string | undefined> {
    return new Promise((resolveRun) => {
      execFile(
        "git",
        ["-C", cwd, ...args],
        {
          encoding: "utf8",
          maxBuffer: 64 * 1024,
          timeout: SOCKET_TIMEOUT_MS,
          windowsHide: true,
        },
        (error, stdout) => {
          if (error) {
            resolveRun(undefined);
            return;
          }
          const value = stdout.trim();
          resolveRun(value || undefined);
        },
      );
    });
  }
}

export class OwnershipStore implements OwnershipRegistry {
  readonly path: string;
  private readonly sessions: Map<string, Map<string, string>>;
  private writeTail: Promise<void> = Promise.resolve();

  private constructor(
    path: string,
    sessions: Map<string, Map<string, string>>,
  ) {
    this.path = path;
    this.sessions = sessions;
  }

  static async load(path: string): Promise<OwnershipStore> {
    let payload: unknown;
    try {
      payload = JSON.parse(await readFile(path, "utf8"));
    } catch (error) {
      const code = (error as NodeJS.ErrnoException).code;
      if (code !== "ENOENT")
        log(`cannot read ownership state: ${String(error)}`);
      return new OwnershipStore(path, new Map());
    }

    const rawSessions = isRecord(payload) ? payload.sessions : undefined;
    const sessions = new Map<string, Map<string, string>>();
    if (isRecord(rawSessions)) {
      for (const [sessionPath, rawLabels] of Object.entries(rawSessions)) {
        if (!isRecord(rawLabels)) continue;
        const labels = new Map<string, string>();
        for (const [tabId, label] of Object.entries(rawLabels)) {
          if (typeof label === "string") labels.set(tabId, label);
        }
        sessions.set(sessionPath, labels);
      }
    }
    return new OwnershipStore(path, sessions);
  }

  stateFor(sessionPath: string): OwnershipState {
    return {
      labels: new Map(this.sessions.get(sessionPath) ?? []),
      known: this.sessions.has(sessionPath),
    };
  }

  async markKnown(sessionPath: string): Promise<void> {
    if (this.sessions.has(sessionPath)) return;
    this.sessions.set(sessionPath, new Map());
    await this.queueSave();
  }

  async set(sessionPath: string, tabId: string, label: string): Promise<void> {
    let labels = this.sessions.get(sessionPath);
    if (!labels) {
      labels = new Map();
      this.sessions.set(sessionPath, labels);
    }
    if (labels.get(tabId) === label) return;
    labels.set(tabId, label);
    await this.queueSave();
  }

  async remove(sessionPath: string, tabId: string): Promise<void> {
    const labels = this.sessions.get(sessionPath);
    if (!labels?.delete(tabId)) return;
    await this.queueSave();
  }

  async retain(sessionPath: string, liveTabs: Set<string>): Promise<void> {
    const labels = this.sessions.get(sessionPath);
    if (!labels) return;
    let changed = false;
    for (const tabId of labels.keys()) {
      if (!liveTabs.has(tabId)) {
        labels.delete(tabId);
        changed = true;
      }
    }
    if (changed) await this.queueSave();
  }

  async flush(): Promise<void> {
    await this.writeTail;
  }

  private serialize(): string {
    const sessions: Record<string, Record<string, string>> = {};
    for (const [sessionPath, labels] of this.sessions) {
      sessions[sessionPath] = Object.fromEntries(labels);
    }
    return `${JSON.stringify({ sessions, version: 1 })}\n`;
  }

  private queueSave(): Promise<void> {
    const payload = this.serialize();
    const write = this.writeTail
      .catch(() => undefined)
      .then(() => this.writePayload(payload));
    this.writeTail = write;
    return write;
  }

  private async writePayload(payload: string): Promise<void> {
    const temporary = `${this.path}.${process.pid}.tmp`;
    try {
      await mkdir(dirname(this.path), { recursive: true });
      await writeFile(temporary, payload, { encoding: "utf8", mode: 0o600 });
      await chmod(temporary, 0o600);
      await rename(temporary, this.path);
    } catch (error) {
      log(`cannot persist ownership state: ${String(error)}`);
      await unlink(temporary).catch(() => undefined);
    }
  }
}

export type TabNamerOptions = {
  sessionPath: string;
  git: GitDescriber;
  ownership: OwnershipRegistry;
  persistOwnership: boolean;
  dryRun: boolean;
  renameTab: RenameTab;
};

export class TabNamer {
  private readonly sessionPath: string;
  private readonly git: GitDescriber;
  private readonly ownership: OwnershipRegistry;
  private readonly persistOwnership: boolean;
  private readonly dryRun: boolean;
  private readonly renameTab: RenameTab;
  private readonly assigned: Map<string, string>;
  private recoverExisting: boolean;

  constructor(options: TabNamerOptions) {
    this.sessionPath = options.sessionPath;
    this.git = options.git;
    this.ownership = options.ownership;
    this.persistOwnership = options.persistOwnership;
    this.dryRun = options.dryRun;
    this.renameTab = options.renameTab;
    const state = this.ownership.stateFor(this.sessionPath);
    this.assigned = state.labels;
    this.recoverExisting = !state.known;
  }

  assignmentFor(tabId: string): string | undefined {
    return this.assigned.get(tabId);
  }

  assignments(): Map<string, string> {
    return new Map(this.assigned);
  }

  async apply(snapshot: Snapshot): Promise<void> {
    const tabs = Array.isArray(snapshot.tabs)
      ? snapshot.tabs.filter(isRecord)
      : [];
    const panes = Array.isArray(snapshot.panes)
      ? snapshot.panes.filter(isRecord)
      : [];
    const panesByTab = new Map<string, PaneInfo[]>();
    for (const pane of panes) {
      const tabId = asString(pane.tab_id);
      if (!tabId) continue;
      const grouped = panesByTab.get(tabId) ?? [];
      grouped.push(pane);
      panesByTab.set(tabId, grouped);
    }

    const liveTabs = new Set<string>();
    const tabCountsByWorkspace = new Map<string, number>();
    for (const tab of tabs) {
      const tabId = asString(tab.tab_id);
      const workspaceId = asString(tab.workspace_id);
      if (!tabId || !workspaceId) continue;
      const index = tabCountsByWorkspace.get(workspaceId) ?? 0;
      tabCountsByWorkspace.set(workspaceId, index + 1);
      liveTabs.add(tabId);
      await this.consider(tab, panesByTab.get(tabId) ?? [], index);
    }

    for (const tabId of this.assigned.keys()) {
      if (!liveTabs.has(tabId)) {
        this.assigned.delete(tabId);
      }
    }
    if (this.canPersist()) {
      await this.ownership.retain(this.sessionPath, liveTabs);
    }
    this.git.forgetMissing(
      new Set(
        panes
          .map((pane) => asString(pane.cwd))
          .filter((cwd): cwd is string => Boolean(cwd)),
      ),
    );
    await this.finishRecovery();
  }

  async consider(
    tab: TabInfo,
    panes: readonly PaneInfo[],
    tabIndex: number,
  ): Promise<void> {
    const tabId = asString(tab.tab_id);
    const index = nonNegativeTabIndex(tabIndex);
    if (!tabId || index === undefined) return;
    const label = asString(tab.label) ?? "";
    const assigned = this.assigned.get(tabId);

    // Pi's naming extension publishes a session title shortly after startup.
    // Until it does, preserve the current label instead of replacing it with a
    // repository fallback that can be mistaken for the real session topic.
    if (
      panes.some((pane) => pane.agent === "pi") &&
      piSessionLabelFor(panes) === undefined
    ) {
      return;
    }

    let automatic =
      !label ||
      /^\d+$/u.test(label) ||
      label === assigned ||
      (assigned !== undefined && indexedTabLabel(index, assigned) === label);

    if (!automatic) {
      const piLabel = panes.length === 1 ? piSessionLabelFor(panes) : undefined;
      if (label === piLabel) {
        automatic = true;
        log(`${tabId}: adopted Pi session label ${JSON.stringify(label)}`);
      }
    }

    if (
      !automatic &&
      this.recoverExisting &&
      panes.some((pane) => Boolean(pane.agent))
    ) {
      const desiredBody = await this.labelFor(panes);
      const desired = desiredBody
        ? indexedTabLabel(index, desiredBody)
        : undefined;
      if (label === desiredBody || label === desired) {
        automatic = true;
        log(`${tabId}: recovered automatic label ${JSON.stringify(label)}`);
      }
    }

    if (!automatic) {
      const previous = await this.forgetAssignment(tabId);
      if (previous !== undefined) {
        log(
          `${tabId} renamed by hand to ${JSON.stringify(label)}; preserving its name`,
        );
      }
      await this.renameLabel(
        tabId,
        label,
        normalizedManualLabel(index, label),
      );
      return;
    }

    const desiredBody = await this.labelFor(panes);
    if (!desiredBody) return;
    const desired = indexedTabLabel(index, desiredBody);
    if (desired === label) {
      if (assigned !== desired) await this.rememberAssignment(tabId, desired);
      return;
    }
    if (!(await this.renameLabel(tabId, label, desired))) return;
    await this.rememberAssignment(tabId, desired);
  }

  async labelFor(panes: readonly PaneInfo[]): Promise<string | undefined> {
    if (panes.length === 0) return undefined;
    const topics = activeTopics(panes);
    if (topics.length === 1) return truncateLabel(topics[0]!);
    const cwd = [...panes]
      .sort(comparePaneOrder)
      .map((pane) => asString(pane.cwd))
      .find(Boolean);
    return cwd ? truncateLabel(await this.projectLabel(cwd)) : undefined;
  }

  private async projectLabel(cwd: string): Promise<string> {
    const [root, branch] = await this.git.describe(cwd);
    let name = basename((root ?? cwd).replace(/\/+$/u, "")) || "/";
    if (!root && normalize(cwd) === normalize(homedir())) name = "~";
    if (!branch || BRANCH_IMPLIED.has(branch)) return name;
    return `${name} ${BRANCH_GLYPH} ${branch}`;
  }

  private async renameLabel(
    tabId: string,
    current: string,
    desired: string,
  ): Promise<boolean> {
    if (current === desired) return true;

    log(
      `${tabId}: ${JSON.stringify(current)} -> ${JSON.stringify(desired)}${
        this.dryRun ? " [dry-run]" : ""
      }`,
    );
    if (!this.dryRun) {
      const delivered = await this.renameTab(tabId, desired);
      if (!delivered) return false;
    }
    return true;
  }

  private canPersist(): boolean {
    return this.persistOwnership && !this.dryRun;
  }

  private async rememberAssignment(
    tabId: string,
    label: string,
  ): Promise<void> {
    this.assigned.set(tabId, label);
    if (this.canPersist()) {
      await this.ownership.set(this.sessionPath, tabId, label);
    }
  }

  private async forgetAssignment(tabId: string): Promise<string | undefined> {
    const previous = this.assigned.get(tabId);
    this.assigned.delete(tabId);
    if (previous !== undefined && this.canPersist()) {
      await this.ownership.remove(this.sessionPath, tabId);
    }
    return previous;
  }

  private async finishRecovery(): Promise<void> {
    if (!this.recoverExisting) return;
    this.recoverExisting = false;
    if (this.canPersist()) await this.ownership.markKnown(this.sessionPath);
  }
}

function requestId(prefix: string): string {
  return `${prefix}:${Date.now()}:${Math.random().toString(36).slice(2)}`;
}

export function herdrCall(
  socketPath: string,
  method: string,
  params: JsonRecord,
  timeoutMs = SOCKET_TIMEOUT_MS,
  signal?: AbortSignal,
): Promise<JsonRecord | undefined> {
  return new Promise((resolveCall) => {
    if (signal?.aborted) {
      resolveCall(undefined);
      return;
    }

    let finished = false;
    let buffer = "";
    const socket = net.createConnection(socketPath);
    const abort = () => finish();
    const finish = (response?: JsonRecord) => {
      if (finished) return;
      finished = true;
      signal?.removeEventListener("abort", abort);
      socket.destroy();
      resolveCall(response);
    };

    signal?.addEventListener("abort", abort, { once: true });
    socket.setTimeout(timeoutMs);
    socket.once("error", () => finish());
    socket.once("timeout", () => finish());
    socket.once("connect", () => {
      socket.write(
        `${JSON.stringify({
          id: requestId("tab-autoname"),
          method,
          params,
        })}\n`,
      );
    });
    socket.on("data", (chunk) => {
      buffer += chunk.toString("utf8");
      if (Buffer.byteLength(buffer) > MAX_REPLY_BYTES) {
        finish();
        return;
      }
      const newline = buffer.indexOf("\n");
      if (newline < 0) return;
      try {
        const response: unknown = JSON.parse(buffer.slice(0, newline));
        finish(isRecord(response) ? response : undefined);
      } catch {
        finish();
      }
    });
    socket.once("end", () => finish());
  });
}

export type SyncSessionOptions = {
  git: GitDescriber;
  ownership: OwnershipRegistry;
  persistOwnership: boolean;
  dryRun: boolean;
};

export async function syncSession(
  path: string,
  options: SyncSessionOptions,
): Promise<boolean> {
  const response = await herdrCall(path, "session.snapshot", {});
  const result = isRecord(response?.result) ? response.result : undefined;
  const snapshot = isRecord(result?.snapshot) ? result.snapshot : undefined;
  if (!snapshot) return false;

  const namer = new TabNamer({
    sessionPath: path,
    git: options.git,
    ownership: options.ownership,
    persistOwnership: options.persistOwnership,
    dryRun: options.dryRun,
    renameTab: async (tabId, label) => {
      const renameResponse = await herdrCall(path, "tab.rename", {
        tab_id: tabId,
        label,
      });
      return renameResponse !== undefined && renameResponse.error === undefined;
    },
  });
  await namer.apply(snapshot);
  return true;
}

async function pathExists(path: string): Promise<boolean> {
  try {
    await access(path);
    return true;
  } catch {
    return false;
  }
}

export async function sessionSockets(): Promise<string[]> {
  const override = process.env.HERDR_SOCKET_PATH;
  if (override) return (await pathExists(override)) ? [override] : [];

  const found = new Set<string>();
  await Promise.all(
    configDirectories.map(async (directory) => {
      let names: string[];
      try {
        names = await readdir(directory);
      } catch {
        return;
      }
      for (const name of names) {
        if (name.endsWith(".sock") && !name.endsWith(CLIENT_SOCKET_SUFFIX)) {
          found.add(join(directory, name));
        }
      }
    }),
  );
  return [...found].sort();
}

type CliOptions = {
  dryRun: boolean;
  verbose: boolean;
};

function usage(): string {
  return [
    "Usage: herdr-tab-autoname [--dry-run] [-v|--verbose]",
    "",
    "Update Herdr tab names once, then exit.",
  ].join("\n");
}

function parseArgs(args: readonly string[]): CliOptions | undefined {
  const options: CliOptions = { dryRun: false, verbose: false };
  for (const argument of args) {
    // Retained as a no-op while existing callers migrate from the daemon CLI.
    if (argument === "--once") continue;
    if (argument === "--dry-run") options.dryRun = true;
    else if (argument === "-v" || argument === "--verbose") {
      options.verbose = true;
    } else if (argument === "-h" || argument === "--help") {
      process.stdout.write(`${usage()}\n`);
      return undefined;
    } else {
      process.stderr.write(`Unknown option: ${argument}\n${usage()}\n`);
      process.exitCode = 2;
      return undefined;
    }
  }
  return options;
}

async function runOnce(
  ownership: OwnershipRegistry,
  git: GitDescriber,
): Promise<number> {
  const paths = await sessionSockets();
  if (paths.length === 0) {
    log("no Herdr server running");
    return 1;
  }

  const results = await Promise.all(
    paths.map(async (path) => {
      try {
        return await syncSession(path, {
          git,
          ownership,
          persistOwnership: true,
          dryRun,
        });
      } catch (error) {
        log(`cannot update ${path}: ${String(error)}`);
        return false;
      }
    }),
  );
  await ownership.flush();
  return results.some(Boolean) ? 0 : 1;
}

export async function main(args = process.argv.slice(2)): Promise<number> {
  const options = parseArgs(args);
  if (!options)
    return typeof process.exitCode === "number" ? process.exitCode : 0;
  verbose = options.verbose || options.dryRun;
  dryRun = options.dryRun;

  const ownership = await OwnershipStore.load(ownershipStatePath);
  const git = new GitCache();
  return runOnce(ownership, git);
}

async function isMainModule(): Promise<boolean> {
  const entry = process.argv[1];
  if (!entry) return false;
  try {
    return (
      (await realpath(entry)) ===
      (await realpath(fileURLToPath(import.meta.url)))
    );
  } catch {
    return resolve(entry) === resolve(fileURLToPath(import.meta.url));
  }
}

if (await isMainModule()) {
  void main().then(
    (code) => {
      process.exitCode = code;
    },
    (error) => {
      process.stderr.write(`herdr-tab-autoname: ${String(error)}\n`);
      process.exitCode = 1;
    },
  );
}
