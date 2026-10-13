import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmod, mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

const zshenv = await readFile("home/.zshenv", "utf8");
const systemPath = "/usr/bin:/bin";

async function fixture(t, architectures) {
  const home = await mkdtemp(path.join(tmpdir(), "dotfiles-zshenv-"));
  t.after(() => rm(home, { recursive: true, force: true }));
  const prefixes = {
    arm: path.join(home, "opt/homebrew"),
    intel: path.join(home, "usr/local"),
  };
  for (const architecture of architectures) {
    const bin = path.join(prefixes[architecture], "bin");
    await mkdir(bin, { recursive: true });
    for (const [name, body] of [
      ["brew", "echo 'brew must not run at shell startup' >&2; exit 1"],
      ["mosh-server", "echo mosh-ready"],
    ]) {
      const filename = path.join(bin, name);
      await writeFile(filename, `#!/bin/sh\n${body}\n`);
      await chmod(filename, 0o755);
    }
  }
  const source = zshenv
    .replaceAll("/opt/homebrew", prefixes.arm)
    .replaceAll("/usr/local", prefixes.intel);
  await writeFile(path.join(home, ".zshenv"), source);
  return { home, prefixes };
}

function run(home, script, inheritedPath = systemPath) {
  const result = spawnSync("zsh", ["-c", script], {
    env: { HOME: home, ZDOTDIR: home, PATH: inheritedPath },
    encoding: "utf8",
    timeout: 10_000,
  });
  assert.equal(result.status, 0, result.stderr || result.stdout);
  assert.equal(result.stderr, "");
  return result.stdout;
}

for (const [label, architectures, chosen] of [
  ["Apple Silicon", ["arm"], "arm"],
  ["Intel", ["intel"], "intel"],
  ["Apple Silicon when both prefixes exist", ["arm", "intel"], "arm"],
]) {
  test(`noninteractive Zsh finds mosh-server on ${label}`, async (t) => {
    const { home, prefixes } = await fixture(t, architectures);
    assert.equal(run(home, "mosh-server"), "mosh-ready\n");
    assert.equal(
      run(home, 'print -r -- "$PATH"'),
      `${systemPath}:${prefixes[chosen]}/bin:${prefixes[chosen]}/sbin\n`,
    );
    assert.equal(run(home, ":"), "");
  });
}

test("noninteractive Zsh preserves PATH without Homebrew", async (t) => {
  const { home } = await fixture(t, []);
  assert.equal(run(home, 'print -r -- "$PATH"'), `${systemPath}\n`);
  assert.equal(run(home, ":"), "");
});

test("Homebrew paths preserve inherited precedence and do not accumulate", async (t) => {
  const { home, prefixes } = await fixture(t, ["arm"]);
  const bin = `${prefixes.arm}/bin`;
  const sbin = `${prefixes.arm}/sbin`;
  const inherited = `${home}/virtualenv/bin:${bin}:${systemPath}:${sbin}`;
  assert.equal(run(home, 'source "$HOME/.zshenv"; print -r -- "$PATH"', inherited), `${inherited}\n`);
  assert.equal(
    run(home, 'source "$HOME/.zshenv"; source "$HOME/.zshenv"; print -r -- "$PATH"'),
    `${systemPath}:${bin}:${sbin}\n`,
  );
});
