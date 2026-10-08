import assert from "node:assert/strict";
import { chmod, mkdir, mkdtemp, readFile, realpath, rm, writeFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";

const repo = process.cwd();
const functions = path.join(repo, "home/shared/functions");
const shells = {
  bash: ["bash", "--noprofile", "--norc", "-c"],
  zsh: ["zsh", "-f", "-c"],
};
const FIELD = "\x1f";
const RECORD = "\x1e";

// Fake herdr: records each call. `worktree create` makes a real Git worktree
// and answers like Herdr 0.9 (JSON on stdout, errors on stderr), and
// `workspace list` reports each fixture worktree as workspace w9.
const fakeHerdr = `#!/bin/sh
for a in "$@"; do printf '%s\\037' "$a"; done >>"$HERDR_LOG"
printf '\\036' >>"$HERDR_LOG"
case "$1 $2" in
"workspace list")
  printf '{"result":{"workspaces":['
  sep=
  for dir in "$WT_ROOT"/*; do
    [ -d "$dir" ] || continue
    printf '%s{"workspace_id":"w9","worktree":{"checkout_path":"%s","is_linked_worktree":true}}' "$sep" "$dir"
    sep=,
  done
  printf ']}}\\n'
  exit 0
  ;;
"worktree create") ;;
*) printf '{"result":{"type":"ok"}}\\n'; exit 0 ;;
esac
if [ -n "$FAIL_CREATE" ]; then
  printf '{"error":{"code":"worktree_create_failed","message":"fixture refused"}}\\n' >&2
  exit 1
fi
while [ $# -gt 0 ]; do
  case "$1" in
  --branch) branch=$2 ;;
  --base) base=$2 ;;
  --cwd) cwd=$2 ;;
  esac
  shift
done
checkout="$WT_ROOT/$(printf '%s' "$branch" | tr / -)"
mkdir -p "$WT_ROOT"
if [ -n "$base" ]; then
  git -C "$cwd" worktree add -q -b "$branch" "$checkout" "$base" >&2 || exit 1
else
  git -C "$cwd" worktree add -q "$checkout" "$branch" >&2 || exit 1
fi
printf '{"result":{"type":"worktree_created","root_pane":{"pane_id":"w9:p1","cwd":"%s"},"worktree":{"path":"%s","branch":"%s"}}}\\n' "$checkout" "$checkout" "$branch"
`;

// Fake pi: records its working directory and arguments.
const fakePi = `#!/bin/sh
{ pwd -P; for a in "$@"; do printf '%s\\037' "$a"; done; } >>"$PI_LOG"
printf '\\036' >>"$PI_LOG"
`;

async function fixture(t) {
  const directory = await realpath(await mkdtemp(path.join(os.tmpdir(), "pi-herdr-worktree-")));
  t.after(() => rm(directory, { recursive: true, force: true }));
  const bin = path.join(directory, "bin");
  await mkdir(bin);
  await writeFile(path.join(bin, "herdr"), fakeHerdr);
  await writeFile(path.join(bin, "pi"), fakePi);
  await chmod(path.join(bin, "herdr"), 0o755);
  await chmod(path.join(bin, "pi"), 0o755);

  const checkout = path.join(directory, "repo");
  await mkdir(path.join(checkout, "sub dir"), { recursive: true });
  const env = {
    ...process.env,
    PATH: `${bin}:${process.env.PATH}`,
    HERDR_ENV: "1",
    HERDR_BIN_PATH: path.join(bin, "herdr"),
    HERDR_LOG: path.join(directory, "herdr.log"),
    PI_LOG: path.join(directory, "pi.log"),
    WT_ROOT: path.join(directory, "worktrees"),
    GIT_CONFIG_GLOBAL: "/dev/null",
    GIT_CONFIG_NOSYSTEM: "1",
    GIT_AUTHOR_NAME: "T",
    GIT_AUTHOR_EMAIL: "t@example.com",
    GIT_COMMITTER_NAME: "T",
    GIT_COMMITTER_EMAIL: "t@example.com",
  };
  delete env.HERDR_SOCKET_PATH;
  const gitIn = (cwd, ...args) => {
    const result = spawnSync("git", ["-C", cwd, ...args], { env, encoding: "utf8" });
    assert.equal(result.status, 0, result.stderr);
    return result.stdout.trim();
  };
  const git = (...args) => gitIn(checkout, ...args);
  git("init", "-q", "-b", "main");
  await writeFile(path.join(checkout, "sub dir", "tracked.txt"), "tracked\n");
  git("add", ".");
  git("commit", "-q", "-m", "init");

  const read = async (file) => {
    if (!existsSync(file)) return [];
    const text = await readFile(file, "utf8");
    return text.split(RECORD).filter(Boolean).map((record) => record.split(FIELD).slice(0, -1));
  };
  return {
    directory,
    checkout,
    env,
    git,
    gitIn,
    head: git("rev-parse", "HEAD"),
    herdrCalls: () => read(env.HERDR_LOG),
    piCalls: async () => {
      if (!existsSync(env.PI_LOG)) return [];
      const text = await readFile(env.PI_LOG, "utf8");
      return text.split(RECORD).filter(Boolean).map((record) => {
        const [cwd, ...rest] = record.split("\n");
        return { cwd, args: rest.join("\n").split(FIELD).slice(0, -1) };
      });
    },
    // Runs `pi <args>` through the shell wrapper from a subdirectory.
    run: (shell, args, extraEnv = {}) => {
      const quoted = args.map((arg) => `'${arg.replaceAll("'", `'\\''`)}'`).join(" ");
      const script = `. ${JSON.stringify(functions)}; cd ${JSON.stringify(path.join(checkout, "sub dir"))} && pi ${quoted}`;
      const [command, ...flags] = shells[shell];
      return spawnSync(command, [...flags, script], { env: { ...env, ...extraEnv }, encoding: "utf8" });
    },
    // Runs the command typed into the worktree pane, answering the exit prompt.
    typed: (shell, command, answer) => {
      const [program, ...flags] = shells[shell];
      return spawnSync(program, [...flags, `. ${JSON.stringify(functions)}; ${command}`], {
        cwd: directory, env: { ...env, HERDR_ENV: "1" }, encoding: "utf8", input: answer,
      });
    },
    // Opens worktree `name` through the wrapper and returns the typed pane command.
    open: async (shell, name, args = []) => {
      const result = spawnSync(shells[shell][0], [...shells[shell].slice(1),
        `. ${JSON.stringify(functions)}; cd ${JSON.stringify(checkout)} && pi --worktree ${name} ${args.join(" ")}`,
      ], { env, encoding: "utf8" });
      assert.equal(result.status, 0, result.stderr);
      const calls = await read(env.HERDR_LOG);
      return calls.at(-1)[3];
    },
  };
}

for (const shell of Object.keys(shells)) {
  test(`${shell}: pi --worktree opens a Herdr worktree and starts pi there without a local pi`, async (t) => {
    const f = await fixture(t);
    const result = f.run(shell, ["--worktree", "fix", "--model", "sonnet", "fix the bug's $HOME"]);
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(await f.piCalls(), [], "no pi starts in the launching pane");

    const calls = await f.herdrCalls();
    const branch = "pi-worktree/fix";
    const worktree = path.join(f.env.WT_ROOT, "pi-worktree-fix");
    assert.deepEqual(calls[0], [
      "worktree", "create", "--cwd", path.join(f.checkout, "sub dir"), "--branch", branch,
      "--base", f.head, "--label", "fix", "--focus",
    ]);
    assert.equal(calls.length, 2);
    assert.deepEqual((await f.herdrCalls()).slice(2), [], "declining closes nothing");
    const [group, action, pane, command] = calls[1];
    assert.deepEqual([group, action, pane], ["pane", "run", "w9:p1"]);
    assert.match(result.stdout, /started in Herdr worktree/);

    assert.match(command, /; _pi_herdr_worktree_close pi-worktree\/fix main; }$/);
    // The typed command reproduces the same directory and arguments in either
    // shell, then asks before removing the worktree.
    for (const paneShell of Object.keys(shells)) {
      const typed = f.typed(paneShell, command, "n\n");
      assert.equal(typed.status, 0, typed.stderr);
      assert.match(typed.stdout, /Remove worktree .*pi-worktree-fix and close its Herdr workspace\?\n/);
      assert.match(typed.stdout, /Branch pi-worktree\/fix has no commits beyond main and is deleted\.\n\(Y\/n\)/);
      assert.match(typed.stdout, /Kept /);
    }
    assert.equal(existsSync(worktree), true);
    for (const call of await f.piCalls()) {
      assert.deepEqual(call, {
        cwd: path.join(worktree, "sub dir"),
        args: ["--model", "sonnet", "fix the bug's $HOME"],
      });
    }
    assert.equal((await f.piCalls()).length, 2);
  });

  test(`${shell}: an existing branch is reopened and generated names are valid`, async (t) => {
    const f = await fixture(t);
    f.git("branch", "pi-worktree/again");
    const reopened = f.run(shell, ["--worktree=again"]);
    assert.equal(reopened.status, 0, reopened.stderr);
    assert.equal(f.run(shell, ["--worktree", "--thinking", "low"]).status, 0);
    const [reopen, , generated, run] = await f.herdrCalls();
    assert.equal(reopen.includes("--base"), false, "Herdr checks out the existing branch");
    const branch = generated[generated.indexOf("--branch") + 1];
    assert.match(branch, /^pi-worktree\/\d{8}-\d{6}-\d+$/);
    assert.match(run[3], / && \{ pi --thinking low; _pi_herdr_worktree_close pi-worktree\/\d{8}-\d{6}-\d+ main; \}$/);
  });

  test(`${shell}: other launches run pi directly`, async (t) => {
    const f = await fixture(t);
    const cases = [
      [["--model", "sonnet"], {}],
      [["--worktree", "fix"], { HERDR_ENV: "" }],
      [["--worktree", "fix", "-c"], {}],
      [["--worktree", "--session=abc"], {}],
      [["--worktree", "fix", "-p", "hello"], {}],
      [["--worktree", "fix", "--mode", "rpc"], {}],
    ];
    for (const [args, env] of cases) {
      const result = f.run(shell, args, env);
      assert.equal(result.status, 0, result.stderr);
    }
    assert.deepEqual(await f.herdrCalls(), []);
    assert.deepEqual((await f.piCalls()).map((call) => call.args), cases.map(([args]) => args));
  });

  test(`${shell}: invalid names and Herdr failures start nothing`, async (t) => {
    const f = await fixture(t);
    for (const name of ["a..b", "x.lock", "flag=1", "a".repeat(101)]) {
      const result = f.run(shell, [`--worktree=${name}`]);
      assert.equal(result.status, 2, name);
      assert.match(result.stderr, /invalid worktree name/);
    }
    assert.deepEqual(await f.herdrCalls(), []);

    const failed = f.run(shell, ["--worktree", "fix"], { FAIL_CREATE: "1" });
    assert.equal(failed.status, 1);
    assert.match(failed.stderr, /Herdr could not create the worktree: fixture refused/);
    assert.equal((await f.herdrCalls()).length, 1);
    assert.deepEqual(await f.piCalls(), []);
  });

  test(`${shell}: confirming after pi exits removes a clean worktree, its empty branch, and its workspace`, async (t) => {
    const f = await fixture(t);
    const command = await f.open(shell, "done");
    const worktree = path.join(f.env.WT_ROOT, "pi-worktree-done");
    const result = f.typed(shell, command, "\n");
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stdout, /\(Y\/n\)/, "nothing is lost, so Enter confirms");
    assert.equal(existsSync(worktree), false);
    assert.equal(spawnSync("git", ["-C", f.checkout, "show-ref", "--verify", "--quiet", "refs/heads/pi-worktree/done"]).status, 1);
    assert.deepEqual((await f.herdrCalls()).at(-1), ["workspace", "close", "w9"]);
  });

  test(`${shell}: uncommitted files default to keeping the worktree, and commits always survive`, async (t) => {
    const f = await fixture(t);
    const command = await f.open(shell, "work");
    const worktree = path.join(f.env.WT_ROOT, "pi-worktree-work");
    await writeFile(path.join(worktree, "committed.txt"), "keep\n");
    f.gitIn(worktree, "add", "committed.txt");
    f.gitIn(worktree, "commit", "-q", "-m", "work");
    const committed = f.gitIn(worktree, "rev-parse", "HEAD");
    await writeFile(path.join(worktree, "scratch.txt"), "draft\n");
    await writeFile(path.join(worktree, ".env"), "SECRET=1\n");
    await writeFile(path.join(worktree, ".gitignore"), ".env\n");

    const kept = f.typed(shell, command, "\n");
    assert.equal(kept.status, 0, kept.stderr);
    assert.match(kept.stdout, /These files are deleted:\n(.*\n)*\?\? scratch\.txt\n/);
    assert.match(kept.stdout, /!! \.env/);
    assert.match(kept.stdout, /Branch pi-worktree\/work is kept with 1 commit\(s\) not in main\.\n\(y\/N\)/);
    assert.equal(existsSync(path.join(worktree, "scratch.txt")), true, "Enter keeps files");

    const removed = f.typed(shell, command, "y\n");
    assert.equal(removed.status, 0, removed.stderr);
    assert.equal(existsSync(worktree), false);
    assert.equal(f.git("rev-parse", "refs/heads/pi-worktree/work"), committed);
    assert.deepEqual((await f.herdrCalls()).at(-1), ["workspace", "close", "w9"]);
  });

  test(`${shell}: unreachable detached commits get a safety branch before removal`, async (t) => {
    const f = await fixture(t);
    const command = await f.open(shell, "detached");
    const worktree = path.join(f.env.WT_ROOT, "pi-worktree-detached");
    f.gitIn(worktree, "checkout", "-q", "--detach");
    f.gitIn(worktree, "commit", "-q", "--allow-empty", "-m", "detached");
    const detached = f.gitIn(worktree, "rev-parse", "HEAD");
    const result = f.typed(shell, command, "y\n");
    assert.equal(result.status, 0, result.stderr);
    const safety = `pi-worktree/detached-detached-${detached.slice(0, 8)}`;
    assert.match(result.stdout, new RegExp(`kept on branch ${safety}`));
    assert.equal(existsSync(worktree), false);
    assert.equal(f.git("rev-parse", `refs/heads/${safety}`), detached);
  });
}
