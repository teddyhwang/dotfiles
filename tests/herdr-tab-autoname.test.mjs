import assert from "node:assert/strict";
import { mkdir, mkdtemp, rm, symlink, writeFile } from "node:fs/promises";
import { execFileSync } from "node:child_process";
import net from "node:net";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import {
  GitCache,
  OwnershipStore,
  TabNamer,
  WorkspaceNamer,
  herdrCall,
  herdrWorkspaceLabel,
  indexedTabLabel,
  piSessionLabelFor,
  piSessionNameFromTitle,
  syncSession,
  topicFromTitle,
  zoneNameFor,
} from "../home/local/bin/herdr-tab-autoname.ts";

const SESSION_PATH = "/tmp/herdr-test.sock";

class MemoryOwnership {
  constructor(sessions = new Map()) {
    this.sessions = new Map(
      [...sessions].map(([sessionPath, labels]) => [
        sessionPath,
        new Map(labels),
      ]),
    );
  }

  stateFor(sessionPath) {
    return {
      labels: new Map(this.sessions.get(sessionPath) ?? []),
      known: this.sessions.has(sessionPath),
    };
  }

  async markKnown(sessionPath) {
    if (!this.sessions.has(sessionPath))
      this.sessions.set(sessionPath, new Map());
  }

  async set(sessionPath, tabId, label) {
    if (!this.sessions.has(sessionPath))
      this.sessions.set(sessionPath, new Map());
    this.sessions.get(sessionPath).set(tabId, label);
  }

  async remove(sessionPath, tabId) {
    this.sessions.get(sessionPath)?.delete(tabId);
  }

  async retain(sessionPath, liveTabs) {
    const labels = this.sessions.get(sessionPath);
    if (!labels) return;
    for (const tabId of labels.keys()) {
      if (!liveTabs.has(tabId)) labels.delete(tabId);
    }
  }

  async flush() {}
}

class FakeGit {
  constructor(root = "/src/dotfiles", branch = "main", zone = undefined) {
    this.root = root;
    this.branch = branch;
    this.zone = zone;
  }

  async describe() {
    return [this.root, this.branch, this.zone];
  }

  forgetMissing() {}
}

function piPane(title = "π - Fix session labels - dotfiles") {
  return {
    agent: "pi",
    cwd: "/src/dotfiles",
    pane_id: "w1:p1",
    terminal_title_stripped: title,
  };
}

function agentPane(title, paneId = "w1:p2", agent = "claude") {
  return {
    agent,
    cwd: "/src/dotfiles",
    pane_id: paneId,
    terminal_title_stripped: title,
  };
}

function shellPane(paneId = "w1:p2") {
  return {
    agent: null,
    cwd: "/src/dotfiles",
    pane_id: paneId,
    terminal_title_stripped: "zsh",
  };
}

function tabInfo(label, number = 1, workspaceId = "w1") {
  return {
    tab_id: `${workspaceId}:t${number}`,
    workspace_id: workspaceId,
    number,
    label,
  };
}

function createNamer({
  ownership = new MemoryOwnership(new Map([[SESSION_PATH, new Map()]])),
  git = new FakeGit(),
  renameTab = async () => true,
  persistOwnership = true,
  isDryRun = false,
} = {}) {
  return new TabNamer({
    sessionPath: SESSION_PATH,
    git,
    ownership,
    persistOwnership,
    dryRun: isDryRun,
    renameTab,
  });
}

test("extracts legacy and session-banner Pi session names", () => {
  const legacyPane = piPane();
  const indexedLegacyPane = piPane(
    "π - 0:0:Fix session labels - dotfiles",
  );
  const bannerPane = piPane("π — 🌊 0:0:When updating nvim mason");
  const worldBannerPane = piPane(
    "π root //areas/core/shopify — 🪻 Show me which file",
  );

  assert.equal(piSessionNameFromTitle(legacyPane), "Fix session labels");
  assert.equal(piSessionLabelFor([legacyPane]), "Fix session labels");
  assert.equal(
    piSessionNameFromTitle(indexedLegacyPane),
    "Fix session labels",
  );
  assert.equal(
    piSessionNameFromTitle(bannerPane),
    "🌊 When updating nvim mason",
  );
  assert.equal(
    piSessionNameFromTitle(worldBannerPane),
    "🪻 Show me which file",
  );
});

test("formats indexed tab labels like tmux within the label limit", () => {
  assert.equal(indexedTabLabel(7, "Fix session labels"), "7:Fix session labels");
  assert.equal(
    indexedTabLabel(12, "A very long tab label that needs to be truncated"),
    "12:A very long tab label that…",
  );
});

