import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmod, mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

const repo = process.cwd();
const version = spawnSync("nvim", ["--version"], { encoding: "utf8" });
const [, minor] = (version.stdout ?? "").match(/NVIM v0\.(\d+)/) ?? [];
const skip = version.status !== 0 ? "Neovim is not installed" : Number(minor) < 10 ? "herdr-nav needs Neovim 0.10+" : false;

const driver = `
package.path = os.getenv("REPO") .. "/home/config/nvim/lua/?.lua;" .. package.path
local nav = require("util.herdr-nav")
local log = os.getenv("NAV_LOG")
local function count()
  local file = io.open(log)
  if not file then return 0 end
  local n = 0
  for _ in file:lines() do n = n + 1 end
  file:close()
  return n
end
local results = {}
for _, step in ipairs(vim.json.decode(os.getenv("NAV_STEPS"))) do
  local verb, arg = step[1], step[2]
  if verb == "cmd" then vim.cmd(arg)
  elseif verb == "move" then nav.move(arg)
  elseif verb == "resize" then nav.resize(arg)
  elseif verb == "win" then results[#results + 1] = vim.fn.winnr()
  elseif verb == "width" then results[#results + 1] = vim.api.nvim_win_get_width(0)
  elseif verb == "height" then results[#results + 1] = vim.api.nvim_win_get_height(0)
  elseif verb == "detect" then results[#results + 1] = nav.detect() or "none"
  end
end
local expected = tonumber(os.getenv("NAV_EXPECT"))
vim.wait(expected > 0 and 3000 or 300, function() return expected > 0 and count() >= expected end, 10)
vim.wait(100)
io.stdout:write(vim.json.encode({ results = results }) .. "\\n")
`;

async function executable(file, source) {
  await writeFile(file, `#!${process.execPath}\n${source}`);
  await chmod(file, 0o755);
}

async function fixture(t) {
  const root = await mkdtemp(path.join(tmpdir(), "herdr-nav-"));
  t.after(() => rm(root, { recursive: true, force: true }));
  const bin = path.join(root, "bin");
  await mkdir(bin);
  const logger = (name, extra = "") => `
const { appendFileSync } = require("node:fs");
const args = process.argv.slice(2);
appendFileSync(process.env.NAV_LOG, JSON.stringify(["${name}", ...args${extra}]) + "\\n");
`;
  await executable(path.join(bin, "ps"), `
const { appendFileSync } = require("node:fs");
const chain = JSON.parse(process.env.NAV_CHAIN);
const pid = Number(process.argv[process.argv.indexOf("-p") + 1]);
appendFileSync(process.env.NAV_PS_LOG, pid + "\\n");
const index = pid > 9000 && pid <= 9000 + chain.length ? pid - 9000 : 0;
if (index >= chain.length) process.exit(1);
console.log(\`  \${index + 1 < chain.length ? 9001 + index : 1} \${chain[index]}\`);
`);
  await executable(path.join(bin, "herdr-app"), `${logger("herdr-app")}
if ((process.env.NAV_APP_FAIL ?? "").split(",").includes(args[1])) process.exit(1);
`);
  await executable(path.join(bin, "herdr-nav"), logger("herdr-nav", ', "pane=" + process.env.HERDR_ACTIVE_PANE_ID'));
  await executable(path.join(bin, "tmux"), logger("tmux"));
  const script = path.join(root, "driver.lua");
  await writeFile(script, driver);
  return { root, bin, script, log: path.join(root, "calls.jsonl"), psLog: path.join(root, "ps.log") };
}

async function lines(file) {
  try {
    return (await readFile(file, "utf8")).trim().split("\n").filter(Boolean);
  } catch (error) {
    if (error.code === "ENOENT") return [];
    throw error;
  }
}

async function run(t, { chain, env = {}, steps, expect = [] }) {
  const f = await fixture(t);
  const clean = Object.fromEntries(Object.entries(process.env).filter(([key]) => !/^(HERDR_|HC_|TMUX)/.test(key)));
  const result = spawnSync("nvim", ["--headless", "--clean", "-l", f.script], {
    env: {
      ...clean,
      ...env,
      PATH: `${f.bin}:${process.env.PATH}`,
      HOME: f.root,
      REPO: repo,
      NAV_LOG: f.log,
      NAV_PS_LOG: f.psLog,
      NAV_CHAIN: JSON.stringify(chain),
      NAV_STEPS: JSON.stringify(steps),
      NAV_EXPECT: String(expect.length),
    },
    encoding: "utf8",
    timeout: 15_000,
  });
  assert.equal(result.status, 0, result.stderr || result.stdout);
  const output = JSON.parse(result.stdout.trim().split("\n").pop());
  const calls = (await lines(f.log)).map((line) => JSON.parse(line));
  assert.deepEqual(calls, expect);
  return { ...output, psCalls: (await lines(f.psLog)).length };
}

const staleHerdr = { HERDR_ENV: "1", HERDR_PANE_ID: "w1:p2", HERDR_BIN_PATH: "/stale/herdr", HC_TERMINAL_ID: "t1" };

