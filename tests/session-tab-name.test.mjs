import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import net from "node:net";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { pathToFileURL } from "node:url";
import {
  default as sessionTabNameExtension,
  deriveLegacySessionName,
  deriveSessionName,
  firstUserPrompt,
  isAloneInTab,
  normalizeAiSessionName,
  panesInTab,
  renameHerdrTab,
  toHerdrLabel,
} from "../home/pi-agent/extensions/session-tab-name.ts";

async function waitFor(predicate) {
  for (let attempt = 0; attempt < 20; attempt += 1) {
    if (predicate()) return;
    await new Promise((resolve) => setImmediate(resolve));
  }
  assert.fail("Timed out waiting for background naming");
}

test("derives a compact fallback when AI naming is unavailable", () => {
  assert.equal(
    deriveSessionName(
      "i want to create an extension when a pi session starts, then update Herdr's tab",
    ),
    "Create an extension when",
  );
  assert.equal(
    deriveSessionName(
      "Can you please fix the authentication timeout in src/api.ts?",
    ),
    "Fix the authentication timeout",
  );
  assert.equal(deriveSessionName("```ts\nconst secret = true\n```"), undefined);
  assert.equal(
    deriveLegacySessionName(
      "i want to create an extension when a pi session starts, then update Herdr's tab",
    ),
    "Create an extension when a pi session starts…",
  );
});

test("normalizes AI output to three or four words", () => {
  assert.equal(
    normalizeAiSessionName('Session name: "Pi Session Tab Naming."'),
    "Pi Session Tab Naming",
  );
  assert.equal(
    normalizeAiSessionName("Improve Herdr naming behavior today please"),
    "Improve Herdr naming behavior",
  );
  assert.equal(normalizeAiSessionName("Naming fix"), undefined);
});

test("redacts credentials and strips terminal control characters", () => {
  const name = deriveSessionName("password=hunter2\u001b[31m fix login");
  assert.equal(name, "Password=[redacted] fix login");
  assert.equal(
    toHerdrLabel("A very long session name that needs a compact tab label"),
    "A very long session name that…",
  );
});

test("finds the first textual user prompt on a session branch", () => {
  assert.equal(
    firstUserPrompt([
      { type: "model_change" },
      {
        type: "message",
        message: {
          role: "user",
          content: [{ type: "text", text: "First task" }],
        },
      },
      { type: "message", message: { role: "user", content: "Second task" } },
    ]),
    "First task",
  );
});

test("asks the active model to name an unnamed session", async () => {
  const handlers = new Map();
  let sessionName;
  let namingRequest;
  let finishNaming;
  const model = { provider: "test", id: "test-model", api: "openai-responses" };
  const pi = {
    on(event, handler) {
      handlers.set(event, handler);
    },
    getSessionName() {
      return sessionName;
    },
    setSessionName(name) {
      sessionName = name;
    },
  };
  const ctx = {
    sessionManager: { getBranch: () => [] },
    model,
    signal: undefined,
    modelRegistry: {
      hasConfiguredAuth: () => true,
      complete(requestModel, context, options) {
        namingRequest = { requestModel, context, options };
        return new Promise((resolve) => {
          finishNaming = () =>
            resolve({
              content: [{ type: "text", text: "AI Session Tab Naming" }],
            });
        });
      },
    },
  };

  sessionTabNameExtension(pi);
  handlers.get("session_start")({}, ctx);
  handlers.get("input")({ text: "please add retry handling" }, ctx);
  const handlerResult = handlers.get("before_agent_start")(
    { prompt: "please add retry handling" },
    ctx,
  );

  assert.equal(handlerResult, undefined);
  assert.equal(sessionName, undefined);
  assert.equal(namingRequest.requestModel, model);
  assert.match(
    namingRequest.context.systemPrompt,
    /exactly three or four words/,
  );
  assert.equal(namingRequest.options.maxTokens, 64);
  assert.equal(namingRequest.options.cacheRetention, "none");

  finishNaming();
  await waitFor(() => sessionName === "AI Session Tab Naming");
});

test("upgrades a legacy automatic name to an AI summary", async () => {
  const handlers = new Map();
  const prompt =
    "i want to create an extension when a pi session starts, then update Herdr's tab";
  let sessionName = deriveLegacySessionName(prompt);
  const pi = {
    on(event, handler) {
      handlers.set(event, handler);
    },
    getSessionName() {
      return sessionName;
    },
    setSessionName(name) {
      sessionName = name;
    },
  };
  const ctx = {
    sessionManager: {
      getBranch: () => [
        { type: "message", message: { role: "user", content: prompt } },
      ],
    },
    model: { provider: "test", id: "test-model", api: "openai-responses" },
    signal: undefined,
    modelRegistry: {
      hasConfiguredAuth: () => true,
      async complete() {
        return {
          content: [{ type: "text", text: "Pi Herdr Session Naming" }],
        };
      },
    },
  };

  sessionTabNameExtension(pi);
  const handlerResult = handlers.get("session_start")({}, ctx);

  assert.equal(handlerResult, undefined);
  assert.equal(sessionName, deriveLegacySessionName(prompt));
  await waitFor(() => sessionName === "Pi Herdr Session Naming");
});

