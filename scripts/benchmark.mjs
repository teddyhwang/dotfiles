// Measure warm startup without deleting caches or installing dependencies.
//
// Usage: node scripts/benchmark.mjs [--runs N] [--json]

import { spawnSync } from "node:child_process";
import { accessSync, constants, statSync } from "node:fs";
import path from "node:path";

const USAGE = "usage: benchmark.mjs [-h] [--runs RUNS] [--json]";

function fail(message) {
  process.stderr.write(`${USAGE}\nbenchmark.mjs: error: ${message}\n`);
  process.exit(2);
}

function parseArguments(argv) {
  const options = { runs: 11, json: false };
  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (argument === "-h" || argument === "--help") {
      process.stdout.write(`${USAGE}\n\nMeasure warm startup without deleting caches or installing dependencies.\n\n` +
        "options:\n  -h, --help   show this help message and exit\n  --runs RUNS\n  --json       emit machine-readable results\n");
      process.exit(0);
    } else if (argument === "--json") {
      options.json = true;
    } else if (argument === "--runs" || argument.startsWith("--runs=")) {
      const value = argument === "--runs" ? argv[++index] : argument.slice("--runs=".length);
      if (value === undefined) fail("argument --runs: expected one argument");
      if (!/^[+-]?\d+$/.test(value.trim())) fail(`argument --runs: invalid int value: '${value}'`);
      options.runs = Number.parseInt(value, 10);
    } else {
      fail(`unrecognized arguments: ${argument}`);
    }
  }
  if (options.runs < 3 || options.runs > 100) fail("--runs must be between 3 and 100");
  return options;
}

function which(command) {
  const candidates = command.includes("/")
    ? [command]
    : (process.env.PATH ?? "").split(path.delimiter).map((directory) => path.join(directory || ".", command));
  for (const candidate of candidates) {
    try {
      accessSync(candidate, constants.X_OK);
      if (statSync(candidate).isFile()) return candidate;
    } catch {
      // Keep searching PATH.
    }
  }
  return null;
}

function median(values) {
  const sorted = [...values].sort((left, right) => left - right);
  const middle = Math.floor(sorted.length / 2);
  return sorted.length % 2 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2;
}

const round = (value) => Number(value.toFixed(1));

const args = parseArguments(process.argv.slice(2));
const cases = {
  bash: ["bash", "-lic", "exit"],
  "system-bash": ["/bin/bash", "-lic", "exit"],
  zsh: ["zsh", "-lic", "exit"],
  nvim: ["nvim", "--headless", "+qa"],
};
const results = {};
for (const [name, command] of Object.entries(cases)) {
  const executable = which(command[0]);
  if (executable === null) continue;
  const samples = [];
  for (let iteration = 0; iteration <= args.runs; iteration += 1) {
    const started = process.hrtime.bigint();
    const result = spawnSync(command[0], command.slice(1), {
      stdio: ["ignore", "ignore", "pipe"],
      timeout: 30_000,
      env: { ...process.env, TERM: "xterm-256color" },
    });
    const elapsed = Number(process.hrtime.bigint() - started) / 1e6;
    if (result.error) {
      process.stderr.write(`${name} failed: ${result.error.message}\n`);
      process.exit(1);
    }
    if (result.status !== 0) {
      const code = result.status ?? `on signal ${result.signal}`;
      process.stderr.write(`${name} exited ${code}: ${result.stderr.toString()}\n`);
      process.exit(1);
    }
    if (iteration) samples.push(elapsed); // Discard one warm-up run per application.
  }
  results[name] = {
    executable,
    median_ms: round(median(samples)),
    min_ms: round(Math.min(...samples)),
    max_ms: round(Math.max(...samples)),
    samples_ms: samples.map(round),
  };
}

if (args.json) {
  console.log(JSON.stringify(results, null, 2));
} else {
  console.log("Warm startup + immediate exit, no TTY; not first-prompt or editor-ready latency.");
  console.log(`${args.runs} samples after one warm-up per application; milliseconds:`);
  for (const [name, result] of Object.entries(results)) {
    console.log(`${name.padEnd(14)} median=${result.median_ms.toFixed(1).padStart(7)}  range=${result.min_ms.toFixed(1)}–${result.max_ms.toFixed(1)}`);
  }
}
