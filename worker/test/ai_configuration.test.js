const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { test } = require("node:test");

test("Compose encaminha AI_BASE_URL, AI_MODEL e AI_API_KEY sem credencial padrão", () => {
    const worker = path.join(__dirname, "..");
    const compose = fs.readFileSync(path.join(worker, "compose.yml"), "utf8");
    const example = fs.readFileSync(path.join(worker, ".env.example"), "utf8");

    assert.ok(compose.includes("AI_BASE_URL: ${AI_BASE_URL:-https://openrouter.ai/api/v1}"));
    assert.ok(compose.includes("AI_MODEL: ${AI_MODEL:-google/gemini-3.8-flash}"));
    assert.ok(compose.includes("AI_API_KEY: ${AI_API_KEY:-}"));
    assert.match(example, /^AI_BASE_URL=https:\/\/openrouter.ai\/api\/v1$/m);
    assert.match(example, /^AI_MODEL=google\/gemini-3.8-flash$/m);
    assert.match(example, /^AI_API_KEY=$/m);
    assert.ok(!compose.includes("GEMINI_"));
    assert.ok(!example.includes("GEMINI_"));
});
