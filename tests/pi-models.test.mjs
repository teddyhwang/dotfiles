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

// Pi turns on strict tool calling for Claude models. It stops agents from
// calling tools they do not have (boadij/pi-herdsman#395). Do not turn it off
// for the anthropic provider or a model. Herdsman v0.20.0 (#239) fixed the
// HTTP 400 grammar-limit error that once made us turn it off.
test("anthropic keeps Pi's default strict tool calling", () => {
  const configs = [providers.anthropic, ...Object.values(providers.anthropic?.modelOverrides ?? {})];
  for (const config of configs) {
    assert.notEqual(config?.compat?.supportsStrictTools, false);
  }
});

test("existing Codex long-context overrides remain unchanged", () => {
  for (const model of ["gpt-6-astra", "gpt-5.6-sol"]) {
    assert.deepEqual(providers["openai-codex"].modelOverrides[model], {
      contextWindow: 872000,
    });
  }
});
