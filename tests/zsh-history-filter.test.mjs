import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

const zshrc = await readFile("home/.zshrc", "utf8");
// Load only the history policy so these tests don't initialize personal plugins.
const policy = zshrc.split("\n").filter((line) => /^(ZSH_AUTOSUGGEST_HISTORY_IGNORE|HISTORY_IGNORE)=/.test(line));
assert.equal(policy.length, 2);

const generated = [
  "pi --extension /Users/teddyhwang/.pi/agent/git/github.com/boadij/pi-herdsman/dist/index.js --thinking high --session /tmp/example.jsonl",
  "pi --model sonnet --extension /home/example/src/pi-herdsman/dist/index.js --session /tmp/example.jsonl",
  "pi --extension '/home/example/path with spaces/pi-herdsman/dist/index.js'",
  "claude --session-id example --append-system-prompt-file /Users/teddyhwang/.claude/herdsman/prompts/example.md --model sonnet",
  "claude --resume example --append-system-prompt-file /home/example/.claude/herdsman/prompts/example.md",
  "cd /Users/example/.herdr/worktrees/repo/pi-worktree-fix/sub && { pi --model sonnet fix\\ it; _pi_herdr_worktree_close pi-worktree/fix main; }",
];
const ordinary = [
  "pi",
  "pi --continue",
  "pi --extension /tmp/other-extension/index.js",
  "pi install git:github.com/boadij/pi-herdsman",
  "claude",
  "claude --resume example",
  "claude --append-system-prompt-file /tmp/normal-prompt.md",
  "git status",
  "cd ~/src/repo && pi",
];

function run(script, args = [], interactive = false) {
  const result = spawnSync("zsh", [interactive ? "-dfi" : "-df", "-c", `${policy.join("\n")}\n${script}`, "zsh", ...args], {
    encoding: "utf8",
    timeout: 10_000,
  });
  assert.equal(result.status, 0, result.stderr || result.stdout);
  return result.stdout;
}

test("Zsh history and autosuggestion filters match only generated Herdsman launches", () => {
  const output = run(`
for command in "$@"; do
  if [[ $command == \${~ZSH_AUTOSUGGEST_HISTORY_IGNORE} ]]; then
    print -r -- ignored
  else
    print -r -- retained
  fi
done
[[ $HISTORY_IGNORE == "$ZSH_AUTOSUGGEST_HISTORY_IGNORE" ]]
`, [...generated, ...ordinary]);
  assert.deepEqual(output.trim().split("\n"), [
    ...generated.map(() => "ignored"),
    ...ordinary.map(() => "retained"),
  ]);
});

test("history suggestions can select ordinary commands past older generated launches", () => {
  const output = run(`
emulate -L zsh
setopt extended_glob
local -A entries=(1 'pi --continue' 2 "$1" 3 'claude --resume example' 4 "$2")
for prefix in pi claude; do
  local pattern="($prefix*)~($ZSH_AUTOSUGGEST_HISTORY_IGNORE)"
  print -r -- "\${entries[(r)$pattern]}"
done
`, [generated[0], generated[3]]);
  assert.equal(output, "pi --continue\nclaude --resume example\n");
});

test("saving native Zsh history excludes launches and preserves ordinary commands", async (t) => {
  const directory = await mkdtemp(path.join(tmpdir(), "dotfiles-zsh-history-"));
  t.after(() => rm(directory, { recursive: true, force: true }));
  const input = path.join(directory, "input");
  const output = path.join(directory, "output");
  await writeFile(input, [...generated, ...ordinary].join("\n") + "\n");
  run(`
HISTSIZE=100
SAVEHIST=100
HISTFILE=$2
fc -R "$1"
fc -W "$2"
`, [input, output], true);
  assert.deepEqual((await readFile(output, "utf8")).trim().split("\n"), ordinary);
});
