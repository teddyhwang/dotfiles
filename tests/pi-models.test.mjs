import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const { providers } = JSON.parse(
  await readFile(new URL("../home/pi-agent/models.json", import.meta.url), "utf8"),
);

// https://developers.openai.com/api/docs/models/gpt-6.1-sol
// Reserve the full output allowance within the published combined context limit.
const solContextLimit = 1_050_000;
const solOutputLimit = 128_000;

for (const provider of ["openai", "openai-codex"]) {
  test(`${provider} GPT-6.1 Sol uses long context with the full output allowance`, () => {
    const model = providers[provider].modelOverrides["gpt-6.1-sol"];
    assert.equal(model.contextWindow, solContextLimit - solOutputLimit);
    assert.equal(model.maxTokens, solOutputLimit);
    assert.equal(model.contextWindow + model.maxTokens, solContextLimit);
  });
}

test("existing Codex long-context overrides remain unchanged", () => {
  for (const model of ["gpt-6-astra", "gpt-5.6-sol"]) {
    assert.deepEqual(providers["openai-codex"].modelOverrides[model], {
      contextWindow: 872000,
    });
  }
});