test("rejects a generic Pi title", () => {
  const pane = piPane("π - dotfiles");
  assert.equal(piSessionNameFromTitle(pane), undefined);
  assert.equal(topicFromTitle(pane), undefined);
});

test("prefixes the zero-based index on an automatically named Pi tab", async () => {
  const requests = [];
  const namer = createNamer({
    renameTab: async (tabId, label) => {
      requests.push({ tabId, label });
      return true;
    },
  });

  await namer.consider(tabInfo("7", 7), [piPane()], 0);

  assert.deepEqual(requests, [
    { tabId: "w1:t7", label: "0:Fix session labels" },
  ]);
  assert.equal(namer.assignmentFor("w1:t7"), "0:Fix session labels");
});

test("tracks session-banner's placeholder and refreshes it after Pi exits", async () => {
  const requests = [];
  const namer = createNamer({
    renameTab: async (tabId, label) => {
      requests.push({ tabId, label });
      return true;
    },
  });

  await namer.consider(
    tabInfo("📭 Open"),
    [{ ...piPane("π"), agent: null }],
    0,
  );
  assert.equal(namer.assignmentFor("w1:t1"), "0:📭 Open");

  await namer.consider(
    tabInfo("0:📭 Open"),
    [{ ...piPane("π - dotfiles"), agent: null }],
    0,
  );

  assert.deepEqual(requests, [
    { tabId: "w1:t1", label: "0:📭 Open" },
    { tabId: "w1:t1", label: "0:dotfiles" },
  ]);
  assert.equal(namer.assignmentFor("w1:t1"), "0:dotfiles");
});

test("indexes tabs by keyboard position within each workspace", async () => {
  const requests = [];
  const namer = createNamer({
    renameTab: async (tabId, label) => {
      requests.push({ tabId, label });
      return true;
    },
  });
  const panes = [
    {
      ...agentPane("Refactor the auth module", "wA:p1"),
      tab_id: "wA:t7",
    },
    { ...agentPane("Update the README", "wA:p2"), tab_id: "wA:t9" },
    {
      ...agentPane("Review the release notes", "wB:p1"),
      tab_id: "wB:t4",
    },
  ];

  await namer.apply({
    tabs: [
      tabInfo("7", 7, "wA"),
      tabInfo("9", 9, "wA"),
      tabInfo("4", 4, "wB"),
    ],
    panes,
  });

  assert.deepEqual(requests, [
    { tabId: "wA:t7", label: "0:Refactor the auth module" },
    { tabId: "wA:t9", label: "1:Update the README" },
    { tabId: "wB:t4", label: "0:Review the release notes" },
  ]);
});

test("updates an existing automatic Pi tab from a session-banner title", async () => {
  const ownership = new MemoryOwnership(
    new Map([[SESSION_PATH, new Map([["w1:t1", "0:dotfiles"]])]]),
  );
  const requests = [];
  const namer = createNamer({
    ownership,
    renameTab: async (tabId, label) => {
      requests.push({ tabId, label });
      return true;
    },
  });
  const pane = piPane("π — 🪻 0:When updating nvim mason");

  await namer.consider(tabInfo("0:dotfiles"), [pane], 0);

  assert.deepEqual(requests, [
    { tabId: "w1:t1", label: "0:🪻 When updating nvim mason" },
  ]);
  assert.equal(
    namer.assignmentFor("w1:t1"),
    "0:🪻 When updating nvim mason",
  );
});

test("collapses repeated indexes restored by pi --continue", async () => {
  const ownership = new MemoryOwnership(
    new Map([
      [
        SESSION_PATH,
        new Map([["w1:t1", "0:🌊 0:When updating nvim mason"]]),
      ],
    ]),
  );
  const requests = [];
  const namer = createNamer({
    ownership,
    renameTab: async (tabId, label) => {
      requests.push({ tabId, label });
      return true;
    },
  });
  const pane = piPane("π — 🌊 0:0:When updating nvim mason");

  await namer.consider(
    tabInfo("0:🌊 0:When updating nvim mason"),
    [pane],
    0,
  );

  assert.deepEqual(requests, [
    { tabId: "w1:t1", label: "0:🌊 When updating nvim mason" },
  ]);
  assert.equal(
    namer.assignmentFor("w1:t1"),
    "0:🌊 When updating nvim mason",
  );
});

test("recovers and refreshes an indexed Pi title after Pi has exited", async () => {
  const requests = [];
  const namer = createNamer({
    renameTab: async (tabId, label) => {
      requests.push({ tabId, label });
      return true;
    },
  });
  const releasedPane = { ...piPane(), agent: null };

  await namer.consider(
    tabInfo("0:Fix session labels"),
    [releasedPane],
    0,
  );

  assert.deepEqual(requests, [
    { tabId: "w1:t1", label: "0:dotfiles" },
  ]);
  assert.equal(namer.assignmentFor("w1:t1"), "0:dotfiles");
});

