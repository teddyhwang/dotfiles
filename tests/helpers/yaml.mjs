import { execFileSync } from "node:child_process";

// Node has no YAML parser. yq (mikefarah, a check.sh requirement) converts
// the actual file, so tests never keep a second copy of the configuration.
export function readYaml(file) {
  return JSON.parse(execFileSync("yq", ["--output-format", "json", ".", file], { encoding: "utf8" }));
}
