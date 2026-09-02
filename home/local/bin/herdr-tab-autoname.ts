#!/usr/bin/env node
/**
 * Name Herdr tabs after what the tab is actually doing.
 *
 * Herdr labels new tabs with numbers. This daemon follows every local Herdr
 * session socket and replaces generated labels with the one topic shared by
 * the tab's active agents, falling back to repository + branch. Manual labels
 * opt out; renaming a tab back to a number opts it in again.
 *
 * All socket, filesystem, and Git work uses Node's asynchronous APIs. Event
 * intake never waits for snapshots, repository inspection, or tab renames.
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
import net, { type Server, type Socket } from "node:net";

const CLIENT_SOCKET_SUFFIX = "-client.sock";
const MAX_LABEL = 32;
const MAX_REPLY_BYTES = 64 * 1024;
const MAX_EVENT_BUFFER_BYTES = 1024 * 1024;
const SETTLE_MS = 750;
const RENAME_INTERVAL_MS = 2_000;
const RECONNECT_MS = 2_000;
const RESCAN_MS = 3_000;
const GIT_CACHE_MS = 15_000;
const SOCKET_TIMEOUT_MS = 2_000;
const BRANCH_GLYPH = "";
const BRANCH_IMPLIED = new Set(["main", "master"]);
const CLIENT_SUBSCRIPTIONS = [
  { type: "tab.created" },
  { type: "tab.closed" },
  { type: "tab.renamed" },
  { type: "tab.moved" },
  { type: "pane.created" },
  { type: "pane.closed" },
  { type: "pane.exited" },
  { type: "pane.moved" },
  { type: "pane.updated" },
  { type: "pane.agent_detected" },
] as const;
const PANE_SIGNATURE_FIELDS = [
  "tab_id",
  "terminal_title_stripped",
  "cwd",
  "agent",
] as const;
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
const ownershipStatePath = join(
  cacheDirectory,
  "herdr-tab-autoname-state.json",
);
const singletonSocketPath = join(cacheDirectory, "herdr-tab-autoname.lock");
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
type MarkDirty = () => void;

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
  markDirty: MarkDirty;
};

export class TabNamer {
  private readonly sessionPath: string;
  private readonly git: GitDescriber;
  private readonly ownership: OwnershipRegistry;
  private readonly persistOwnership: boolean;
  private readonly dryRun: boolean;
  private readonly renameTab: RenameTab;
  private readonly markDirty: MarkDirty;
  private readonly assigned: Map<string, string>;
  private readonly renamedAt = new Map<string, number>();
  private recoverExisting: boolean;

  constructor(options: TabNamerOptions) {
    this.sessionPath = options.sessionPath;
    this.git = options.git;
    this.ownership = options.ownership;
    this.persistOwnership = options.persistOwnership;
    this.dryRun = options.dryRun;
    this.renameTab = options.renameTab;
    this.markDirty = options.markDirty;
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
    for (const tab of tabs) {
      const tabId = asString(tab.tab_id);
      if (!tabId) continue;
      liveTabs.add(tabId);
      await this.consider(tab, panesByTab.get(tabId) ?? []);
    }

    for (const tabId of this.assigned.keys()) {
      if (!liveTabs.has(tabId)) {
        this.assigned.delete(tabId);
        this.renamedAt.delete(tabId);
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

  async consider(tab: TabInfo, panes: readonly PaneInfo[]): Promise<void> {
    const tabId = asString(tab.tab_id);
    if (!tabId) return;
    const label = asString(tab.label) ?? "";

    if (label && !/^\d+$/u.test(label) && label !== this.assigned.get(tabId)) {
      const piLabel = panes.length === 1 ? piSessionLabelFor(panes) : undefined;
      if (label === piLabel) {
        await this.rememberAssignment(tabId, label);
        log(`${tabId}: adopted Pi session label ${JSON.stringify(label)}`);
        return;
      }

      if (this.recoverExisting && panes.some((pane) => Boolean(pane.agent))) {
        const desired = await this.labelFor(panes);
        if (label === desired) {
          await this.rememberAssignment(tabId, label);
          log(`${tabId}: recovered automatic label ${JSON.stringify(label)}`);
          return;
        }
      }

      const previous = await this.forgetAssignment(tabId);
      if (previous !== undefined) {
        log(
          `${tabId} renamed by hand to ${JSON.stringify(label)}; leaving it alone`,
        );
      }
      return;
    }

    const desired = await this.labelFor(panes);
    if (!desired || desired === label) return;

    const now = performance.now();
    const lastRenamed = this.renamedAt.get(tabId);
    if (lastRenamed !== undefined && now - lastRenamed < RENAME_INTERVAL_MS) {
      this.markDirty();
      return;
    }

    log(
      `${tabId}: ${JSON.stringify(label)} -> ${JSON.stringify(desired)}${
        this.dryRun ? " [dry-run]" : ""
      }`,
    );
    if (!this.dryRun) {
      const delivered = await this.renameTab(tabId, desired);
      if (!delivered) {
        this.renamedAt.set(tabId, now);
        this.markDirty();
        return;
      }
    }
    await this.rememberAssignment(tabId, desired);
    this.renamedAt.set(tabId, now);
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

function connectEventSocket(socketPath: string): Promise<Socket> {
  return new Promise((resolveSocket, rejectSocket) => {
    const socket = net.createConnection(socketPath);
    const cleanup = () => {
      socket.removeListener("error", onError);
      socket.removeListener("timeout", onTimeout);
    };
    const onError = (error: Error) => {
      cleanup();
      socket.destroy();
      rejectSocket(error);
    };
    const onTimeout = () => onError(new Error("event subscription timed out"));

    socket.setTimeout(SOCKET_TIMEOUT_MS);
    socket.once("error", onError);
    socket.once("timeout", onTimeout);
    socket.once("connect", () => {
      cleanup();
      socket.setTimeout(0);
      socket.pause();
      socket.write(
        `${JSON.stringify({
          id: "tab-autoname:subscribe",
          method: "events.subscribe",
          params: { subscriptions: CLIENT_SUBSCRIPTIONS },
        })}\n`,
      );
      resolveSocket(socket);
    });
  });
}

export type HerdrSessionOptions = {
  path: string;
  socket: Socket;
  git: GitDescriber;
  ownership: OwnershipRegistry;
  persistOwnership: boolean;
  dryRun: boolean;
  onDisconnect: (session: HerdrSession) => void;
};

export class HerdrSession {
  readonly path: string;
  private readonly socket: Socket;
  private readonly onDisconnect: (session: HerdrSession) => void;
  private readonly controller = new AbortController();
  private readonly paneSignatures = new Map<string, string>();
  private readonly namer: TabNamer;
  private buffer = "";
  private closed = false;
  private dirty = false;
  private settleTimer: NodeJS.Timeout | undefined;
  private syncPromise: Promise<void> | undefined;

  private constructor(options: HerdrSessionOptions) {
    this.path = options.path;
    this.socket = options.socket;
    this.onDisconnect = options.onDisconnect;
    this.namer = new TabNamer({
      sessionPath: this.path,
      git: options.git,
      ownership: options.ownership,
      persistOwnership: options.persistOwnership,
      dryRun: options.dryRun,
      renameTab: async (tabId, label) => {
        const response = await herdrCall(
          this.path,
          "tab.rename",
          { tab_id: tabId, label },
          SOCKET_TIMEOUT_MS,
          this.controller.signal,
        );
        return response !== undefined && response.error === undefined;
      },
      markDirty: () => this.markDirty(),
    });

    this.socket.on("data", (chunk) => this.read(chunk));
    this.socket.once("end", () => this.disconnect());
    this.socket.once("close", () => this.disconnect());
    this.socket.once("error", () => this.disconnect());
    this.socket.resume();
  }

  static async open(
    path: string,
    options: Omit<HerdrSessionOptions, "path" | "socket">,
  ): Promise<HerdrSession> {
    const socket = await connectEventSocket(path);
    return new HerdrSession({ ...options, path, socket });
  }

  start(): void {
    this.queueSync(0);
  }

  async syncOnce(): Promise<void> {
    await this.sync();
  }

  close(): void {
    if (this.closed) return;
    this.closed = true;
    this.dirty = false;
    if (this.settleTimer) clearTimeout(this.settleTimer);
    this.settleTimer = undefined;
    this.controller.abort();
    this.socket.destroy();
  }

  private disconnect(): void {
    if (this.closed) return;
    this.close();
    this.onDisconnect(this);
  }

  private read(chunk: Buffer | string): void {
    this.buffer += chunk.toString();
    if (Buffer.byteLength(this.buffer) > MAX_EVENT_BUFFER_BYTES) {
      log(`${this.path}: event buffer exceeded limit; reconnecting`);
      this.disconnect();
      return;
    }

    while (this.buffer.includes("\n")) {
      const newline = this.buffer.indexOf("\n");
      const line = this.buffer.slice(0, newline);
      this.buffer = this.buffer.slice(newline + 1);
      if (!line.trim()) continue;
      try {
        const message: unknown = JSON.parse(line);
        if (isRecord(message) && "event" in message && isRecord(message.data)) {
          this.handleEvent(message.data);
        }
      } catch {
        // One malformed event must not disconnect an otherwise healthy stream.
      }
    }
  }

  private handleEvent(data: JsonRecord): void {
    if (data.type === "pane_updated") {
      if (!isRecord(data.pane)) return;
      const paneId = asString(data.pane.pane_id);
      if (!paneId) return;
      const signature = JSON.stringify(
        PANE_SIGNATURE_FIELDS.map((field) => data.pane![field] ?? null),
      );
      if (this.paneSignatures.get(paneId) === signature) return;
      this.paneSignatures.set(paneId, signature);
    }
    // pane_agent_detected includes released=true when a harness exits. It and
    // every other subscribed topology event require a fresh snapshot.
    this.markDirty();
  }

  private markDirty(): void {
    this.queueSync(SETTLE_MS);
  }

  private queueSync(delayMs: number): void {
    if (this.closed) return;
    this.dirty = true;
    if (this.syncPromise || this.settleTimer) return;
    this.settleTimer = setTimeout(() => {
      this.settleTimer = undefined;
      this.startSync();
    }, delayMs);
  }

  private startSync(): void {
    if (this.closed || this.syncPromise) return;
    this.dirty = false;
    const operation = this.sync();
    this.syncPromise = operation;
    const settled = (error?: unknown) => {
      if (error) log(`${this.path}: background sync failed: ${String(error)}`);
      if (this.syncPromise !== operation) return;
      this.syncPromise = undefined;
      if (this.dirty) this.queueSync(SETTLE_MS);
    };
    void operation.then(() => settled(), settled);
  }

  private async sync(): Promise<void> {
    const response = await herdrCall(
      this.path,
      "session.snapshot",
      {},
      SOCKET_TIMEOUT_MS,
      this.controller.signal,
    );
    if (this.closed) return;
    const result = isRecord(response?.result) ? response.result : undefined;
    const snapshot = isRecord(result?.snapshot) ? result.snapshot : undefined;
    if (!snapshot) return;
    await this.namer.apply(snapshot);
  }
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

function listen(server: Server, path: string): Promise<void> {
  return new Promise((resolveListen, rejectListen) => {
    const onError = (error: Error) => {
      server.removeListener("listening", onListening);
      rejectListen(error);
    };
    const onListening = () => {
      server.removeListener("error", onError);
      resolveListen();
    };
    server.once("error", onError);
    server.once("listening", onListening);
    server.listen(path);
  });
}

function socketAccepts(path: string): Promise<boolean> {
  return new Promise((resolveCheck) => {
    const socket = net.createConnection(path);
    let settled = false;
    const finish = (accepted: boolean) => {
      if (settled) return;
      settled = true;
      socket.destroy();
      resolveCheck(accepted);
    };
    socket.setTimeout(250);
    socket.once("connect", () => finish(true));
    socket.once("error", () => finish(false));
    socket.once("timeout", () => finish(false));
  });
}

async function claimSingleton(): Promise<Server | undefined> {
  await mkdir(cacheDirectory, { recursive: true });
  for (let attempt = 0; attempt < 2; attempt += 1) {
    const server = net.createServer((socket) => socket.end());
    try {
      await listen(server, singletonSocketPath);
      await chmod(singletonSocketPath, 0o600).catch((error) =>
        log(`cannot restrict singleton socket permissions: ${String(error)}`),
      );
      return server;
    } catch (error) {
      server.close();
      const code = (error as NodeJS.ErrnoException).code;
      if (code !== "EADDRINUSE") throw error;
      if (await socketAccepts(singletonSocketPath)) return undefined;
      await unlink(singletonSocketPath).catch(() => undefined);
    }
  }
  return undefined;
}

async function releaseSingleton(server: Server): Promise<void> {
  await new Promise<void>((resolveClose) => server.close(() => resolveClose()));
  await unlink(singletonSocketPath).catch(() => undefined);
}

type CliOptions = {
  once: boolean;
  dryRun: boolean;
  verbose: boolean;
};

function usage(): string {
  return [
    "Usage: herdr-tab-autoname [--once] [--dry-run] [-v|--verbose]",
    "",
    "Name Herdr tabs after their active agents, repository, and branch.",
  ].join("\n");
}

function parseArgs(args: readonly string[]): CliOptions | undefined {
  const options: CliOptions = { once: false, dryRun: false, verbose: false };
  for (const argument of args) {
    if (argument === "--once") options.once = true;
    else if (argument === "--dry-run") options.dryRun = true;
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

async function openSession(
  path: string,
  ownership: OwnershipRegistry,
  git: GitDescriber,
  persistOwnership: boolean,
  onDisconnect: (session: HerdrSession) => void,
): Promise<HerdrSession | undefined> {
  try {
    return await HerdrSession.open(path, {
      git,
      ownership,
      persistOwnership,
      dryRun,
      onDisconnect,
    });
  } catch (error) {
    log(`cannot follow ${path}: ${String(error)}`);
    return undefined;
  }
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
  const sessions = (
    await Promise.all(
      paths.map((path) => openSession(path, ownership, git, false, () => {})),
    )
  ).filter((session): session is HerdrSession => Boolean(session));
  if (sessions.length === 0) return 1;

  try {
    await Promise.all(sessions.map((session) => session.syncOnce()));
    return 0;
  } finally {
    for (const session of sessions) session.close();
  }
}

async function runDaemon(
  ownership: OwnershipRegistry,
  git: GitDescriber,
): Promise<number> {
  const singleton = await claimSingleton();
  if (!singleton) {
    log("another herdr-tab-autoname is already running");
    return 0;
  }

  const sessions = new Map<string, HerdrSession>();
  let shuttingDown = false;
  let scanRunning = false;
  let scanAgain = false;

  const scan = async (): Promise<void> => {
    if (shuttingDown) return;
    if (scanRunning) {
      scanAgain = true;
      return;
    }
    scanRunning = true;
    try {
      const paths = new Set(await sessionSockets());
      for (const [path, session] of sessions) {
        if (!paths.has(path)) {
          sessions.delete(path);
          session.close();
        }
      }
      await Promise.all(
        [...paths]
          .filter((path) => !sessions.has(path))
          .map(async (path) => {
            const session = await openSession(
              path,
              ownership,
              git,
              true,
              (disconnected) => {
                if (sessions.get(path) !== disconnected) return;
                sessions.delete(path);
                void scan();
              },
            );
            if (!session || shuttingDown) {
              session?.close();
              return;
            }
            sessions.set(path, session);
            session.start();
            log(`following ${path}`);
          }),
      );
    } finally {
      scanRunning = false;
      if (scanAgain) {
        scanAgain = false;
        void scan();
      }
    }
  };

  await scan();
  const scanTimer = setInterval(() => void scan(), RESCAN_MS);
  await new Promise<void>((resolveStop) => {
    const stop = () => resolveStop();
    process.once("SIGINT", stop);
    process.once("SIGTERM", stop);
    process.once("SIGHUP", stop);
  });

  shuttingDown = true;
  clearInterval(scanTimer);
  for (const session of sessions.values()) session.close();
  sessions.clear();
  await ownership.flush();
  await releaseSingleton(singleton);
  return 0;
}

export async function main(args = process.argv.slice(2)): Promise<number> {
  const options = parseArgs(args);
  if (!options)
    return typeof process.exitCode === "number" ? process.exitCode : 0;
  verbose = options.verbose || options.dryRun;
  dryRun = options.dryRun;

  const ownership = await OwnershipStore.load(ownershipStatePath);
  const git = new GitCache();
  return options.once ? runOnce(ownership, git) : runDaemon(ownership, git);
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