// Labels emitted by the canonical pi-extensions package. Keep these as protocol
// fixtures: dotfiles tests must not import or reimplement Pi extension code.
for (const [topic, shortenedLabel] of [
  ["Investigate Stuck Development Agent", "Investigate Stuck Development…"],
  ["Investigate Unexpected Shutdown Crash", "Investigate Unexpected…"],
]) {
  test(`retains ownership of Pi's shortened label: ${topic}`, async (t) => {
    const directory = await mkdtemp(path.join(os.tmpdir(), "herdr-pi-exit-"));
    t.after(() => rm(directory, { recursive: true, force: true }));
    const statePath = path.join(directory, "ownership.json");
    const store = await OwnershipStore.load(statePath);
    await store.set(SESSION_PATH, "w1:t1", "0:dotfiles");

    let label = shortenedLabel;
    const requests = [];
    async function pass(pane) {
      // Each event launches a fresh worker; nothing survives except disk state.
      const ownership = await OwnershipStore.load(statePath);
      const namer = createNamer({
        ownership,
        renameTab: async (_tabId, desired) => {
          label = desired;
          requests.push(desired);
          return true;
        },
      });
      await namer.consider(tabInfo(label), [pane], 0);
      await ownership.flush();
      const persisted = await OwnershipStore.load(statePath);
      assert.equal(persisted.stateFor(SESSION_PATH).labels.get("w1:t1"), label);
    }

    await pass(piPane(`π - ${topic} - dotfiles`));
    // Exit before a second pass can recover ownership from Pi's OSC title.
    await pass({ pane_id: "w1:p1", cwd: "/src/dotfiles" });
    assert.equal(label, "0:dotfiles");
    await pass(agentPane("Review the README", "w1:p1"));
    assert.equal(label, "0:Review the README");
    await pass({ pane_id: "w1:p1", cwd: "/src/dotfiles" });
    assert.equal(label, "0:dotfiles");
    assert.equal(requests.length, 4);
  });
}

test("recovers an already-indexed shortened Pi label after exit", async () => {
  const topic = "Investigate Unexpected Shutdown Crash";
  const namer = createNamer();
  await namer.consider(
    tabInfo(indexedTabLabel(0, "Investigate Unexpected…")),
    [{ ...piPane(`π - ${topic} - dotfiles`), agent: null }],
    0,
  );
  assert.equal(namer.assignmentFor("w1:t1"), "0:dotfiles");
});

for (const manualLabel of ["My manual name…", "Investigate Stuck…"]) {
  test(`does not adopt a shortened manual Pi tab label: ${manualLabel}`, async () => {
    const ownership = new MemoryOwnership(
      new Map([[SESSION_PATH, new Map([["w1:t1", "0:dotfiles"]])]]),
    );
    const namer = createNamer({ ownership });
    await namer.consider(
      tabInfo(manualLabel),
      [piPane("π - Investigate Stuck Development Agent - dotfiles")],
      0,
    );
    assert.equal(namer.assignmentFor("w1:t1"), undefined);
    assert.equal(ownership.stateFor(SESSION_PATH).labels.has("w1:t1"), false);
  });
}

test("prefixes a manual name without taking ownership of it", async () => {
  const ownership = new MemoryOwnership(
    new Map([[SESSION_PATH, new Map([["w1:t1", "1:dotfiles"]])]]),
  );
  const requests = [];
  const namer = createNamer({
    ownership,
    renameTab: async (tabId, label) => {
      requests.push({ tabId, label });
      return true;
    },
  });

  await namer.consider(
    tabInfo("My manual name"),
    [agentPane("Refactor auth")],
    0,
  );

  assert.deepEqual(requests, [{ tabId: "w1:t1", label: "0:My manual name" }]);
  assert.equal(namer.assignmentFor("w1:t1"), undefined);
});

test("preserves one correct index prefix on a manual name", async () => {
  const requests = [];
  const namer = createNamer({
    renameTab: async (tabId, label) => {
      requests.push({ tabId, label });
      return true;
    },
  });

  await namer.consider(
    tabInfo("7:My manual name", 7),
    [agentPane("Refactor auth")],
    7,
  );

  assert.deepEqual(requests, []);
  assert.equal(namer.assignmentFor("w1:t7"), undefined);
});

