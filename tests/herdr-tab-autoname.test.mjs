import assert from "node:assert/strict";
import { mkdtemp, rm } from "node:fs/promises";
import net from "node:net";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import {
  HerdrSession,
  OwnershipStore,
  TabNamer,
  herdrCall,
  piSessionLabelFor,
  piSessionNameFromTitle,
  topicFromTitle,
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
  constructor(root = "/src/dotfiles", branch = "main") {
    this.root = root;
    this.branch = branch;
  }

  async describe() {
    return [this.root, this.branch];
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

function createNamer({
  ownership = new MemoryOwnership(new Map([[SESSION_PATH, new Map()]])),
  git = new FakeGit(),
  renameTab = async () => true,
  markDirty = () => {},
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
    markDirty,
  });
}

async function waitFor(predicate, timeoutMs = 2_500) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (predicate()) return;
    await new Promise((resolve) => setTimeout(resolve, 10));
  }
  assert.fail("Timed out waiting for asynchronous tab naming");
}

test("extracts an explicit Pi session name", () => {
  const pane = piPane();
  assert.equal(piSessionNameFromTitle(pane), "Fix session labels");
  assert.equal(piSessionLabelFor([pane]), "Fix session labels");
});

test("rejects a generic Pi title", () => {
  const pane = piPane("π - dotfiles");
  assert.equal(piSessionNameFromTitle(pane), undefined);
  assert.equal(topicFromTitle(pane), undefined);
});

test("adopts a direct Pi extension rename", async () => {
  const ownership = new MemoryOwnership(
    new Map([[SESSION_PATH, new Map([["w1:t1", "dotfiles"]])]]),
  );
  const namer = createNamer({ ownership });

  await namer.consider({ tab_id: "w1:t1", label: "Fix session labels" }, [
    piPane(),
  ]);

  assert.equal(namer.assignmentFor("w1:t1"), "Fix session labels");
});

test("still treats other labels as manual", async () => {
  const ownership = new MemoryOwnership(
    new Map([[SESSION_PATH, new Map([["w1:t1", "dotfiles"]])]]),
  );
  const namer = createNamer({ ownership });

  await namer.consider({ tab_id: "w1:t1", label: "My manual name" }, [
    piPane(),
  ]);

  assert.equal(namer.assignmentFor("w1:t1"), undefined);
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

test("automatic ownership survives a daemon restart", async (t) => {
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
  await namer.consider({ tab_id: "w1:t1", label: "Refactor the auth module" }, [
    { ...agentPane("Refactor the auth module"), agent: null },
  ]);

  assert.deepEqual(requests, [{ tabId: "w1:t1", label: "dotfiles" }]);
  await reloadedStore.flush();
  const persisted = await OwnershipStore.load(statePath);
  assert.deepEqual(
    Object.fromEntries(persisted.stateFor(SESSION_PATH).labels),
    { "w1:t1": "dotfiles" },
  );
});

test("recovers existing automatic labels during state migration", async () => {
  const ownership = new MemoryOwnership();
  const namer = createNamer({ ownership });

  await namer.consider({ tab_id: "w1:t1", label: "Update the README" }, [
    agentPane("Update the README"),
  ]);

  assert.deepEqual(Object.fromEntries(namer.assignments()), {
    "w1:t1": "Update the README",
  });
  assert.equal(ownership.stateFor(SESSION_PATH).known, true);
});

test("does not adopt a Pi label that speaks over a split", async () => {
  const namer = createNamer();
  await namer.consider({ tab_id: "w1:t1", label: "Fix session labels" }, [
    piPane(),
    agentPane("Update the README"),
  ]);
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

  const operation = namer.consider({ tab_id: "w1:t1", label: "1" }, [piPane()]);
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

test(
  "agent release events resnapshot and replace the stale topic",
  { timeout: 4_000 },
  async (t) => {
    if (process.platform === "win32") {
      t.skip("Unix socket fixture");
      return;
    }
    const directory = await mkdtemp(path.join(os.tmpdir(), "herdr-events-"));
    const socketPath = path.join(directory, "herdr.sock");
    t.after(() => rm(directory, { recursive: true, force: true }));
    const sockets = new Set();
    let eventSocket;
    let released = false;
    let snapshotCount = 0;
    const renames = [];
    const server = net.createServer((socket) => {
      sockets.add(socket);
      socket.once("close", () => sockets.delete(socket));
      let buffer = "";
      socket.on("data", (chunk) => {
        buffer += chunk.toString("utf8");
        const newline = buffer.indexOf("\n");
        if (newline < 0) return;
        const request = JSON.parse(buffer.slice(0, newline));
        if (request.method === "events.subscribe") {
          eventSocket = socket;
          socket.write(`${JSON.stringify({ id: request.id, result: {} })}\n`);
          return;
        }
        if (request.method === "session.snapshot") {
          snapshotCount += 1;
          socket.end(
            `${JSON.stringify({
              id: request.id,
              result: {
                snapshot: {
                  tabs: [{ tab_id: "w1:t1", label: "Update the README" }],
                  panes: [
                    {
                      ...agentPane("Update the README", "w1:p1", "claude"),
                      agent: released ? null : "claude",
                      tab_id: "w1:t1",
                    },
                  ],
                },
              },
            })}\n`,
          );
          return;
        }
        if (request.method === "tab.rename") {
          renames.push(request.params);
          socket.end(`${JSON.stringify({ id: request.id, result: {} })}\n`);
        }
      });
    });
    await new Promise((resolve, reject) => {
      server.once("error", reject);
      server.listen(socketPath, resolve);
    });
    t.after(() => {
      for (const socket of sockets) socket.destroy();
      server.close();
    });

    const ownership = new MemoryOwnership(
      new Map([[socketPath, new Map([["w1:t1", "Update the README"]])]]),
    );
    const session = await HerdrSession.open(socketPath, {
      git: new FakeGit(),
      ownership,
      persistOwnership: true,
      dryRun: false,
      onDisconnect: () => {},
    });
    t.after(() => session.close());
    session.start();
    await waitFor(() => snapshotCount >= 1 && eventSocket);

    released = true;
    eventSocket.write(
      `${JSON.stringify({
        event: "pane.agent_detected",
        data: {
          type: "pane_agent_detected",
          pane_id: "w1:p1",
          agent: null,
          released: true,
        },
      })}\n`,
    );

    await waitFor(
      () =>
        snapshotCount >= 2 &&
        renames.some((request) => request.label === "dotfiles"),
    );
  },
);
