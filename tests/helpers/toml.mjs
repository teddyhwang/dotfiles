import { execFileSync } from "node:child_process";

// Node has no TOML parser. taplo (a check.sh requirement) converts the actual
// file, so tests never keep a second copy of the configuration they verify.
export function readToml(file) {
  return JSON.parse(execFileSync("taplo", ["get", "--file-path", file, "--output-format", "json"], { encoding: "utf8" }));
}