test("replaces a stale position prefix on a manual name", async () => {
  const requests = [];
  const namer = createNamer({
    renameTab: async (tabId, label) => {
      requests.push({ tabId, label });
      return true;
    },
  });

  await namer.consider(
    tabInfo("0:My manual name", 7),
    [agentPane("Refactor auth")],
    7,
  );

  assert.deepEqual(requests, [{ tabId: "w1:t7", label: "7:My manual name" }]);
  assert.equal(namer.assignmentFor("w1:t7"), undefined);
});

test("a lone topic labels a split containing an idle shell", async () => {
  const namer = createNamer();
  assert.equal(
    await namer.labelFor([piPane(), shellPane()]),
    "Fix session labels",
  );
});

test("agreeing panes keep their shared topic", async () => {
  const namer = createNamer();
  assert.equal(
    await namer.labelFor([piPane(), agentPane("Fix session labels")]),
    "Fix session labels",
  );
});

test("contradicting panes fall back to project and branch", async () => {
  const namer = createNamer({
    git: new FakeGit("/src/dotfiles", "split-labels"),
  });
  assert.equal(
    await namer.labelFor([piPane(), agentPane("Update the README")]),
    "dotfiles  split-labels",
  );
});

test("recomputes from the pane that survives an exit", async () => {
  const namer = createNamer();
  assert.equal(
    await namer.labelFor([piPane(), agentPane("Update the README")]),
    "dotfiles",
  );
  assert.equal(
    await namer.labelFor([agentPane("Update the README")]),
    "Update the README",
  );
});

test("every supported harness is a peer in the topic vote", async () => {
  const namer = createNamer();
  for (const agent of ["claude", "codex", "gemini", "opencode"]) {
    assert.equal(
      await namer.labelFor([
        agentPane("Refactor the auth module", "w1:p1", agent),
        shellPane("w1:p2"),
      ]),
      "Refactor the auth module",
    );
  }
});

test("generic agent titles abstain instead of vetoing", async () => {
  const namer = createNamer();
  assert.equal(
    await namer.labelFor([
      agentPane("Tab renaming for herdr splits", "w1:p1", "claude"),
      agentPane("codex", "w1:p2", "codex"),
    ]),
    "Tab renaming for herdr splits",
  );
  assert.equal(
    await namer.labelFor([
      agentPane("Claude", "w1:p1", "claude"),
      agentPane("codex", "w1:p2", "codex"),
    ]),
    "dotfiles",
  );
});

test("different agent topics fall back to the project", async () => {
  const namer = createNamer();
  assert.equal(
    await namer.labelFor([
      agentPane("Tab renaming for herdr splits", "w1:p1", "claude"),
      agentPane("Refactor the auth module", "w1:p2", "codex"),
    ]),
    "dotfiles",
  );
});

test("released agent titles fall back to the project", async () => {
  const namer = createNamer();
  assert.equal(
    await namer.labelFor([{ ...piPane(), agent: null }]),
    "dotfiles",
  );
  assert.equal(
    await namer.labelFor([{ ...agentPane("Update the README"), agent: null }]),
    "dotfiles",
  );
});

test("automatic ownership survives transient worker invocations", async (t) => {
  const directory = await mkdtemp(path.join(os.tmpdir(), "herdr-ownership-"));
  t.after(() => rm(directory, { recursive: true, force: true }));
  const statePath = path.join(directory, "ownership.json");
  const firstStore = await OwnershipStore.load(statePath);
  await firstStore.set(SESSION_PATH, "w1:t1", "Refactor the auth module");
  await firstStore.flush();

  const reloadedStore = await OwnershipStore.load(statePath);
  const state = reloadedStore.stateFor(SESSION_PATH);
  assert.equal(state.known, true);
  assert.deepEqual(Object.fromEntries(state.labels), {
    "w1:t1": "Refactor the auth module",
  });

  const requests = [];
  const namer = createNamer({
    ownership: reloadedStore,
    renameTab: async (tabId, label) => {
      requests.push({ tabId, label });
      return true;
    },
  });
  await namer.consider(
    tabInfo("Refactor the auth module"),
    [{ ...agentPane("Refactor the auth module"), agent: null }],
    0,
  );

  assert.deepEqual(requests, [{ tabId: "w1:t1", label: "0:dotfiles" }]);
  await reloadedStore.flush();
  const persisted = await OwnershipStore.load(statePath);
  assert.deepEqual(
    Object.fromEntries(persisted.stateFor(SESSION_PATH).labels),
    { "w1:t1": "0:dotfiles" },
  );
});

test("recovers existing automatic labels during state migration", async () => {
  const ownership = new MemoryOwnership();
  const namer = createNamer({ ownership });

  await namer.consider(
    tabInfo("Update the README"),
    [agentPane("Update the README")],
    0,
  );

  assert.deepEqual(Object.fromEntries(namer.assignments()), {
    "w1:t1": "0:Update the README",
  });
  assert.equal(ownership.stateFor(SESSION_PATH).known, true);
});

