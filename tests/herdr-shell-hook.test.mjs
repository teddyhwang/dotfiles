import assert from "node:assert/strict";
import { chmod, mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import net from "node:net";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { setTimeout as delay } from "node:timers/promises";
import test from "node:test";

const repo = process.cwd();
const functions = path.join(repo, "home/shared/functions");
const shells = {
  bash: ["bash", "--noprofile", "--norc", "-c"],
  zsh: ["zsh", "-f", "-c"],
};

function run(command, args, options = {}) {
  return spawnSync(command, args, { encoding: "utf8", ...options });
}

async function fixture(t) {
  const directory = await mkdtemp(path.join(os.tmpdir(), "herdr-shell-hook-"));
  t.after(() => rm(directory, { recursive: true, force: true }));

  const socketPath = path.join(directory, "herdr.sock");
  const server = net.createServer();
  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(socketPath, resolve);
  });
  t.after(() => server.close());

  const callLog = path.join(directory, "calls");
  const herdr = path.join(directory, "herdr");
  await writeFile(herdr, "#!/bin/sh\nprintf '%s %s\\n' \"$STEP\" \"$*\" >>\"$CALL_LOG\"\n");
  await chmod(herdr, 0o755);

  const env = {
    ...process.env,
    CALL_LOG: callLog,
    GIT_AUTHOR_EMAIL: "test@example.com",
    GIT_AUTHOR_NAME: "Test",
    GIT_COMMITTER_EMAIL: "test@example.com",
    GIT_COMMITTER_NAME: "Test",
    GIT_CONFIG_GLOBAL: "/dev/null",
    GIT_CONFIG_NOSYSTEM: "1",
    HERDR_BIN_PATH: herdr,
    HERDR_SOCKET_PATH: socketPath,
  };
  const checkout = path.join(directory, "repo");
  const git = (...args) => {
    const result = run("git", ["-C", checkout, ...args], { env });
    assert.equal(result.status, 0, result.stderr);
  };
  await mkdir(path.join(checkout, "sub"), { recursive: true });
  // tec zones in a monorepo checkout, one nested inside another.
  await mkdir(path.join(checkout, "zones/alpha/deep"), { recursive: true });
  await mkdir(path.join(checkout, "zones/alpha/inner"), { recursive: true });
  await mkdir(path.join(checkout, "zones/beta"), { recursive: true });
  for (const zone of ["zones/alpha", "zones/alpha/inner", "zones/beta"]) {
    await writeFile(path.join(checkout, zone, "zone.nix"), "{ }\n");
  }
  git("init", "-q", "-b", "main");
  git("commit", "-q", "--allow-empty", "-m", "init");
  git("branch", "feature");
  git("worktree", "add", "-q", path.join(directory, "linked"), "-b", "linked");
  await mkdir(path.join(directory, "plain"));
  return { callLog, directory, env };
}

async function settledCalls(callLog, expected) {
  // The hook backgrounds Herdr, so wait for the expected calls and then long
  // enough to catch any unexpected extra call.
  const deadline = Date.now() + 5_000;
  let lines = [];
  while (Date.now() < deadline) {
    lines = (await readFile(callLog, "utf8").catch(() => "")).split("\n").filter(Boolean);
    if (lines.length >= expected) break;
    await delay(25);
  }
  await delay(200);
  return (await readFile(callLog, "utf8").catch(() => "")).split("\n").filter(Boolean).sort();
}

for (const [shell, command] of Object.entries(shells)) {
  test(`${shell} prompt refreshes Herdr tab names when the checkout or zone changes`, async (t) => {
    const { callLog, directory, env } = await fixture(t);
    const script = `
      . "$FUNCTIONS" || exit 1
      prompt() { STEP=$1; export STEP; _herdr_tab_autoname_precmd; }
      cd "$ROOT/repo" && prompt baseline
      prompt unchanged
      cd sub && prompt subdirectory
      cd "$ROOT/repo/zones/alpha" && prompt zone
      cd deep && prompt zone-subdirectory
      cd "$ROOT/repo/zones/alpha/inner" && prompt nested-zone
      cd "$ROOT/repo/zones/beta" && prompt other-zone
      cd "$ROOT/repo" && prompt zone-exit
      git switch -q feature && prompt branch
      git checkout -q --detach && prompt detached
      cd "$ROOT/linked" && prompt worktree
      cd "$ROOT/plain" && prompt directory
      (exit 7); _herdr_tab_autoname_precmd; printf 'status=%s\\n' "$?"
    `;
    const result = run(command[0], [...command.slice(1), script], {
      env: { ...env, FUNCTIONS: functions, ROOT: directory },
    });
    assert.equal(result.status, 0, result.stderr);
    assert.equal(result.stdout, "status=7\n");

    const invoke = "plugin action invoke refresh --plugin teddyhwang.tab-autoname";
    assert.deepEqual(await settledCalls(callLog, 8), [
      `branch ${invoke}`,
      `detached ${invoke}`,
      `directory ${invoke}`,
      `nested-zone ${invoke}`,
      `other-zone ${invoke}`,
      `worktree ${invoke}`,
      `zone ${invoke}`,
      `zone-exit ${invoke}`,
    ]);
  });
}

test("prompt hooks register once and only inside Herdr", async (t) => {
  const { env } = await fixture(t);
  const zsh = run(
    "zsh",
    ["-f", "-c", '. "$FUNCTIONS"; . "$FUNCTIONS"; print -r -- "${(j: :)precmd_functions}"'],
    { env: { ...env, FUNCTIONS: functions } },
  );
  assert.equal(zsh.status, 0, zsh.stderr);
  assert.equal(zsh.stdout, "_herdr_tab_autoname_precmd\n");

  const bash = run(
    "bash",
    ["--noprofile", "--norc", "-c", '. "$FUNCTIONS"; . "$FUNCTIONS"; printf "%s\\n" "$PROMPT_COMMAND"'],
    { env: { ...env, FUNCTIONS: functions, PROMPT_COMMAND: "existing_prompt" } },
  );
  assert.equal(bash.status, 0, bash.stderr);
  assert.equal(bash.stdout, "_herdr_tab_autoname_precmd;existing_prompt\n");

  const preexec = run(
    "bash",
    [
      "--noprofile",
      "--norc",
      "-c",
      'bash_preexec_imported=defined; precmd_functions=(other); . "$FUNCTIONS"; . "$FUNCTIONS"; printf "%s\\n" "${precmd_functions[*]}" "${PROMPT_COMMAND:-}"',
    ],
    { env: { ...env, FUNCTIONS: functions, PROMPT_COMMAND: "" } },
  );
  assert.equal(preexec.status, 0, preexec.stderr);
  assert.equal(preexec.stdout, "other _herdr_tab_autoname_precmd\n\n");

  const outside = { ...env, FUNCTIONS: functions, PROMPT_COMMAND: "" };
  delete outside.HERDR_SOCKET_PATH;
  const outsideZsh = run("zsh", ["-f", "-c", '. "$FUNCTIONS"; print -r -- "${#precmd_functions}"'], {
    env: outside,
  });
  assert.equal(outsideZsh.stdout, "0\n", outsideZsh.stderr);
  const outsideBash = run(
    "bash",
    ["--noprofile", "--norc", "-c", '. "$FUNCTIONS"; printf "[%s]\\n" "${PROMPT_COMMAND:-}"'],
    { env: outside },
  );
  assert.equal(outsideBash.stdout, "[]\n", outsideBash.stderr);
});
