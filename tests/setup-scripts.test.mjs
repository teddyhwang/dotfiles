import assert from "node:assert/strict";
import { chmod, mkdir, mkdtemp, readFile, readlink, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import net from "node:net";
import test from "node:test";

const repo = process.cwd();

function run(command, args, options = {}) {
  return spawnSync(command, args, {
    cwd: repo,
    encoding: "utf8",
    ...options,
  });
}

test("linker works outside the repository and creates parent directories", async () => {
  const home = await mkdtemp(path.join(tmpdir(), "dotfiles-home-"));
  const cwd = await mkdtemp(path.join(tmpdir(), "dotfiles-cwd-"));
  try {
    const result = run("sh", [path.join(repo, "scripts/linker.sh")], {
      cwd,
      env: { ...process.env, HOME: home },
      input: "",
    });
    assert.equal(result.status, 0, result.stderr || result.stdout);
    assert.equal(await readlink(path.join(home, ".zshrc")), path.join(repo, "home/.zshrc"));
    assert.equal(await readlink(path.join(home, ".config/nvim")), path.join(repo, "home/config/nvim"));
    assert.equal(
      await readlink(path.join(home, ".pi/agent/models.json")),
      path.join(repo, "home/pi-agent/models.json"),
    );
  } finally {
    await Promise.all([rm(home, { recursive: true, force: true }), rm(cwd, { recursive: true, force: true })]);
  }
});

test("symlink helper rejects unsafe source and target paths", async () => {
  const home = await mkdtemp(path.join(tmpdir(), "dotfiles-missing-"));
  try {
    const missingScript = `. "${repo}/scripts/utils.sh"; validate_and_symlink "$HOME/missing" "$HOME/target"`;
    const missing = run("sh", ["-c", missingScript], { env: { ...process.env, HOME: home } });
    assert.notEqual(missing.status, 0);
    assert.match(missing.stdout, /Cannot symlink missing source/);

    const outsideScript = `. "${repo}/scripts/utils.sh"; validate_and_symlink "${repo}/README.md" "${tmpdir()}/outside-home"`;
    const outside = run("sh", ["-c", outsideScript], { env: { ...process.env, HOME: home } });
    assert.notEqual(outside.status, 0);
    assert.match(outside.stdout, /Refusing to manage a symlink outside HOME/);
  } finally {
    await rm(home, { recursive: true, force: true });
  }
});

test("macOS package setup reads the repository Brewfile without implicit upgrades", async () => {
  const home = await mkdtemp(path.join(tmpdir(), "dotfiles-macos-home-"));
  const bin = path.join(home, "bin");
  const log = path.join(home, "brew.log");
  try {
    await mkdir(bin, { recursive: true });
    const brew = path.join(bin, "brew");
    await writeFile(
      brew,
      `#!/bin/sh\ncase "$1" in\n  shellenv) exit 0 ;;\n  bundle) printf '%s\\n' "$*" >>"$BREW_LOG"; exit 0 ;;\n  --prefix) printf '%s\\n' "$HOME/no-fzf"; exit 0 ;;\nesac\n`,
    );
    for (const command of ["herdr", "launchctl"]) {
      const executable = path.join(bin, command);
      await writeFile(executable, "#!/bin/sh\nexit 0\n");
      await chmod(executable, 0o755);
    }
    await chmod(brew, 0o755);

    const result = run("sh", [path.join(repo, "scripts/packages_mac.sh")], {
      cwd: tmpdir(),
      env: {
        ...process.env,
        HOME: home,
        PATH: `${bin}:/usr/bin:/bin`,
        BREW_LOG: log,
      },
      input: "",
    });
    assert.equal(result.status, 0, result.stderr || result.stdout);
    const invocation = await readFile(log, "utf8");
    assert.ok(invocation.includes(`check --no-upgrade --file ${repo}/Brewfile`), invocation);
  } finally {
    await rm(home, { recursive: true, force: true });
  }
});

test("shared initialization cache is atomic and cleans interrupted generations", async () => {
  const home = await mkdtemp(path.join(tmpdir(), "dotfiles-init-cache-"));
  try {
    const cache = path.join(home, ".cache");
    await mkdir(cache, { recursive: true });
    const stale = path.join(cache, "shared_init_cache.bash.tmp.interrupted");
    await writeFile(stale, "partial");
    const script = `touch -t 202001010000 "${stale}"; mkdir -p "$HOME/.shared"; cp "${repo}/home/shared/init" "$HOME/.shared/init"; . "$HOME/.shared/init"; test -f "$HOME/.cache/shared_init_cache.bash"; test ! -e "${stale}"; test ! -e "$HOME/.cache/shared_init_cache.bash.lock"`;
    const result = run("bash", ["--noprofile", "--norc", "-c", script], {
      env: { ...process.env, HOME: home, PATH: "/usr/bin:/bin" },
    });
    assert.equal(result.status, 0, result.stderr || result.stdout);
  } finally {
    await rm(home, { recursive: true, force: true });
  }
});

test("shared environment does not grow PATH when sourced repeatedly", async () => {
  const home = await mkdtemp(path.join(tmpdir(), "dotfiles-env-"));
  try {
    const localBin = path.join(home, ".local/bin");
    const script = `mkdir -p "${localBin}"; . "${repo}/home/shared/env"; . "${repo}/home/shared/env"; printf '%s\\n' "$PATH"`;
    const result = run("bash", ["--noprofile", "--norc", "-c", script], {
      env: { ...process.env, HOME: home, PATH: `/usr/bin:/bin:${localBin}` },
    });
    assert.equal(result.status, 0, result.stderr);
    const entries = result.stdout.trim().split(":");
    assert.equal(entries.filter((entry) => entry === localBin).length, 1);
  } finally {
    await rm(home, { recursive: true, force: true });
  }
});

test("worktree helpers fail safely", () => {
  const functions = path.join(repo, "home/shared/functions");
  const missingName = run("bash", ["--noprofile", "--norc", "-c", `. "${functions}"; gwn; printf 'alive\\n'`]);
  assert.equal(missingName.status, 0, missingName.stderr);
  assert.match(missingName.stdout, /alive/);
  assert.match(missingName.stderr, /Usage: gwn/);

  const primary = run("bash", ["--noprofile", "--norc", "-c", `. "${functions}"; gwd`]);
  assert.notEqual(primary.status, 0);
  assert.match(primary.stderr, /refusing to remove the primary worktree/);
});

test("Herdr layout helper times out instead of hanging", async () => {
  const directory = await mkdtemp(path.join(tmpdir(), "herdr-socket-"));
  const socketPath = path.join(directory, "herdr.sock");
  const server = net.createServer(() => {});

  try {
    await new Promise((resolve, reject) => {
      server.once("error", reject);
      server.listen(socketPath, resolve);
    });

    const started = Date.now();
    const result = run("python3", [path.join(repo, "home/local/bin/herdr-even-layout")], {
      env: {
        ...process.env,
        HERDR_SOCKET_PATH: socketPath,
        HERDR_SOCKET_TIMEOUT: "0.05",
      },
      timeout: 1_000,
    });
    assert.notEqual(result.status, 0);
    assert.ok(Date.now() - started < 1_000);
    assert.match(result.stderr, /timed out/);
  } finally {
    server.close();
    await rm(directory, { recursive: true, force: true });
  }
});

test("portable configs avoid hard-coded home paths and pin Neovim plugins", async () => {
  for (const filename of ["home/.bash_profile", "home/.bashrc", "home/.zshrc"]) {
    const contents = await readFile(path.join(repo, filename), "utf8");
    assert.doesNotMatch(contents, /\/Users\/teddyhwang/);
  }

  const lock = JSON.parse(await readFile(path.join(repo, "home/config/nvim/lazy-lock.json"), "utf8"));
  assert.match(lock["herdr-splits.nvim"].commit, /^[0-9a-f]{40}$/);

  const gitconfig = await readFile(path.join(repo, "home/.shared.gitconfig"), "utf8");
  assert.match(gitconfig, /default = simple/);
  assert.doesNotMatch(gitconfig, /default = matching/);
});