test("does not adopt a Pi label that speaks over a split", async () => {
  const namer = createNamer();
  await namer.consider(
    tabInfo("Fix session labels"),
    [piPane(), agentPane("Update the README")],
    0,
  );
  assert.equal(namer.assignmentFor("w1:t1"), undefined);
});

test("rename waits never block the Node event loop", async () => {
  let releaseRename;
  const renameGate = new Promise((resolve) => {
    releaseRename = resolve;
  });
  let renameStarted;
  const started = new Promise((resolve) => {
    renameStarted = resolve;
  });
  const namer = createNamer({
    renameTab: async () => {
      renameStarted();
      await renameGate;
      return true;
    },
  });

  const operation = namer.consider(
    tabInfo("1"),
    [agentPane("Fix session labels")],
    0,
  );
  await started;
  let eventLoopAdvanced = false;
  setImmediate(() => {
    eventLoopAdvanced = true;
  });
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(eventLoopAdvanced, true);
  releaseRename();
  await operation;
});

test("sends socket API requests asynchronously", async (t) => {
  if (process.platform === "win32") {
    t.skip("Unix socket fixture");
    return;
  }
  const directory = await mkdtemp(path.join(os.tmpdir(), "herdr-call-"));
  const socketPath = path.join(directory, "herdr.sock");
  t.after(() => rm(directory, { recursive: true, force: true }));
  let request;
  const server = net.createServer((socket) => {
    let buffer = "";
    socket.on("data", (chunk) => {
      buffer += chunk.toString("utf8");
      const newline = buffer.indexOf("\n");
      if (newline < 0) return;
      request = JSON.parse(buffer.slice(0, newline));
      socket.end(
        `${JSON.stringify({ id: request.id, result: { ok: true } })}\n`,
      );
    });
  });
  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(socketPath, resolve);
  });
  t.after(() => server.close());

  const response = await herdrCall(socketPath, "tab.rename", {
    tab_id: "w1:t1",
    label: "Async",
  });
  assert.deepEqual(response.result, { ok: true });
  assert.equal(request.method, "tab.rename");
});

test("a transient sync snapshots and renames without an event subscription", async (t) => {
  if (process.platform === "win32") {
    t.skip("Unix socket fixture");
    return;
  }
  const directory = await mkdtemp(path.join(os.tmpdir(), "herdr-sync-"));
  const socketPath = path.join(directory, "herdr.sock");
  t.after(() => rm(directory, { recursive: true, force: true }));
  let snapshotCount = 0;
  const renames = [];
  const server = net.createServer((socket) => {
    let buffer = "";
    socket.on("data", (chunk) => {
      buffer += chunk.toString("utf8");
      const newline = buffer.indexOf("\n");
      if (newline < 0) return;
      const request = JSON.parse(buffer.slice(0, newline));
      if (request.method === "session.snapshot") {
        snapshotCount += 1;
        socket.end(
          `${JSON.stringify({
            id: request.id,
            result: {
              snapshot: {
                tabs: [tabInfo("7", 7)],
                panes: [
                  { ...agentPane("Fix session labels"), tab_id: "w1:t7" },
                ],
              },
            },
          })}\n`,
        );
      } else if (request.method === "tab.rename") {
        renames.push(request.params);
        socket.end(`${JSON.stringify({ id: request.id, result: {} })}\n`);
      }
    });
  });
  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(socketPath, resolve);
  });
  t.after(() => server.close());

  assert.equal(
    await syncSession(socketPath, {
      git: new FakeGit(),
      ownership: new MemoryOwnership(
        new Map([[socketPath, new Map([["w1:t7", "7"]])]]),
      ),
      persistOwnership: true,
      dryRun: false,
    }),
    true,
  );
  assert.equal(snapshotCount, 1);
  assert.deepEqual(renames, [
    { tab_id: "w1:t7", label: "0:Fix session labels" },
  ]);
});

const WORLD_ROOT = "/world/trees/root/src";
const SHOPIFY_ZONE = `${WORLD_ROOT}/areas/core/shopify`;

class PathGit {
  constructor(entries) {
    this.entries = new Map(Object.entries(entries));
  }

  async describe(cwd) {
    return this.entries.get(cwd) ?? [undefined, undefined, undefined];
  }

  forgetMissing() {}
}

