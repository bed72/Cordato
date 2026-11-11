const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { test } = require("node:test");
const { loadAudioFlow, compileAudioFlow, functionIds } = require("./support/audio_flow.js");

const requestId = "01234567-89ab-4cde-8fab-0123456789ab";
const token = "fixture.payload.signature";
const owner = "fixtureowner001";
const environment = {
    get: name => ({ AI_API_KEY: "fixture-only-key", AI_BASE_URL: "https://openrouter.ai/api/v1", POCKETBASE_URL: "https://pocketbase.example.test", AI_MODEL: "google/gemini-3.8-flash" })[name],
};

function message(release = () => {}) {
    return {
        req: {
            headers: { authorization: "Bearer " + token },
            body: { reference_date: "2026-11-10" },
            files: [{ fieldname: "file", mimetype: "audio/mp4", buffer: Buffer.from("\x00\x00\x00\x18ftypM4A fixture") }],
            cordatoAudio: { requestId, startedAt: Date.now(), release },
        },
        res: { _res: { destroyed: false } },
    };
}

function authenticationResponse(msg) {
    msg.statusCode = 200;
    msg.payload = JSON.stringify({ record: { id: owner, collectionName: "users", verified: true } });
}

test("export contém funções completas sem require, contexto global ou módulos externos", () => {
    const nodes = loadAudioFlow();
    for (const [name, id] of Object.entries(functionIds)) {
        const node = nodes.find(entry => entry.id === id);

        assert.equal(node.type, "function");
        assert.ok(node.func.includes("function " + name + "("));
        assert.ok(!/\brequire\s*\(|\bmodule\s*\.|\bprocess\s*\.|\bglobal\s*\./.test(node.func));
        assert.equal(node.initialize, "");
        assert.equal(node.finalize, "");
        assert.deepEqual(node.libs, []);
    }
});

test("pipeline do JSON funciona em sandbox sem implementação na imagem", () => {
    const functions = compileAudioFlow(loadAudioFlow(), vm.createContext({ Buffer, URL }));
    let released = 0;
    const msg = message(() => { released += 1; });
    const logs = [];

    const [authentication, rejected, uploadLogs] = functions.receive(msg, environment);
    logs.push(...uploadLogs);
    assert.equal(authentication, msg);
    assert.equal(rejected, null);
    assert.equal(msg.headers.Authorization, token);
    assert.equal(msg.requestTimeout, 10000);

    authenticationResponse(msg);
    const [interpretation, accepted, authenticationLogs] = functions.authenticated(msg, environment);
    logs.push(...authenticationLogs);
    assert.equal(interpretation, msg);
    assert.equal(accepted.statusCode, 202);
    assert.equal(accepted.payload.status, "processing");
    assert.equal(accepted.payload.request_id, requestId);
    assert.equal(msg.requestTimeout, 300000);
    assert.equal(msg.payload.reasoning_effort, "low");
    assert.equal(msg.url, "https://openrouter.ai/api/v1/chat/completions");
    assert.equal(msg.headers.Authorization, "Bearer fixture-only-key");
    assert.ok(!JSON.stringify(msg.payload).includes(token));
    assert.equal(msg.req, undefined);
    assert.equal(msg.res, undefined);
    assert.equal(released, 0);
    accepted.res._res.destroyed = true;

    msg.statusCode = 200;
    msg.payload = JSON.stringify({ choices: [{ index: 0, finish_reason: "stop", message: { role: "assistant", content: JSON.stringify({
        decision: "single", expense: { description: "Despesa fictícia", amount: 1250, category: "food", occurred_on: "2026-11-10" },
    }) } }] });
    const [persistence, interpretationReply, interpretationLogs] = functions.interpreted(msg);
    logs.push(...interpretationLogs);
    assert.equal(persistence, msg);
    assert.equal(interpretationReply, null);
    assert.equal(msg.payload.owner, owner);
    assert.equal(msg.payload.amount, 1250);
    assert.equal(msg.headers.Authorization, token);
    assert.ok(!JSON.stringify(msg).includes("fixture-only-key"));
    assert.equal(msg.headers["x-goog-api-key"], undefined);
    assert.ok(!JSON.stringify(msg).includes("fixture-only-key"));
    assert.equal(msg.requestTimeout, 10000);

    msg.statusCode = 200;
    msg.payload = JSON.stringify({ id: "fixtureexpense1", ...msg.audioExpense });
    const [next, persistenceReply, persistenceLogs] = functions.persisted(msg);
    logs.push(...persistenceLogs);
    assert.equal(next, null);
    assert.equal(persistenceReply, null);
    assert.equal(msg.payload, undefined);
    assert.equal(msg.audioToken, undefined);
    assert.equal(released, 1);

    const entries = [];
    for (const entry of logs) {
        assert.ok(functions.audit(entry, { log: text => entries.push(text) }));
    }
    assert.ok(entries.at(-1).includes("request.completed"));
    for (const sensitive of [token, "fixture-only-key", owner, "Despesa fictícia", "ftypM4A fixture"]) {
        assert.ok(!entries.join("\n").includes(sensitive));
    }
});

test("editar timeout somente no JSON altera o processamento sem rebuild", () => {
    const nodes = loadAudioFlow();
    const preparation = nodes.find(entry => entry.id === functionIds.authenticated);
    assert.ok(preparation.func.includes("msg.requestTimeout = 300000;"));
    preparation.func = preparation.func.replace("msg.requestTimeout = 300000;", "msg.requestTimeout = 42000;");
    const functions = compileAudioFlow(nodes, vm.createContext({ Buffer, URL }));
    const msg = message();

    functions.receive(msg, environment);
    authenticationResponse(msg);
    const [next, accepted] = functions.authenticated(msg, environment);

    assert.equal(next, msg);
    assert.equal(accepted.statusCode, 202);
    assert.equal(msg.requestTimeout, 42000);
});

test("Catch sem metadados de upload usa ID nativo sem crypto no sandbox", () => {
    const functions = compileAudioFlow(loadAudioFlow(), vm.createContext({ Buffer, URL }));
    const [next, rejected, logs] = functions.caught({});
    const entries = [];

    assert.equal(next, null);
    assert.equal(rejected.statusCode, 500);
    assert.match(rejected.payload.request_id, /^[a-f0-9]{16}$/);
    assert.ok(functions.audit(logs[0], { log: text => entries.push(text) }));
    assert.equal(entries.length, 1);
});

test("imagem inclui somente middleware de admissão, não lógica do flow", () => {
    const worker = path.join(__dirname, "..");
    const dockerfile = fs.readFileSync(path.join(worker, "Dockerfile"), "utf8");
    const settings = fs.readFileSync(path.join(worker, "settings.js"), "utf8");

    assert.ok(dockerfile.includes("middleware/audio_upload_gate.js"));
    assert.ok(!dockerfile.includes("flows/audio"));
    assert.ok(!settings.includes("cordatoAudio"));
    assert.ok(!fs.existsSync(path.join(worker, "flows/audio/audio.js")));
});