test("herdr-nav picks the nearest multiplexer and caches it", { skip }, async (t) => {
  await t.test("herdr-app despite stale herdr TUI variables", async (t) => {
    const out = await run(t, {
      chain: ["zsh", "herdr-core", "herdr-core", "launchd"],
      env: staleHerdr,
      steps: [["move", "left"], ["move", "up"], ["detect"]],
      expect: [["herdr-app", "do", "splits.go-left"], ["herdr-app", "do", "splits.go-up"]],
    });
    assert.deepEqual(out.results, ["app"]);
    assert.equal(out.psCalls, 2);
  });
  await t.test("herdr TUI despite an inherited HC_TERMINAL_ID", async (t) => {
    const out = await run(t, {
      chain: ["-zsh", "herdr", "launchd"],
      env: { HERDR_ENV: "1", HERDR_PANE_ID: "w1:p7", HC_TERMINAL_ID: "t1" },
      steps: [["move", "left"], ["detect"]],
      expect: [["herdr-nav", "focus", "left", "pane=w1:p7"]],
    });
    assert.deepEqual(out.results, ["tui"]);
  });
  await t.test("tmux inside herdr-app", async (t) => {
    const out = await run(t, {
      chain: ["zsh", "tmux", "zsh", "herdr-core"],
      env: staleHerdr,
      steps: [["move", "right"], ["detect"]],
      expect: [["tmux", "select-pane", "-R"]],
    });
    assert.deepEqual(out.results, ["tmux"]);
  });
  await t.test("nothing outside a multiplexer", async (t) => {
    const out = await run(t, { chain: ["zsh", "launchd"], steps: [["move", "down"], ["detect"]] });
    assert.deepEqual(out.results, ["none"]);
  });
});

test("herdr-nav falls back to pane.go when the herdr-app splits mod is missing", { skip }, async (t) => {
  await run(t, {
    chain: ["zsh", "herdr-core"],
    env: { ...staleHerdr, NAV_APP_FAIL: "splits.go-right" },
    steps: [["move", "right"]],
    expect: [["herdr-app", "do", "splits.go-right"], ["herdr-app", "do", "pane.go", "--direction", "right"]],
  });
});

test("herdr-nav moves between Neovim windows without asking the multiplexer", { skip }, async (t) => {
  const out = await run(t, {
    chain: ["zsh", "herdr-core"],
    env: staleHerdr,
    steps: [["cmd", "vsplit"], ["win"], ["move", "right"], ["win"], ["move", "left"], ["win"], ["cmd", "split"], ["move", "down"], ["win"]],
  });
  assert.deepEqual(out.results, [1, 2, 1, 2]);
  assert.equal(out.psCalls, 0);
});

test("herdr-nav resizes Neovim windows so the divider follows the key", { skip }, async (t) => {
  const out = await run(t, {
    chain: ["zsh", "herdr-core"],
    env: staleHerdr,
    steps: [
      ["cmd", "vsplit"], ["width"], ["resize", "left"], ["width"], ["resize", "right"], ["width"],
      ["cmd", "wincmd l"], ["width"], ["resize", "left"], ["width"],
      ["cmd", "split"], ["height"], ["resize", "up"], ["height"], ["cmd", "wincmd j"], ["height"], ["resize", "up"], ["height"],
    ],
  });
  const [left, narrower, restored, right, wider, top, shorter, bottom, taller] = out.results;
  assert.equal(narrower, left - 3);
  assert.equal(restored, left);
  assert.equal(wider, right + 3);
  assert.equal(shorter, top - 2);
  assert.equal(taller, bottom + 2);
  assert.equal(out.psCalls, 0);
});

test("herdr-nav hands resizes past Neovim's edge to the multiplexer", { skip }, async (t) => {
  await t.test("herdr-app", async (t) => {
    await run(t, {
      chain: ["zsh", "herdr-core"],
      env: staleHerdr,
      steps: [["resize", "left"], ["cmd", "split"], ["resize", "right"]],
      expect: [["herdr-app", "do", "splits.resize-pane-left"], ["herdr-app", "do", "splits.resize-pane-right"]],
    });
  });
  await t.test("herdr-app without the splits mod does not fall back", async (t) => {
    await run(t, {
      chain: ["zsh", "herdr-core"],
      env: { ...staleHerdr, NAV_APP_FAIL: "splits.resize-pane-up" },
      steps: [["resize", "up"]],
      expect: [["herdr-app", "do", "splits.resize-pane-up"]],
    });
  });
  await t.test("herdr TUI", async (t) => {
    await run(t, {
      chain: ["zsh", "herdr"],
      env: { HERDR_ENV: "1", HERDR_PANE_ID: "w1:p3" },
      steps: [["resize", "down"]],
      expect: [["herdr-nav", "resize-pane", "down", "pane=w1:p3"]],
    });
  });
  await t.test("tmux", async (t) => {
    await run(t, {
      chain: ["zsh", "tmux"],
      steps: [["resize", "right"]],
      expect: [["tmux", "resize-pane", "-R", "3"]],
    });
  });
});
