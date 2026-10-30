import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { fileURLToPath } from "node:url";
import test from "node:test";

const configPath = fileURLToPath(new URL("../home/config/rex/init.lua", import.meta.url));
const config = readFileSync(configPath, "utf8");
const linker = readFileSync(new URL("../scripts/linker.sh", import.meta.url), "utf8");

test("linker links Rex's init.lua by itself, not the whole directory", () => {
  assert.match(linker, /^\s+[^\n]*\| rex\)$/m);
});

test("key handlers do not queue client actions", () => {
  // Rex rejects rex.client.queue inside a rex.bind function at key time
  // ("a key handler cannot queue client actions"), which `rex config check`
  // does not catch. Handlers must call server methods with rex.call instead.
  assert.doesNotMatch(config, /rex\.client\.queue/);
});

test("Rex accepts the configuration", {
  skip: spawnSync("sh", ["-c", "command -v rex"]).status !== 0 && "rex is not installed",
}, () => {
  const env = { ...process.env, HOME: tmpdir(), REX_CONFIG: configPath };
  for (const name of ["REX_SERVER", "REX_SESSION", "REX_BLOCK", "REX_CLIENT"]) delete env[name];
  const result = spawnSync("rex", ["--autostart=false", "config", "check"], {
    encoding: "utf8",
    env,
    timeout: 30_000,
  });
  assert.equal(result.status, 0, result.error?.message || `${result.stdout}${result.stderr}`);
  assert.doesNotMatch(`${result.stdout}${result.stderr}`, /\b(error|warning)\b/i);
  assert.match(result.stdout, /^modes: 1$/m);
});
