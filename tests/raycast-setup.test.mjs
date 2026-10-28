import assert from "node:assert/strict";
import { chmod, copyFile, mkdir, mkdtemp, readFile, readdir, realpath, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";

const repo = process.cwd();

async function sandbox(t) {
  const home = await realpath(await mkdtemp(path.join(tmpdir(), "raycast-setup-")));
  t.after(() => rm(home, { recursive: true, force: true }));
  const bin = path.join(home, "bin");
  await mkdir(bin);
  const executable = async (name, body) => {
    await writeFile(path.join(bin, name), `#!/bin/sh\n${body}\n`);
    await chmod(path.join(bin, name), 0o755);
  };
  await executable("uname", 'printf "%s\\n" "${MOCK_OS:-Darwin}"');
  await executable("open", 'printf "%s\\n" "$@" >>"$HOME/open.log"; exit "${OPEN_STATUS:-0}"');
  const archive = path.join(home, ".config/dotfiles/raycast.rayconfig");
  await mkdir(path.dirname(archive), { recursive: true });
  const env = { ...process.env, HOME: home, PATH: `${bin}:/usr/bin:/bin`, RAYCAST_CONFIG_FILE: "" };
  const helper = path.join(repo, "scripts/raycast.sh");
  // Exercise the interactive branch without depending on a host controlling TTY.
  // Only terminal detection is bypassed; the real default-no confirm reads stdin.
  const fixture = path.join(home, "interactive");
  await mkdir(fixture);
  const source = await readFile(helper, "utf8");
  assert.equal(source.split('[ ! -t 0 ]').length, 2);
  await writeFile(path.join(fixture, "raycast.sh"), source.replace('[ ! -t 0 ]', "false"));
  const utils = await readFile(path.join(repo, "scripts/utils.sh"), "utf8");
  await writeFile(path.join(fixture, "utils.sh"), utils.replace("</dev/tty", "</dev/null"));
  const run = (args = [], extra = {}, interactive = false) => spawnSync("sh", [
    interactive ? path.join(fixture, "raycast.sh") : helper, ...args,
  ], {
    cwd: home, env: { ...env, ...extra }, input: interactive ? `${extra.REPLY}\n` : "",
    encoding: "utf8", timeout: 10000,
  });
  return { home, bin, archive, env, run, executable };
}

async function noOpen(s) {
  await assert.rejects(readFile(path.join(s.home, "open.log")), { code: "ENOENT" });
}

test("missing default and noninteractive reruns preserve state and give instructions", async (t) => {
  const s = await sandbox(t);
  let result = s.run();
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /No usable private Raycast archive/);
  assert.match(result.stdout, /--import/);
  await writeFile(s.archive, "private archive content");
  for (let i = 0; i < 2; i++) {
    result = s.run();
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stdout, /Noninteractive setup/);
  }
  assert.equal(await readFile(s.archive, "utf8"), "private archive content");
  assert.deepEqual(await readdir(path.dirname(s.archive)), ["raycast.rayconfig"]);
  await noOpen(s);
});

for (const reply of ["", "n", "yes"]) {
  test(`interactive handoff requires default-no consent (reply=${JSON.stringify(reply)})`, async (t) => {
    const s = await sandbox(t);
    await writeFile(s.archive, "private archive content");
    const result = s.run([], { REPLY: reply }, true);
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stdout, /may replace settings/);
    if (reply === "yes") {
      assert.equal(await readFile(path.join(s.home, "open.log"), "utf8"), `-a\nRaycast\n${s.archive}\n`);
      assert.match(result.stdout, /not confirmed as imported/);
    } else await noOpen(s);
  });
}

test("explicit default, environment override and relative paths with spaces open without prompting", async (t) => {
  const s = await sandbox(t);
  await writeFile(s.archive, "secret sentinel");
  const relative = "-private archive.rayconfig";
  await writeFile(path.join(s.home, relative), "secret sentinel");
  for (const [args, extra, expected] of [
    [["--import"], {}, s.archive],
    [["--import"], { RAYCAST_CONFIG_FILE: relative }, path.join(s.home, relative)],
    [["--import", relative], { RAYCAST_CONFIG_FILE: "/missing" }, path.join(s.home, relative)],
  ]) {
    const result = s.run(args, extra);
    assert.equal(result.status, 0, result.stderr);
    assert.doesNotMatch(result.stdout, /\(y\/N\)|secret sentinel/);
    assert.match(result.stdout, /manual import, not confirmed as imported/);
    assert.ok((await readFile(path.join(s.home, "open.log"), "utf8")).endsWith(`-a\nRaycast\n${expected}\n`));
  }
});