const worldGit = () =>
  new PathGit({
    [WORLD_ROOT]: [WORLD_ROOT, "main", undefined],
    [SHOPIFY_ZONE]: [WORLD_ROOT, "main", "shopify"],
    [`${SHOPIFY_ZONE}/app`]: [WORLD_ROOT, "main", "shopify"],
    "/src/dotfiles": ["/src/dotfiles", "main", undefined],
    "/src/dotfiles/home": ["/src/dotfiles", "main", undefined],
  });

function createWorkspaceNamer({
  ownership = new MemoryOwnership(),
  git = worldGit(),
  renameWorkspace = async () => true,
} = {}) {
  return new WorkspaceNamer({
    sessionPath: SESSION_PATH,
    git,
    ownership,
    persistOwnership: true,
    dryRun: false,
    renameWorkspace,
  });
}

function recordRenames() {
  const requests = [];
  return {
    requests,
    renameWorkspace: async (workspaceId, label) => {
      requests.push({ workspaceId, label });
      return true;
    },
  };
}

test("finds the innermost tec zone below the checkout root", async (t) => {
  const directory = await mkdtemp(path.join(os.tmpdir(), "herdr-zone-"));
  t.after(() => rm(directory, { recursive: true, force: true }));
  const root = path.join(directory, "trees/root/src");
  for (const zone of ["", "areas/core/shopify", "areas/core/shopify/inner"]) {
    await mkdir(path.join(root, zone), { recursive: true });
    await writeFile(path.join(root, zone, "zone.nix"), "{ }\n");
  }
  await mkdir(path.join(root, "areas/core/shopify/app/models"), {
    recursive: true,
  });
  await mkdir(path.join(root, "areas/core/shopify/inner/lib"), {
    recursive: true,
  });
  await mkdir(path.join(root, "docs"), { recursive: true });
  await symlink(
    path.join(root, "areas/core/shopify/app"),
    path.join(directory, "shortcut"),
  );

  const zone = (cwd) => zoneNameFor(path.join(root, cwd), root);
  assert.equal(await zone("areas/core/shopify"), "shopify");
  assert.equal(await zone("areas/core/shopify/app/models"), "shopify");
  assert.equal(await zone("areas/core/shopify/inner/lib"), "inner");
  assert.equal(await zone(""), undefined);
  assert.equal(await zone("docs"), undefined);
  assert.equal(
    await zoneNameFor(path.join(directory, "shortcut"), root),
    "shopify",
  );
  assert.equal(await zoneNameFor(directory, root), undefined);
  assert.equal(await zoneNameFor(root, undefined), undefined);
});

test("describes a checkout with the tec zone of the cwd", async (t) => {
  const directory = await mkdtemp(path.join(os.tmpdir(), "herdr-zone-git-"));
  t.after(() => rm(directory, { recursive: true, force: true }));
  const root = path.join(directory, "src");
  const zone = path.join(root, "areas/core/shopify");
  await mkdir(path.join(zone, "app"), { recursive: true });
  await writeFile(path.join(zone, "zone.nix"), "{ }\n");
  execFileSync("git", ["-c", "init.defaultBranch=main", "init", "-q", root], {
    env: { ...process.env, GIT_CONFIG_GLOBAL: "/dev/null", GIT_CONFIG_NOSYSTEM: "1" },
  });

  const [describedRoot, branch, zoneName] = await new GitCache().describe(
    path.join(zone, "app"),
  );
  assert.equal(path.basename(describedRoot), "src");
  assert.equal(branch, "main");
  assert.equal(zoneName, "shopify");
});

test("mirrors Herdr's own workspace label", () => {
  assert.equal(herdrWorkspaceLabel(`${SHOPIFY_ZONE}/app`, WORLD_ROOT), "src");
  assert.equal(herdrWorkspaceLabel("/tmp/scratch", undefined), "scratch");
  assert.equal(herdrWorkspaceLabel(os.homedir(), undefined), "~");
});

test("truncation keeps part of a branch instead of a bare glyph", () => {
  assert.equal(
    indexedTabLabel(
      1,
      "agent-server  teddyhwang/agent-server-mcp-graphql-prototype",
    ),
    "1:agent-server  teddyhwang/age…",
  );
});

test("tabs in a tec zone use the zone as the project name", async () => {
  const namer = createNamer({
    git: new FakeGit(WORLD_ROOT, "main", "shopify"),
  });
  assert.equal(await namer.labelFor([shellPane()]), "shopify");

  const branchNamer = createNamer({
    git: new FakeGit(WORLD_ROOT, "teddyhwang/fix", "shopify"),
  });
  assert.equal(
    await branchNamer.labelFor([shellPane()]),
    "shopify  teddyhwang/fix",
  );
});

