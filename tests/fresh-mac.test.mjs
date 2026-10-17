import assert from "node:assert/strict";
import { chmod, mkdir, mkdtemp, readFile, readlink, rm, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";

const repo = process.cwd();
const run = (command, args, options = {}) => spawnSync(command, args, {
  cwd: repo, encoding: "utf8", input: "", timeout: 15_000, ...options,
});

async function sandbox(t) {
  const home = await mkdtemp(path.join(tmpdir(), "dotfiles-fresh-mac-"));
  t.after(() => rm(home, { recursive: true, force: true }));
  return home;
}

async function executable(filename, contents) {
  await writeFile(filename, `#!/bin/sh\n${contents}\n`);
  await chmod(filename, 0o755);
}

test("fresh directory creation followed by linking requires no replacement confirmations", async (t) => {
  const home = await sandbox(t);
  const env = { ...process.env, HOME: home };
  const directories = run("sh", ["scripts/directories.sh"], { env });
  assert.equal(directories.status, 0, directories.stderr || directories.stdout);
  for (let pass = 0; pass < 2; pass++) {
    const result = run("sh", ["scripts/linker.sh"], { env });
    assert.equal(result.status, 0, result.stderr || result.stdout);
    assert.doesNotMatch(result.stdout, /Do you want to replace|exists and differs/);
    for (const name of ["ghostty", "btop"]) {
      assert.equal(await readlink(path.join(home, ".config", name)), path.join(repo, "home/config", name));
    }
  }
  const source = await readFile(path.join(repo, "scripts/directories.sh"), "utf8");
  assert.doesNotMatch(source, /sudo|\/usr\/local\/bin/);
});

for (const scenario of ["missing CLT", "broken Git", "working Git"]) {
  test(`dependency preflight detects ${scenario} before installation`, async (t) => {
    const home = await sandbox(t);
    const bin = path.join(home, "bin");
    await mkdir(bin);
    for (const name of ["dirname", "curl", "readlink"]) {
      await symlink(`/usr/bin/${name}`, path.join(bin, name));
    }
    const log = path.join(home, "git-invoked");
    await executable(path.join(bin, "uname"), "printf 'Darwin\\n'");
    await executable(path.join(bin, "xcode-select"), scenario === "missing CLT" ? "exit 1" : "exit 0");
    await executable(path.join(bin, "git"), `printf '%s\\n' "$*" >> "$GIT_LOG"\nexit ${scenario === "broken Git" ? 1 : 0}`);
    const result = run("/bin/sh", [path.join(repo, "scripts/verify_dependencies.sh")], {
      env: { ...process.env, HOME: home, PATH: bin, GIT_LOG: log },
    });
    if (scenario === "working Git") {
      assert.equal(result.status, 0, result.stderr || result.stdout);
    } else {
      assert.notEqual(result.status, 0);
      assert.match(result.stdout, /Command Line Tools/);
    }
    if (scenario === "missing CLT") {
      assert.match(result.stdout, /xcode-select --install/);
      await assert.rejects(readFile(log), { code: "ENOENT" });
    } else {
      assert.equal(await readFile(log, "utf8"), "--version\n");
    }
  });
}

for (const signing of [undefined, "true", "false"]) {
  test(`Git setup needs no prior identity or signing key (signing=${signing ?? "unset"})`, async (t) => {
    const home = await sandbox(t);
    const bin = path.join(home, "bin");
    await mkdir(bin);
    await executable(path.join(bin, "bat"), "printf 'base16-256\\n'");
    await symlink(path.join(repo, "home/.shared.gitconfig"), path.join(home, ".shared.gitconfig"));
    const env = {
      ...process.env, HOME: home, XDG_CONFIG_HOME: path.join(home, ".config"),
      GIT_CONFIG_GLOBAL: path.join(home, ".gitconfig"), GIT_CONFIG_NOSYSTEM: "1",
      PATH: `${bin}:${process.env.PATH}`,
    };
    const git = (...args) => run("git", args, { env });
    if (signing !== undefined) {
      assert.equal(git("config", "--global", "commit.gpgsign", signing).status, 0);
    }
    for (let pass = 0; pass < 2; pass++) {
      const result = run("sh", ["scripts/git_bat.sh"], { env });
      assert.equal(result.status, 0, result.stderr || result.stdout);
    }
    assert.equal(git("config", "--global", "--get-all", "include.path").stdout.trim(), path.join(home, ".shared.gitconfig"));
    const preference = git("config", "--global", "--get", "commit.gpgsign");
    assert.equal(preference.stdout.trim(), signing ?? "");
    assert.equal(preference.status, signing === undefined ? 1 : 0);
    // Setup must not invent a personal identity or an authentication secret.
    assert.notEqual(git("config", "--global", "--get", "user.email").status, 0);
    if (signing === undefined) {
      const checkout = path.join(home, "checkout");
      assert.equal(git("init", checkout).status, 0);
      const commit = git("-C", checkout, "-c", "user.name=Bootstrap Test", "-c", "user.email=test@example.invalid",
        "commit", "--allow-empty", "-m", "Clean-home commit without a signing key");
      assert.equal(commit.status, 0, commit.stderr || commit.stdout);
    }
  });
}

for (const shell of ["bash", "zsh"]) {
  test(`${shell}: fzf does not send tmux commands from an ordinary Terminal shell`, async (t) => {
    const home = await sandbox(t);
    for (const tmux of ["", "/tmp/example-tmux,123,0"]) {
      const result = run(shell, ["-c", `tmux() { :; }; . "${repo}/home/shared/env"; printf '%s\\n' "$FZF_CTRL_T_OPTS"`], {
        env: { ...process.env, HOME: home, TMUX: tmux },
      });
      assert.equal(result.status, 0, result.stderr);
      if (tmux) assert.match(result.stdout, /tmux send-keys/);
      else assert.doesNotMatch(result.stdout, /tmux send-keys/);
    }
  });
}

test("Ctrl-F is bound only when the fzf widget exists", async () => {
  const source = await readFile(path.join(repo, "home/.zshrc"), "utf8");
  const binding = source.split("\n").find((line) => line.includes("bindkey '^f'"));
  assert.ok(binding);
  for (const installed of [false, true]) {
    const result = run("zsh", ["-f", "-c", `${installed ? "fzf-cd-widget() { :; }; zle -N fzf-cd-widget;" : ""}
      ${binding}
      bindkey '^f'`]);
    assert.equal(result.status, 0, result.stderr);
    if (installed) assert.match(result.stdout, /fzf-cd-widget/);
    else assert.doesNotMatch(result.stdout, /fzf-cd-widget/);
  }
});