test("invalid files and arguments fail explicitly without opening anything", async (t) => {
  const s = await sandbox(t);
  await writeFile(path.join(s.home, "empty.rayconfig"), "");
  await writeFile(path.join(s.home, "wrong.txt"), "content");
  await mkdir(path.join(s.home, "directory.rayconfig"));
  await writeFile(path.join(s.home, "unreadable.rayconfig"), "content");
  await chmod(path.join(s.home, "unreadable.rayconfig"), 0);
  const invalid = ["missing.rayconfig", "empty.rayconfig", "wrong.txt", "directory.rayconfig", ""];
  if (process.getuid?.() !== 0) invalid.push("unreadable.rayconfig");
  for (const file of invalid) {
    const result = s.run(["--import", file]);
    assert.notEqual(result.status, 0);
    assert.match(result.stdout, /readable, nonempty regular .rayconfig/);
  }
  for (const args of [["--import"], ["--unknown"], ["file.rayconfig"], ["--import", "a", "b"]]) {
    assert.notEqual(s.run(args).status, 0);
  }
  await noOpen(s);
});

test("open failures are reported and non-Darwin never invokes native tools", async (t) => {
  const s = await sandbox(t);
  await writeFile(s.archive, "archive");
  let result = s.run(["--import"], { OPEN_STATUS: "1" });
  assert.notEqual(result.status, 0);
  assert.match(result.stdout, /Could not open/);
  await rm(path.join(s.home, "open.log"));
  for (const args of [[], ["--import"]]) {
    result = s.run(args, { MOCK_OS: "Linux" });
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stdout, /macOS-only/);
  }
  await noOpen(s);
});

for (const os of ["Darwin", "Linux"]) {
  test(`setup runs Raycast via sh only after macOS packages and brew environment (${os})`, async (t) => {
    const s = await sandbox(t);
    const checkout = path.join(s.home, "checkout");
    const scripts = path.join(checkout, "scripts");
    await mkdir(scripts, { recursive: true });
    await copyFile(path.join(repo, "setup.sh"), path.join(checkout, "setup.sh"));
    await copyFile(path.join(repo, "scripts/utils.sh"), path.join(scripts, "utils.sh"));
    const setup = await readFile(path.join(repo, "setup.sh"), "utf8");
    const names = [...setup.matchAll(/scripts\/([a-z_]+\.sh)/g)].map((match) => match[1]);
    for (const name of new Set(names)) {
      if (name === "utils.sh") continue;
      const body = name === "raycast.sh"
        ? 'test "$BREW_READY" = yes || exit 98\nprintf "raycast.sh\\n" >>"$HOME/order"'
        : `printf '%s\\n' '${name}' >>"$HOME/order"`;
      await writeFile(path.join(scripts, name), `#!/bin/sh\n${body}\n`);
      // raycast.sh is deliberately nonexecutable: setup must call it via sh.
      if (name !== "raycast.sh") await chmod(path.join(scripts, name), 0o755);
    }
    await s.executable("id", "printf '1000\\n'");
    await s.executable("brew", 'printf "brew-env\\n" >>"$HOME/order"; printf "export BREW_READY=yes\\n"');
    const result = spawnSync("sh", [path.join(checkout, "setup.sh")], {
      env: { ...s.env, MOCK_OS: os, BREW_READY: "" }, input: "", encoding: "utf8", timeout: 10000,
    });
    assert.equal(result.status, 0, result.stderr || result.stdout);
    const order = (await readFile(path.join(s.home, "order"), "utf8")).trim().split("\n");
    if (os === "Darwin") {
      assert.ok(order.indexOf("packages_mac.sh") < order.indexOf("brew-env"));
      assert.ok(order.indexOf("brew-env") < order.indexOf("raycast.sh"));
      assert.ok(order.indexOf("raycast.sh") < order.indexOf("linker_mac.sh"));
      assert.equal(order.filter((name) => name === "raycast.sh").length, 1);
    } else assert.ok(!order.includes("raycast.sh"));
  });
}
