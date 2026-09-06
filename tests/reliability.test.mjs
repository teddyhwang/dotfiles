import assert from "node:assert/strict";
import { chmod, copyFile, mkdir, mkdtemp, readFile, readdir, readlink, rm, symlink, writeFile } from "node:fs/promises";
import { spawn, spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

const repo = process.cwd();

async function fixture(t) {
  const home = await mkdtemp(path.join(tmpdir(), "dotfiles-reliability-"));
  t.after(() => rm(home, { recursive: true, force: true }));
  await mkdir(path.join(home, "bin"));
  const env = { ...process.env, HOME: home, PATH: `${home}/bin:/usr/bin:/bin` };
  for (const key of ["XDG_CACHE_HOME", "XDG_DATA_HOME", "XDG_CONFIG_HOME", "ZDOTDIR", "BASH_ENV", "ENV", "NVIM", "FLOATERM", "TMUX"]) {
    delete env[key];
  }
  return { home, env };
}

async function executable(filename, contents) {
  await writeFile(filename, `#!/bin/sh\n${contents}\n`);
  await chmod(filename, 0o755);
}

function run(shell, script, env, interactive = false) {
  const args = shell === "zsh" ? ["-f"] : ["--noprofile", "--norc"];
  if (interactive) args.push("-i");
  args.push("-c", script);
  return spawnSync(shell, args, { env, encoding: "utf8", timeout: 15_000, input: "" });
}

function ok(result) {
  assert.equal(result.status, 0, result.stderr || result.stdout);
}

test("symlink helper rejects HOME, traversal, and escaping parents before writing", async (t) => {
  const { home, env } = await fixture(t);
  const outside = await mkdtemp(path.join(tmpdir(), "dotfiles-outside-"));
  t.after(() => rm(outside, { recursive: true, force: true }));
  await symlink(outside, path.join(home, "escape"));
  for (const target of [home, `${home}/../bad`, `${home}/./bad`, `${home}/escape/nested/bad`, `${home}/bad/`]) {
    const result = run("bash", `. "${repo}/scripts/utils.sh"; confirm() { return 0; }; validate_and_symlink "${repo}/README.md" "$TARGET"`, { ...env, TARGET: target });
    assert.notEqual(result.status, 0, target);
    assert.match(result.stdout, /Refusing/);
  }
  assert.deepEqual(await readdir(outside), []);
});

test("confirmed replacement preserves files and directories; reruns need no confirmation", async (t) => {
  const { home, env } = await fixture(t);
  const target = path.join(home, "config");
  await mkdir(target);
  await writeFile(path.join(target, "precious"), "keep me\n");
  const script = `. "${repo}/scripts/utils.sh"; confirm() { return 0; }; validate_and_symlink "${repo}/home/shared" "$HOME/config"`;
  ok(run("bash", script, env));
  assert.equal(await readlink(target), path.join(repo, "home/shared"));
  const backupRoot = path.join(home, ".local/state/dotfiles/backups");
  const backups = await readdir(backupRoot);
  assert.equal(backups.length, 1);
  assert.equal(await readFile(path.join(backupRoot, backups[0], "config/precious"), "utf8"), "keep me\n");
  ok(run("bash", script.replace("confirm() { return 0; }", "confirm() { exit 99; }"), env));
  assert.deepEqual(await readdir(backupRoot), backups);
});

for (const shell of ["bash", "zsh"]) {
  for (const [name, output, exitCode] of [
    ["failed", "export PARTIAL=1", 1],
    ["invalid", "if then", 0],
  ]) {
    test(`${shell} keeps its last good cache after a ${name} generator`, async (t) => {
      const { home, env } = await fixture(t);
      const cache = path.join(home, ".cache", `shared_init_cache.${shell}`);
      await mkdir(path.dirname(cache));
      await writeFile(cache, "export LAST_GOOD=1\n");
      await executable(path.join(home, "bin/gh"), `printf '%s\\n' '${output}'; exit ${exitCode}`);
      const result = run(shell, `. "${repo}/home/shared/init"; _shared_init_regen_cache "${cache}" ${shell}`, env);
      assert.notEqual(result.status, 0);
      assert.equal(await readFile(cache, "utf8"), "export LAST_GOOD=1\n");
      assert.deepEqual(await readdir(path.dirname(cache)), [`shared_init_cache.${shell}`]);
    });
  }

  test(`${shell} never sources invalid output on the first cache generation`, async (t) => {
    const { home, env } = await fixture(t);
    await executable(path.join(home, "bin/gh"), "printf 'touch \"$HOME/should-not-run\"\\nif then\\n'");
    const result = run(shell, `. "${repo}/home/shared/init"; test ! -f "$HOME/should-not-run"; test ! -f "$HOME/.cache/shared_init_cache.${shell}"`, env);
    ok(result);
    assert.match(result.stderr, /could not generate/);
  });

  test(`${shell} warm theme loading uses generated files without running tinty`, async (t) => {
    const { home, env } = await fixture(t);
    const data = path.join(home, "data/tinted-theming/tinty");
    await mkdir(data, { recursive: true });
    await writeFile(path.join(data, "theme.sh"), "export THEME_LOADED=yes\n");
    await executable(path.join(home, "bin/tinty"), 'touch "$HOME/tinty-was-called"; exit 1');
    const result = run(shell, `. "${repo}/home/shared/functions"; test "$THEME_LOADED" = yes; test ! -e "$HOME/tinty-was-called"`, { ...env, XDG_DATA_HOME: path.join(home, "data") }, true);
    ok(result);
  });

  test(`${shell} handles no generated themes and propagates tinty failures`, async (t) => {
    const { home, env } = await fixture(t);
    await executable(path.join(home, "bin/tinty"), "exit 7");
    const result = run(shell, `. "${repo}/home/shared/functions"; _tinty_load_shell_theme; test $? -eq 1 || exit 99; tinty_source_shell_theme apply broken`, env);
    assert.equal(result.status, 7, result.stderr);
    assert.doesNotMatch(result.stderr, /no matches found/);
  });
}

test("concurrent first shells publish one complete cache in XDG_CACHE_HOME", async (t) => {
  const { home, env } = await fixture(t);
  const cacheHome = path.join(home, "custom-cache");
  await executable(path.join(home, "bin/gh"), 'echo generation >>"$HOME/generations"; sleep 0.2; echo "export CACHE_COMPLETE=yes"');
  const script = `. "${repo}/home/shared/init"; test "$CACHE_COMPLETE" = yes`;
  const results = await Promise.all(Array.from({ length: 5 }, () => new Promise((resolve) => {
    const child = spawn("bash", ["--noprofile", "--norc", "-c", script], { env: { ...env, XDG_CACHE_HOME: cacheHome }, stdio: ["ignore", "pipe", "pipe"] });
    let stderr = "";
    child.stderr.on("data", (chunk) => { stderr += chunk; });
    child.on("error", (error) => resolve({ status: -1, stderr: String(error) }));
    child.on("close", (status) => resolve({ status, stderr }));
  })));
  for (const result of results) ok(result);
  assert.equal(await readFile(path.join(home, "generations"), "utf8"), "generation\n");
  assert.deepEqual(await readdir(cacheHome), ["shared_init_cache.bash"]);
});

test("an empty tmux autosave cannot overwrite a rich previous layout", async (t) => {
  const { home, env } = await fixture(t);
  const previous = "pane\tone\npane\ttwo\npane\tthree\npane\tfour\n";
  await writeFile(path.join(home, "previous"), previous);
  await writeFile(path.join(home, "new"), "session\tdefault\n");
  await symlink("previous", path.join(home, "last"));
  const result = spawnSync("bash", [path.join(repo, "home/config/tmux/resurrect-guard.sh"), path.join(home, "new")], { env, encoding: "utf8" });
  ok(result);
  assert.equal(await readFile(path.join(home, "new"), "utf8"), previous);
  assert.match(result.stderr, /vetoed trivial save \(0 panes\)/);
});

test("tmux setup checks all plugins using only its isolated socket", async (t) => {
  const { home, env } = await fixture(t);
  const tpm = path.join(home, ".config/tmux/plugins/tpm/bin");
  await mkdir(tpm, { recursive: true });
  // This old sentinel must not suppress checking for other missing plugins.
  await mkdir(path.join(home, ".config/tmux/plugins/base16-tmux-powerline"));
  await executable(path.join(home, "bin/tmux"), 'printf "%s\\n" "$*" >>"$HOME/tmux-calls"');
  await executable(path.join(tpm, "install_plugins"), 'echo checked >>"$HOME/plugin-checks"; tmux show-environment -g TMUX_PLUGIN_MANAGER_PATH');
  for (let i = 0; i < 2; i++) {
    ok(spawnSync("sh", [path.join(repo, "scripts/tmux.sh")], { env, encoding: "utf8" }));
  }
  assert.equal(await readFile(path.join(home, "plugin-checks"), "utf8"), "checked\nchecked\n");
  const calls = (await readFile(path.join(home, "tmux-calls"), "utf8")).trim().split("\n");
  for (const call of calls) assert.match(call, /^-S \/tmp\/dotfiles-tmux\.[^/]+\/server /);
  assert.ok(calls.some((call) => call.includes("show-environment")));
  assert.ok(calls.some((call) => call.includes("kill-server")));
  assert.ok(calls.every((call) => !call.includes("new-session")));
});

test("launch agent setup repairs unloaded jobs and is idempotent when loaded", async (t) => {
  const { home, env } = await fixture(t);
  const agents = path.join(home, "Library/LaunchAgents");
  await mkdir(agents, { recursive: true });
  await mkdir(path.join(home, "loaded"));
  await mkdir(path.join(home, ".local/bin"), { recursive: true });
  await executable(path.join(home, ".local/bin/herdr-tab-autoname"), "exit 0");
  for (const name of ["pbcopy", "pbpaste", "herdr-tab-autoname"]) {
    await copyFile(path.join(repo, "apps", `${name}.plist`), path.join(agents, `${name}.plist`));
  }
  await executable(path.join(home, "bin/launchctl"), `printf '%s\\n' "$*" >>"$HOME/launch-calls"
case "$1" in
  print) test -f "$HOME/loaded/\${2##*/}" ;;
  bootstrap) name=\${3##*/}; touch "$HOME/loaded/localhost.\${name%.plist}" ;;
  bootout) rm -f "$HOME/loaded/\${2##*/}" ;;
  *) exit 1 ;;
esac`);
  ok(spawnSync("sh", [path.join(repo, "scripts/services_mac.sh")], { env, encoding: "utf8" }));
  let calls = await readFile(path.join(home, "launch-calls"), "utf8");
  assert.equal(calls.split("\n").filter((line) => line.startsWith("bootstrap ")).length, 3);
  await writeFile(path.join(home, "launch-calls"), "");
  ok(spawnSync("sh", [path.join(repo, "scripts/services_mac.sh")], { env, encoding: "utf8" }));
  calls = await readFile(path.join(home, "launch-calls"), "utf8");
  assert.doesNotMatch(calls, /bootstrap|bootout/);
});

test("gwd preserves dirty worktrees instead of forcing deletion", async (t) => {
  const { home, env } = await fixture(t);
  const gitEnv = { ...env, GIT_CONFIG_GLOBAL: "/dev/null", GIT_CONFIG_NOSYSTEM: "1" };
  const primary = path.join(home, "primary");
  const secondary = path.join(home, "secondary");
  const git = (...args) => {
    const result = spawnSync("git", args, { env: gitEnv, encoding: "utf8" });
    ok(result);
    return result;
  };
  git("init", primary);
  git("-C", primary, "-c", "user.name=Test", "-c", "user.email=test@example.com", "-c", "commit.gpgsign=false", "commit", "--allow-empty", "-m", "initial");
  git("-C", primary, "worktree", "add", "-b", "feature", secondary);
  await writeFile(path.join(secondary, "untracked"), "do not delete\n");
  const result = run("bash", `. "${repo}/home/shared/functions"; cd "$HOME/secondary"; gwd <<<'y'`, gitEnv);
  assert.notEqual(result.status, 0);
  assert.equal(await readFile(path.join(secondary, "untracked"), "utf8"), "do not delete\n");
  git("-C", primary, "show-ref", "--verify", "refs/heads/feature");
});

test("tmux start builds a three-window session before attaching at base-index 1", async (t) => {
  const discovery = spawnSync("sh", ["-c", "command -v tmux"], { encoding: "utf8" });
  if (discovery.status !== 0) return t.skip("tmux is not installed");
  const realTmux = discovery.stdout.trim();
  const { home, env } = await fixture(t);
  const socketDir = await mkdtemp("/tmp/dotfiles-test-tmux-");
  const socket = path.join(socketDir, "server");
  t.after(async () => {
    spawnSync(realTmux, ["-S", socket, "kill-server"]);
    await rm(socketDir, { recursive: true, force: true });
  });
  ok(spawnSync(realTmux, ["-S", socket, "-f", "/dev/null", "start-server", ";", "set-option", "-g", "exit-empty", "off", ";", "set-option", "-g", "base-index", "1"], { encoding: "utf8" }));
  await executable(path.join(home, "bin/tmux"), `case "$1" in
  attach-session) echo attached >"$HOME/attached"; exit 0 ;;
esac
exec "$REAL_TMUX" -S "$TEST_SOCKET" "$@"`);
  ok(run("bash", `. "${repo}/home/shared/functions"; tmux start example`, { ...env, REAL_TMUX: realTmux, TEST_SOCKET: socket }));
  const windows = spawnSync(realTmux, ["-S", socket, "list-windows", "-t", "example", "-F", "#{window_index}:#{window_name}:#{window_active}"], { encoding: "utf8" });
  ok(windows);
  assert.equal(windows.stdout, "1:Terminal:1\n2:Editor:0\n3:Server:0\n");
  assert.equal(await readFile(path.join(home, "attached"), "utf8"), "attached\n");
});

test("fresh Homebrew caches are portable and not empty in nested shells", { skip: process.platform !== "darwin" }, async (t) => {
  const discovery = spawnSync("sh", ["-c", "command -v brew"], { encoding: "utf8" });
  if (discovery.status !== 0) return t.skip("Homebrew is not installed");
  const { home, env } = await fixture(t);
  const brewBin = path.dirname(discovery.stdout.trim());
  const nestedEnv = { ...env, PATH: `${brewBin}:${path.dirname(brewBin)}/sbin:${env.PATH}` };
  for (const shell of ["bash", "zsh"]) {
    const result = run(shell, `. "${repo}/home/shared/env"; test -n "$HOMEBREW_PREFIX"`, nestedEnv);
    ok(result);
    assert.doesNotMatch(result.stderr, /command not found|bad substitution/);
  }
  const cache = await readFile(path.join(home, ".cache/brew_shellenv.posix.sh"), "utf8");
  assert.match(cache, /export HOMEBREW_PREFIX=/);
  assert.doesNotMatch(cache, /fpath\[/);
  ok(spawnSync("sh", ["-n", path.join(home, ".cache/brew_shellenv.posix.sh")], { encoding: "utf8" }));
});

test("Neovim's frequent autoread events check one file and skip special buffers", (t) => {
  if (spawnSync("nvim", ["--version"]).status !== 0) return t.skip("Neovim is not installed");
  const lua = `
    package.loaded['util.indent-opacity'] = { apply = function() end, reset = function() end }
    package.loaded['util.sorbet-dim'] = { setup = function() end }
    dofile('${repo}/home/config/nvim/lua/config/autocmds.lua')
    local commands, original = {}, vim.cmd
    vim.cmd = function(cmd) commands[#commands + 1] = cmd end
    local file = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_exec_autocmds('CursorHold', { buffer = file, group = 'dotfiles_autoread' })
    assert(#commands == 1 and commands[1] == 'checktime ' .. file, vim.inspect(commands))
    local scratch = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_exec_autocmds('CursorHold', { buffer = scratch, group = 'dotfiles_autoread' })
    assert(#commands == 1, 'special buffer triggered checktime')
    assert(#vim.api.nvim_get_autocmds({ group = 'dotfiles_autoread', event = 'FocusGained' }) == 0)
    vim.cmd = original
  `;
  const result = spawnSync("nvim", ["--headless", "--noplugin", "-u", "NONE", "-i", "NONE", "-n", "-c", `lua local ok, err = pcall(function() ${lua} end); if not ok then print(err); vim.cmd('cquit 1') end`, "-c", "qa!"], { encoding: "utf8", timeout: 10_000 });
  ok(result);
});
