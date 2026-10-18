import assert from "node:assert/strict";
import { chmod, mkdir, mkdtemp, readFile, readdir, rm, symlink, writeFile } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

const repo = process.cwd();
const script = path.join(repo, "bootstrap.sh");
const realGit = spawnSync("sh", ["-c", "command -v git"], { encoding: "utf8" }).stdout.trim();
const python = String.raw`
import errno, os, pty, subprocess, sys
if os.environ.get("NO_TTY") == "1":
    sys.exit(subprocess.run(["/bin/sh", sys.argv[1]], start_new_session=True).returncode)
pid, master = pty.fork()
if pid == 0:
    # Simulate a downloaded script with no terminal on stdin. The bootstrap
    # must reconnect prompts and setup to its controlling terminal itself.
    null = os.open(os.devnull, os.O_RDONLY)
    os.dup2(null, 0)
    os.close(null)
    os.execl("/bin/sh", "sh", sys.argv[1])
os.write(master, b"\n")
while True:
    try:
        data = os.read(master, 65536)
        if not data:
            break
        sys.stdout.buffer.write(data)
        sys.stdout.buffer.flush()
    except OSError as error:
        if error.errno == errno.EIO:
            break
        raise
os.close(master)
_, status = os.waitpid(pid, 0)
sys.exit(os.waitstatus_to_exitcode(status))
`;

async function fixture(t, ready = true) {
  const root = await mkdtemp(path.join(tmpdir(), "dotfiles-bootstrap-test-"));
  t.after(() => rm(root, { recursive: true, force: true }));
  const home = path.join(root, "home with spaces");
  const bin = path.join(root, "bin");
  const remote = path.join(root, "remote");
  const log = path.join(root, "calls");
  const clt = path.join(root, "clt-ready");
  for (const dir of [home, bin, remote]) await mkdir(dir);
  const env = {
    ...process.env, HOME: home, PATH: `${bin}:${process.env.PATH}`,
    GIT_CONFIG_GLOBAL: "/dev/null", GIT_CONFIG_NOSYSTEM: "1",
    REAL_GIT: realGit, FAKE_REMOTE: remote, BOOTSTRAP_LOG: log, CLT_READY: clt,
    FAKE_UID: "501", FAKE_OS: "Darwin", SETUP_STATUS: "0", CLT_MODE: "install", NO_TTY: "0",
  };
  const git = (...args) => {
    const result = spawnSync(realGit, args, { env, encoding: "utf8" });
    assert.equal(result.status, 0, result.stderr);
    return result;
  };
  const executable = async (name, source) => {
    await writeFile(path.join(bin, name), `#!/bin/sh\n${source}\n`);
    await chmod(path.join(bin, name), 0o755);
  };
  await executable("uname", 'printf "%s\\n" "$FAKE_OS"');
  await executable("id", 'printf "%s\\n" "$FAKE_UID"');
  await executable("xcode-select", `printf 'xcode-select %s\\n' "$*" >>"$BOOTSTRAP_LOG"
case "$1" in
  -p) test -f "$CLT_READY" ;;
  --install) test "$CLT_MODE" != fail || exit 1; if [ "$CLT_MODE" = install ]; then touch "$CLT_READY"; fi ;;
  *) exit 99 ;;
esac`);
  await executable("git", `printf 'git %s\\n' "$*" >>"$BOOTSTRAP_LOG"
case "$1" in
  --version) test -f "$CLT_READY" || exit 99 ;;
  clone)
    for argument do destination=$argument; done
    if [ "\${FAIL_CLONE:-0}" = 1 ]; then mkdir -p "$destination"; exit 42; fi
    "$REAL_GIT" clone --branch main "$FAKE_REMOTE" "$destination" || exit $?
    "$REAL_GIT" -C "$destination" remote set-url origin https://github.com/teddyhwang/dotfiles.git
    exit $? ;;
esac
exec "$REAL_GIT" "$@"`);
  await writeFile(path.join(remote, "setup.sh"), `#!/bin/sh
[ -t 0 ] || exit 99
printf 'setup\\n' >>"$BOOTSTRAP_LOG"
exit "$SETUP_STATUS"
`);
  git("init", "--initial-branch=main", remote);
  git("-C", remote, "add", "setup.sh");
  git("-C", remote, "-c", "user.name=Test", "-c", "user.email=test@example.invalid", "-c", "commit.gpgsign=false", "commit", "-m", "fixture");
  if (ready) await writeFile(clt, "ready");
  const run = (extra = {}) => spawnSync("python3", ["-c", python, script], {
    env: { ...env, ...extra }, encoding: "utf8", input: "", timeout: 15_000,
  });
  const calls = () => readFile(log, "utf8").catch(() => "");
  const checkout = path.join(home, "src/github.com/teddyhwang/dotfiles");
  return { root, home, remote, checkout, git, run, calls };
}