test("cancels background naming when the session shuts down", async () => {
  const handlers = new Map();
  let sessionName;
  let namingSignal;
  const pi = {
    on(event, handler) {
      handlers.set(event, handler);
    },
    getSessionName() {
      return sessionName;
    },
    setSessionName(name) {
      sessionName = name;
    },
  };
  const ctx = {
    sessionManager: { getBranch: () => [] },
    model: { provider: "test", id: "test-model", api: "openai-responses" },
    modelRegistry: {
      hasConfiguredAuth: () => true,
      complete(_model, _context, options) {
        namingSignal = options.signal;
        return new Promise((_resolve, reject) => {
          namingSignal.addEventListener("abort", () =>
            reject(new Error("aborted")),
          );
        });
      },
    },
  };

  sessionTabNameExtension(pi);
  handlers.get("session_start")({}, ctx);
  handlers.get("input")({ text: "rename this session" }, ctx);
  handlers.get("before_agent_start")({ prompt: "rename this session" }, ctx);
  handlers.get("session_shutdown")({ reason: "quit" }, ctx);

  assert.equal(namingSignal.aborted, true);
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(sessionName, undefined);
});

test("sends a tab.rename request to the inherited Herdr tab", async (t) => {
  if (process.platform === "win32") {
    t.skip("Unix socket fixture");
    return;
  }

  const socketPath = path.join(
    os.tmpdir(),
    `pi-session-tab-name-${process.pid}-${Date.now()}.sock`,
  );
  let request;
  const server = net.createServer((socket) => {
    let buffer = "";
    socket.on("data", (chunk) => {
      buffer += chunk.toString("utf8");
      const newline = buffer.indexOf("\n");
      if (newline < 0) return;
      request = JSON.parse(buffer.slice(0, newline));
      socket.end(
        `${JSON.stringify({ id: request.id, result: { type: "tab_info" } })}\n`,
      );
    });
  });
  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(socketPath, resolve);
  });
  t.after(() => server.close());

  assert.equal(
    await renameHerdrTab({ socketPath, tabId: "w6:tB" }, "Pi session labels"),
    true,
  );
  assert.deepEqual(
    { method: request.method, params: request.params },
    {
      method: "tab.rename",
      params: { tab_id: "w6:tB", label: "Pi session labels" },
    },
  );
});

