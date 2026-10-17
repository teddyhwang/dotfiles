import assert from "node:assert/strict";
import { cp, mkdir, mkdtemp, readFile, readdir, readlink, realpath, rm, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";

const repo = process.cwd();

async function fixture(t, shell) {
  const root = await mkdtemp(path.join(tmpdir(), "dotfiles-shell-installers-"));
  t.after(() => rm(root, { recursive: true, force: true }));
  const home = path.join(root, "home");
  const bin = path.join(root, "bin");
  const checkout = path.join(root, "checkout");
  for (const directory of [home, bin, path.join(checkout, "scripts"), path.join(checkout, "home/completions")]) {
    await mkdir(directory, { recursive: true });
  }
  for (const file of ["utils.sh", `${shell}.sh`]) {
    await cp(path.join(repo, "scripts", file), path.join(checkout, "scripts", file));
  }
  const completion = path.join(checkout, "home/completions/_example");
  await writeFile(completion, "# completion\n");
  const log = path.join(root, "commands.log");
  await writeFile(log, "");
  await writeFile(path.join(bin, "git"), `#!/bin/sh
printf 'git\\n' >>"$COMMAND_LOG"
for destination do :; done
mkdir -p "$destination"
printf 'clone data\\n' >"$destination/source"
[ "$FAIL_GIT" != 1 ] || exit 1
if [ "$MISSING_ENTRY" != 1 ]; then
  printf '# zinit\\n' >"$destination/zinit.zsh"
fi
`, { mode: 0o755 });
  await writeFile(path.join(bin, "make"), `#!/bin/sh
printf 'make\\n' >>"$COMMAND_LOG"
for argument do
  case "$argument" in PREFIX=*) prefix=\${argument#PREFIX=} ;; esac
done
case "$prefix" in "$HOME"/.local/share/.dotfiles-blesh.*/prefix) ;; *) exit 90 ;; esac
mkdir -p "$prefix/share/blesh"
if [ "$MISSING_ENTRY" != 1 ]; then
  printf '# ble\\n' >"$prefix/share/blesh/ble.sh"
fi
printf 'support\\n' >"$prefix/share/blesh/support"
[ "$FAIL_MAKE" != 1 ] || exit 1
`, { mode: 0o755 });
  const target = path.join(home, shell === "zsh" ? ".local/share/zinit/zinit.git" : ".local/share/blesh");
  const entry = shell === "zsh" ? "zinit.zsh" : "ble.sh";
  const run = (extra = {}, input = "") => spawnSync("/bin/sh", [path.join(checkout, "scripts", `${shell}.sh`)], {
    cwd: tmpdir(),
    encoding: "utf8",
    timeout: 10_000,
    input,
    env: { ...process.env, HOME: home, XDG_DATA_HOME: path.join(home, ".local/share"), PATH: `${bin}:/usr/bin:/bin`, COMMAND_LOG: log, FAIL_GIT: "0", FAIL_MAKE: "0", MISSING_ENTRY: "0", ...extra },
  });
  return { home, target, entry, run, log, completion };
}

function success(result) {
  assert.equal(result.status, 0, result.error?.message || result.stderr || result.stdout);
}

for (const shell of ["zsh", "bash"]) {
  test(`${shell}: fresh install publishes entry and rerun skips installer`, async (t) => {
    const f = await fixture(t, shell);
    success(f.run());
    assert.match(await readFile(path.join(f.target, f.entry), "utf8"), /^#/);
    const before = await readFile(f.log, "utf8");
    success(f.run());
    assert.equal(await readFile(f.log, "utf8"), before);
    assert.deepEqual((await readdir(path.dirname(f.target))).filter((name) => name.startsWith(".dotfiles-")), []);
  });

  test(`${shell}: incomplete installation is backed up, not discarded`, async (t) => {
    const f = await fixture(t, shell);
    await mkdir(path.join(f.target, f.entry), { recursive: true }); // A directory is not an entry file.
    await writeFile(path.join(f.target, "keep"), "original");
    success(f.run());
    const backups = path.join(f.home, ".local/state/dotfiles/backups");
    const [backup] = await readdir(backups);
    assert.equal(await readFile(path.join(backups, backup, path.basename(f.target), "keep"), "utf8"), "original");
    assert.match(await readFile(path.join(f.target, f.entry), "utf8"), /^#/);
  });

  for (const failure of shell === "zsh" ? ["FAIL_GIT", "MISSING_ENTRY"] : ["FAIL_GIT", "FAIL_MAKE", "MISSING_ENTRY"]) {
    test(`${shell}: ${failure} leaves incomplete original intact and rerun repairs`, async (t) => {
      const f = await fixture(t, shell);
      await mkdir(f.target, { recursive: true });
      await writeFile(path.join(f.target, "keep"), "original");
      const failed = f.run({ [failure]: "1" });
      assert.notEqual(failed.status, 0);
      assert.equal(await readFile(path.join(f.target, "keep"), "utf8"), "original");
      assert.deepEqual(await readdir(f.target), ["keep"]);
      assert.deepEqual((await readdir(path.dirname(f.target))).filter((name) => name.startsWith(".dotfiles-")), []);
      success(f.run());
      assert.match(await readFile(path.join(f.target, f.entry), "utf8"), /^#/);
    });
  }

  test(`${shell}: parent symlink escape is rejected before installer runs`, async (t) => {
    const f = await fixture(t, shell);
    await symlink(path.dirname(f.home), path.join(f.home, ".local"));
    assert.notEqual(f.run().status, 0);
    assert.equal(await readFile(f.log, "utf8"), "");
  });

  test(`${shell}: unsafe backup parent preserves incomplete install`, async (t) => {
    const f = await fixture(t, shell);
    await mkdir(f.target, { recursive: true });
    await writeFile(path.join(f.target, "keep"), "original");
    await symlink(path.dirname(f.home), path.join(f.home, ".local/state"));
    assert.notEqual(f.run().status, 0);
    assert.equal(await readFile(path.join(f.target, "keep"), "utf8"), "original");
  });
}

test("zsh: completion replacements require consent and preserve originals", async (t) => {
  const f = await fixture(t, "zsh");
  const destination = path.join(f.home, ".zsh/completions/_example");
  await mkdir(path.dirname(destination), { recursive: true });
  await writeFile(destination, "original");
  success(f.run({}, "n\n"));
  assert.equal(await readFile(destination, "utf8"), "original");
  success(f.run({}, "y\n"));
  assert.equal(await readlink(destination), await realpath(f.completion));
  const backups = path.join(f.home, ".local/state/dotfiles/backups");
  const [backup] = await readdir(backups);
  assert.equal(await readFile(path.join(backups, backup, "_example"), "utf8"), "original");
});

test("zsh: completion parent escape cannot overwrite external files", async (t) => {
  const f = await fixture(t, "zsh");
  await symlink(path.dirname(f.home), path.join(f.home, ".zsh"));
  const result = f.run();
  assert.notEqual(result.status, 0);
  assert.match(result.stdout, /parent escapes HOME/);
});