function ok(result) {
  assert.equal(result.status, 0, result.stderr || result.stdout);
}

test("bootstrap starts from an empty HOME, clones HTTPS and gives setup a TTY", async (t) => {
  const { checkout, run, calls } = await fixture(t);
  const result = run();
  ok(result);
  assert.match(await calls(), /git clone --branch main -- https:\/\/github\.com\/teddyhwang\/dotfiles\.git/);
  assert.match(await calls(), /setup/);
  assert.match(result.stdout, /exec \/bin\/zsh -l/);
  assert.equal(await readFile(path.join(checkout, "setup.sh"), "utf8").then(Boolean), true);
  assert.deepEqual((await readdir(path.dirname(checkout))).sort(), ["dotfiles"]);
});

test("bootstrap opens missing CLT installer before Git and continues after Return", async (t) => {
  const { run, calls } = await fixture(t, false);
  const result = run();
  ok(result);
  const log = await calls();
  assert.ok(log.indexOf("xcode-select --install") < log.indexOf("git --version"));
  assert.match(result.stdout, /press Return/);
});

for (const mode of ["fail", "pending"]) {
  test(`bootstrap stops when CLT installation is ${mode}`, async (t) => {
    const { run, calls } = await fixture(t, false);
    const result = run({ CLT_MODE: mode });
    assert.notEqual(result.status, 0);
    assert.match(result.stdout, /rerun bootstrap/);
    assert.doesNotMatch(await calls(), /git |setup/);
  });
}

test("reruns reuse an existing matching checkout without pulling or losing local changes", async (t) => {
  const { checkout, run, calls } = await fixture(t);
  ok(run());
  await writeFile(path.join(checkout, "local-work"), "keep me\n");
  ok(run());
  assert.equal(await readFile(path.join(checkout, "local-work"), "utf8"), "keep me\n");
  const log = await calls();
  assert.equal(log.split("\n").filter((line) => line.startsWith("git clone ")).length, 1);
  assert.doesNotMatch(log, /git .*pull|git .*reset/);
});

for (const kind of ["file", "directory", "wrong origin", "symlink", "escaping parent"]) {
  test(`bootstrap refuses an unsafe destination: ${kind}`, async (t) => {
    const { root, home, checkout, remote, git, run, calls } = await fixture(t);
    if (kind === "escaping parent") {
      await symlink(root, path.join(home, "src"));
    } else {
      await mkdir(path.dirname(checkout), { recursive: true });
      if (kind === "file") await writeFile(checkout, "keep me");
      if (kind === "directory") await mkdir(checkout);
      if (kind === "symlink") await symlink(remote, checkout);
      if (kind === "wrong origin") git("clone", remote, checkout);
    }
    assert.notEqual(run().status, 0);
    assert.doesNotMatch(await calls(), /git clone|setup/);
    assert.equal(await readFile(path.join(remote, "setup.sh"), "utf8").then(Boolean), true);
  });
}

test("failed clone cleans its staging area and a rerun succeeds", async (t) => {
  const { checkout, run } = await fixture(t);
  assert.equal(run({ FAIL_CLONE: "1" }).status, 42);
  await assert.rejects(readFile(path.join(checkout, "setup.sh")), { code: "ENOENT" });
  assert.deepEqual(await readdir(path.dirname(checkout)), []);
  ok(run());
});

test("setup failure is propagated and the clone is kept for retry", async (t) => {
  const { checkout, run } = await fixture(t);
  const result = run({ SETUP_STATUS: "23" });
  assert.equal(result.status, 23, result.stderr || result.stdout);
  assert.match(result.stdout, /Setup failed \(exit 23\)/);
  assert.match(result.stdout, /setup\.sh/);
  assert.ok(await readFile(path.join(checkout, "setup.sh")));
  ok(run());
});

for (const extra of [{ FAKE_UID: "0" }, { FAKE_OS: "Linux" }, { NO_TTY: "1" }]) {
  test(`bootstrap rejects unsupported execution: ${JSON.stringify(extra)}`, async (t) => {
    const { run, calls } = await fixture(t);
    const result = run(extra);
    assert.notEqual(result.status, 0);
    if (extra.NO_TTY) assert.match(result.stderr, /controlling terminal is required/);
    assert.equal(await calls(), "");
  });
}