test(
  "session hooks detach and cancel Herdr rename I/O",
  { timeout: 2_000 },
  async (t) => {
    if (process.platform === "win32") {
      t.skip("Unix socket fixture");
      return;
    }

    const socketPath = path.join(
      os.tmpdir(),
      `pi-detached-rename-${process.pid}-${Date.now()}.sock`,
    );
    const sockets = new Set();
    let finishRenameRequest;
    const renameRequested = new Promise((resolve) => {
      finishRenameRequest = resolve;
    });
    let finishRenameClose;
    const renameClosed = new Promise((resolve) => {
      finishRenameClose = resolve;
    });
    const server = net.createServer((socket) => {
      sockets.add(socket);
      socket.once("close", () => sockets.delete(socket));
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
                  panes: [{ pane_id: "w9:p1", tab_id: "w9:tA" }],
                },
              },
            })}\n`,
          );
          return;
        }
        if (request.method === "tab.rename") {
          finishRenameRequest();
          socket.once("close", finishRenameClose);
          // Deliberately never reply. session_shutdown must abort this request.
        }
      });
    });
    await new Promise((resolve, reject) => {
      server.once("error", reject);
      server.listen(socketPath, resolve);
    });

    const previousEnv = {
      HERDR_ENV: process.env.HERDR_ENV,
      HERDR_SOCKET_PATH: process.env.HERDR_SOCKET_PATH,
      HERDR_TAB_ID: process.env.HERDR_TAB_ID,
    };
    process.env.HERDR_ENV = "1";
    process.env.HERDR_SOCKET_PATH = socketPath;
    process.env.HERDR_TAB_ID = "w9:tA";
    t.after(() => {
      for (const socket of sockets) socket.destroy();
      server.close();
      for (const [key, value] of Object.entries(previousEnv)) {
        if (value === undefined) delete process.env[key];
        else process.env[key] = value;
      }
    });

    const handlers = new Map();
    const pi = {
      on(event, handler) {
        handlers.set(event, handler);
      },
      getSessionName() {
        return "Detached Herdr Rename";
      },
      setSessionName() {},
    };
    const ctx = {
      sessionManager: { getBranch: () => [] },
      model: undefined,
      modelRegistry: { hasConfiguredAuth: () => false },
    };
    sessionTabNameExtension(pi);

    // A lifecycle handler must never return the socket promise to Pi.
    assert.equal(handlers.get("session_start")({}, ctx), undefined);
    await renameRequested;
    assert.equal(
      handlers.get("session_shutdown")({ reason: "quit" }, ctx),
      undefined,
    );
    await renameClosed;
  },
);

test(
  "an unanswered Herdr rename cannot keep Pi's process alive",
  { timeout: 2_000 },
  async (t) => {
    if (process.platform === "win32") {
      t.skip("Unix socket fixture");
      return;
    }

    const socketPath = path.join(
      os.tmpdir(),
      `pi-unref-rename-${process.pid}-${Date.now()}.sock`,
    );
    const sockets = new Set();
    const server = net.createServer((socket) => {
      sockets.add(socket);
      socket.once("close", () => sockets.delete(socket));
      // Never reply: the child must exit because its Herdr socket is unref'ed,
      // not because the request completed.
    });
    await new Promise((resolve, reject) => {
      server.once("error", reject);
      server.listen(socketPath, resolve);
    });
    t.after(() => {
      for (const socket of sockets) socket.destroy();
      server.close();
    });

    const extensionUrl = pathToFileURL(
      path.resolve("home/pi-agent/extensions/session-tab-name.ts"),
    ).href;
    const child = spawn(
      process.execPath,
      [
        "--input-type=module",
        "--eval",
        [
          `import { renameHerdrTab } from ${JSON.stringify(extensionUrl)};`,
          `void renameHerdrTab(${JSON.stringify({ socketPath, tabId: "w1:t1" })}, "Nonblocking", 10000);`,
          "await new Promise((resolve) => setTimeout(resolve, 100));",
        ].join("\n"),
      ],
      { stdio: ["ignore", "pipe", "pipe"] },
    );
    let stderr = "";
    child.stderr.setEncoding("utf8");
    child.stderr.on("data", (chunk) => {
      stderr += chunk;
    });

    const exit = new Promise((resolve, reject) => {
      child.once("error", reject);
      child.once("exit", (code, signal) => resolve({ code, signal }));
    });
    const timeout = setTimeout(() => child.kill("SIGKILL"), 1_500);
    const result = await exit;
    clearTimeout(timeout);
    assert.deepEqual(result, { code: 0, signal: null }, stderr);
  },
);

test("counts only the panes sharing this tab", () => {
  const snapshot = {
    panes: [
      { pane_id: "w1:p1", tab_id: "w1:tA" },
      { pane_id: "w1:p2", tab_id: "w1:tA" },
      { pane_id: "w1:p3", tab_id: "w1:tB" },
    ],
  };
  assert.equal(panesInTab(snapshot, "w1:tA"), 2);
  assert.equal(panesInTab(snapshot, "w1:tB"), 1);
  assert.equal(panesInTab(snapshot, "w1:tZ"), 0);
  assert.equal(panesInTab(undefined, "w1:tA"), undefined);
  assert.equal(panesInTab({ panes: "nonsense" }, "w1:tA"), undefined);
});

test("claims the tab label only when Pi is alone in the tab", async (t) => {
  if (process.platform === "win32") {
    t.skip("Unix socket fixture");
    return;
  }

  // The tab label speaks for every visible pane, so a Pi session sharing its
  // tab leaves the naming to herdr-tab-autoname, which can see them all.
  const serve = async (panes) => {
    const socketPath = path.join(
      os.tmpdir(),
      `pi-alone-${process.pid}-${Math.random().toString(36).slice(2)}.sock`,
    );
    const server = net.createServer((socket) => {
      let buffer = "";
      socket.on("data", (chunk) => {
        buffer += chunk.toString("utf8");
        const newline = buffer.indexOf("\n");
        if (newline < 0) return;
        const request = JSON.parse(buffer.slice(0, newline));
        socket.end(
          `${JSON.stringify({
            id: request.id,
            result: { snapshot: { panes } },
          })}\n`,
        );
      });
    });
    await new Promise((resolve, reject) => {
      server.once("error", reject);
      server.listen(socketPath, resolve);
    });
    t.after(() => server.close());
    return socketPath;
  };

  const solo = await serve([{ pane_id: "w6:p1", tab_id: "w6:tB" }]);
  assert.equal(await isAloneInTab({ socketPath: solo, tabId: "w6:tB" }), true);

  const split = await serve([
    { pane_id: "w6:p1", tab_id: "w6:tB" },
    { pane_id: "w6:p2", tab_id: "w6:tB" },
  ]);
  assert.equal(
    await isAloneInTab({ socketPath: split, tabId: "w6:tB" }),
    false,
  );

  // An unreachable server must not strand a solo tab at its number; the
  // daemon corrects an over-eager rename on its next pass.
  assert.equal(
    await isAloneInTab(
      { socketPath: path.join(os.tmpdir(), "pi-no-such.sock"), tabId: "w6:tB" },
      200,
    ),
    true,
  );
});