test("renames Herdr's checkout label to the tec zone", async () => {
  const { requests, renameWorkspace } = recordRenames();
  const namer = createWorkspaceNamer({ renameWorkspace });
  await namer.consider("w1", "src", SHOPIFY_ZONE);
  assert.deepEqual(requests, [{ workspaceId: "w1", label: "shopify" }]);
  assert.equal(namer.assignmentFor("w1"), "shopify");
});

test("renames Herdr's label for an uninspected cwd to the tec zone", async () => {
  const { requests, renameWorkspace } = recordRenames();
  const namer = createWorkspaceNamer({ renameWorkspace });
  await namer.consider("w1", "app", `${SHOPIFY_ZONE}/app`);
  assert.deepEqual(requests, [{ workspaceId: "w1", label: "shopify" }]);
});

test("adopts a workspace label that already names the zone", async () => {
  const { requests, renameWorkspace } = recordRenames();
  const namer = createWorkspaceNamer({ renameWorkspace });
  await namer.consider("w1", "shopify", SHOPIFY_ZONE);
  assert.deepEqual(requests, []);
  assert.equal(namer.assignmentFor("w1"), "shopify");
});

test("leaves a manual workspace name alone and releases it", async () => {
  const { requests, renameWorkspace } = recordRenames();
  const ownership = new MemoryOwnership(
    new Map([[`${SESSION_PATH}#workspaces`, new Map([["w1", "shopify"]])]]),
  );
  const namer = createWorkspaceNamer({ ownership, renameWorkspace });
  await namer.consider("w1", "Checkout work", SHOPIFY_ZONE);
  assert.deepEqual(requests, []);
  assert.equal(namer.assignmentFor("w1"), undefined);
  assert.equal(
    ownership.stateFor(`${SESSION_PATH}#workspaces`).labels.has("w1"),
    false,
  );
});

test("leaves workspaces outside a zone to Herdr", async () => {
  const { requests, renameWorkspace } = recordRenames();
  const namer = createWorkspaceNamer({ renameWorkspace });
  await namer.consider("w1", "dotfiles", "/src/dotfiles");
  await namer.consider("w2", "home", "/src/dotfiles/home");
  await namer.consider("w3", "src", WORLD_ROOT);
  assert.deepEqual(requests, []);
  assert.equal(namer.assignmentFor("w1"), undefined);
  assert.equal(namer.assignmentFor("w2"), undefined);
  assert.equal(namer.assignmentFor("w3"), undefined);
});

test("an owned workspace label follows its pane out of and into a zone", async () => {
  const { requests, renameWorkspace } = recordRenames();
  const ownership = new MemoryOwnership(
    new Map([[`${SESSION_PATH}#workspaces`, new Map([["w1", "shopify"]])]]),
  );
  const namer = createWorkspaceNamer({ ownership, renameWorkspace });
  // Herdr cannot clear a name set over the API, so restore its label here.
  await namer.consider("w1", "shopify", "/src/dotfiles");
  await namer.consider("w1", "dotfiles", SHOPIFY_ZONE);
  assert.deepEqual(requests, [
    { workspaceId: "w1", label: "dotfiles" },
    { workspaceId: "w1", label: "shopify" },
  ]);
  assert.equal(namer.assignmentFor("w1"), "shopify");
});

test("names a workspace from the root pane of its first tab", async () => {
  const { requests, renameWorkspace } = recordRenames();
  const ownership = new MemoryOwnership(
    new Map([[`${SESSION_PATH}#workspaces`, new Map([["w9", "closed"]])]]),
  );
  const namer = createWorkspaceNamer({ ownership, renameWorkspace });
  await namer.apply({
    workspaces: [
      { workspace_id: "w1", label: "src" },
      { workspace_id: "w2", label: "dotfiles" },
    ],
    tabs: [tabInfo("0:one", 1, "w1"), tabInfo("1:two", 2, "w1"), tabInfo("0", 1, "w2")],
    panes: [
      { pane_id: "w1:p3", tab_id: "w1:t1", cwd: "/src/dotfiles" },
      { pane_id: "w1:p1", tab_id: "w1:t1", cwd: SHOPIFY_ZONE },
      { pane_id: "w1:p2", tab_id: "w1:t2", cwd: "/src/dotfiles" },
      { pane_id: "w2:p1", tab_id: "w2:t1", cwd: "/src/dotfiles" },
    ],
  });
  assert.deepEqual(requests, [{ workspaceId: "w1", label: "shopify" }]);
  assert.deepEqual(
    Object.fromEntries(ownership.stateFor(`${SESSION_PATH}#workspaces`).labels),
    { w1: "shopify" },
  );
});

