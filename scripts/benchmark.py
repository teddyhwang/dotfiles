#!/usr/bin/env python3
"""Measure warm startup without deleting caches or installing dependencies."""

import argparse
import json
import os
import shutil
import statistics
import subprocess
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runs", type=int, default=11)
    parser.add_argument("--json", action="store_true", help="emit machine-readable results")
    args = parser.parse_args()
    if not 3 <= args.runs <= 100:
        parser.error("--runs must be between 3 and 100")

    cases = {
        "bash": ["bash", "-lic", "exit"],
        "system-bash": ["/bin/bash", "-lic", "exit"],
        "zsh": ["zsh", "-lic", "exit"],
        "nvim": ["nvim", "--headless", "+qa"],
    }
    results = {}
    for name, command in cases.items():
        executable = shutil.which(command[0])
        if executable is None:
            continue
        samples = []
        for iteration in range(args.runs + 1):
            started = time.perf_counter()
            result = subprocess.run(
                command,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.PIPE,
                timeout=30,
                env={**os.environ, "TERM": "xterm-256color"},
            )
            elapsed = (time.perf_counter() - started) * 1000
            if result.returncode:
                raise SystemExit(f"{name} exited {result.returncode}: {result.stderr.decode(errors='replace')}")
            if iteration:  # Discard one warm-up run per application.
                samples.append(elapsed)
        results[name] = {
            "executable": executable,
            "median_ms": round(statistics.median(samples), 1),
            "min_ms": round(min(samples), 1),
            "max_ms": round(max(samples), 1),
            "samples_ms": [round(value, 1) for value in samples],
        }

    if args.json:
        print(json.dumps(results, indent=2))
    else:
        print("Warm startup + immediate exit, no TTY; not first-prompt or editor-ready latency.")
        print(f"{args.runs} samples after one warm-up per application; milliseconds:")
        for name, result in results.items():
            print(f"{name:14} median={result['median_ms']:7.1f}  range={result['min_ms']:.1f}–{result['max_ms']:.1f}")


if __name__ == "__main__":
    main()