test("a transient sync renames tabs and workspaces with separate ownership", async (t) => {
  if (process.platform === "win32") {
    t.skip("Unix socket fixture");
    return;
  }
  const directory = await mkdtemp(path.join(os.tmpdir(), "herdr-sync-"));
  const socketPath = path.join(directory, "herdr.sock");
  t.after(() => rm(directory, { recursive: true, force: true }));
  const requests = [];
  const server = net.createServer((socket) => {
    let buffer = "";
    socket.on("data", (chunk) => {
      buffer += chunk.toString("utf8");
      const newline = buffer.indexOf("\n");
      if (newline < 0) return;
      const request = JSON.parse(buffer.slice(0, newline));
      if (request.method === "session.snapshot") {
        socket.end(
          `${JSON.stringify({
            id: request.id,
            result: {
              snapshot: {
                workspaces: [{ workspace_id: "w1", label: "src" }],
                tabs: [tabInfo("0", 1)],
                panes: [
                  {
                    pane_id: "w1:p1",
                    tab_id: "w1:t1",
                    agent: null,
                    cwd: SHOPIFY_ZONE,
                    terminal_title_stripped: "zsh",
                  },
                ],
              },
            },
          })}\n`,
        );
      } else {
        requests.push({ method: request.method, params: request.params });
        socket.end(`${JSON.stringify({ id: request.id, result: {} })}\n`);
      }
    });
  });
  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(socketPath, resolve);
  });
  t.after(() => server.close());

  const ownership = new MemoryOwnership(new Map([[socketPath, new Map()]]));
  assert.equal(
    await syncSession(socketPath, {
      git: worldGit(),
      ownership,
      persistOwnership: true,
      dryRun: false,
    }),
    true,
  );
  assert.deepEqual(requests, [
    { method: "tab.rename", params: { tab_id: "w1:t1", label: "0:shopify" } },
    {
      method: "workspace.rename",
      params: { workspace_id: "w1", label: "shopify" },
    },
  ]);
  assert.deepEqual(Object.fromEntries(ownership.stateFor(socketPath).labels), {
    "w1:t1": "0:shopify",
  });
  assert.deepEqual(
    Object.fromEntries(ownership.stateFor(`${socketPath}#workspaces`).labels),
    { w1: "shopify" },
  );
});

const POOL_ZONE = "/world/trees/pool-1/src/areas/core/shopify";
const poolGit = (branch = "worktree/bulk-flag") =>
  new PathGit({
    [SHOPIFY_ZONE]: [WORLD_ROOT, "main", "shopify"],
    [POOL_ZONE]: ["/world/trees/pool-1/src", branch, "shopify"],
  });

test("leaves linked worktrees to Herdr, which lists them by branch", async () => {
  const { requests, renameWorkspace } = recordRenames();
  const namer = createWorkspaceNamer({ git: poolGit(), renameWorkspace });
  await namer.apply({
    workspaces: [
      { workspace_id: "w1", label: "src", worktree: { is_linked_worktree: false } },
      { workspace_id: "w2", label: "src", worktree: { is_linked_worktree: true } },
    ],
    tabs: [tabInfo("0", 1, "w1"), tabInfo("0", 1, "w2")],
    panes: [
      { pane_id: "w1:p1", tab_id: "w1:t1", cwd: SHOPIFY_ZONE },
      { pane_id: "w2:p1", tab_id: "w2:t1", cwd: POOL_ZONE },
    ],
  });
  assert.deepEqual(requests, [{ workspaceId: "w1", label: "shopify" }]);
  assert.equal(namer.assignmentFor("w2"), undefined);
});

test("an owned linked worktree takes its branch as the label", async () => {
  const { requests, renameWorkspace } = recordRenames();
  const ownership = new MemoryOwnership(
    new Map([[`${SESSION_PATH}#workspaces`, new Map([["w2", "shopify"]])]]),
  );
  const namer = createWorkspaceNamer({ ownership, git: poolGit(), renameWorkspace });
  // Herdr cannot clear the zone name, so follow the branch it would show.
  await namer.consider("w2", "shopify", POOL_ZONE, true);
  assert.deepEqual(requests, [{ workspaceId: "w2", label: "bulk-flag" }]);
  assert.equal(namer.assignmentFor("w2"), "bulk-flag");

  const renamed = createWorkspaceNamer({
    ownership,
    git: poolGit("teddyhwang/next"),
    renameWorkspace,
  });
  await renamed.consider("w2", "bulk-flag", POOL_ZONE, true);
  assert.deepEqual(requests.at(-1), { workspaceId: "w2", label: "teddyhwang/next" });

  await renamed.consider("w2", "My review", POOL_ZONE, true);
  assert.equal(renamed.assignmentFor("w2"), undefined);
});
