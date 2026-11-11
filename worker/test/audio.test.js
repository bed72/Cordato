const assert = require("node:assert/strict");
const { EventEmitter } = require("node:events");
const fs = require("node:fs");
const path = require("node:path");
const { describe, test } = require("node:test");
const audio = require("../flows/audio/audio.js");

const token = "fixture.payload.signature";
const owner = "fixtureowner001";
const geminiKey = "fixture-only-gemini-key";
const requestId = "01234567-89ab-4cde-8fab-0123456789ab";
const environment = {
    get: name => ({ GEMINI_API_KEY: geminiKey, POCKETBASE_URL: "https://pocketbase.example.test", GEMINI_MODEL: "gemini-3.8-flash" })[name],
};

function message() {
    return {
        req: {
            headers: { authorization: "Bearer " + token },
            body: { reference_date: "2026-11-10" },
            files: [{ fieldname: "file", mimetype: "audio/mp4", buffer: Buffer.from("\x00\x00\x00\x18ftypM4A fixture") }],
            cordatoAudio: { requestId, startedAt: Date.now() },
        },
        res: { _res: { destroyed: false } },
    };
}

function authenticatedMessage() {
    const msg = message();
    audio.receive(msg, environment);
    msg.statusCode = 200;
    msg.payload = JSON.stringify({ token: "discarded-refreshed-token", record: { id: owner, collectionName: "users", verified: true } });
    audio.authenticated(msg, environment);
    return msg;
}

function extraction(overrides = {}) {
    return { decision: "single", expense: { description: "Despesa fictícia", amount: 1250, category: "food", occurred_on: "2026-11-09", ...overrides } };
}

function geminiResponse(msg, content) {
    msg.statusCode = 200;
    msg.payload = JSON.stringify({ status: "completed", steps: [{ type: "model_output", content: [{ type: "text", text: JSON.stringify(content) }] }] });
}

function pendingExpense() {
    const msg = authenticatedMessage();
    geminiResponse(msg, extraction());
    audio.interpreted(msg);
    return msg;
}

describe("recebimento e autenticação", () => {
    test("valida o upload e prepara autenticação sem transmitir áudio ao PocketBase", () => {
        const msg = message();
        const [next, rejected, logs] = audio.receive(msg, environment);

        assert.equal(next, msg);
        assert.equal(rejected, null);
        assert.equal(msg.url, "https://pocketbase.example.test/api/collections/users/auth-refresh");
        assert.deepEqual(msg.payload, {});
        assert.equal(msg.headers.Authorization, token);
        assert.equal(msg.requestTimeout, 10000);
        assert.equal(msg.followRedirects, false);
        assert.deepEqual(logs.map(entry => entry.payload.event), ["upload.accepted", "authentication.started"]);
    });

    for (const scenario of [
        { name: "arquivo ausente", change: msg => { msg.req.files = []; }, status: 400 },
        { name: "proprietário enviado pelo cliente", change: msg => { msg.req.body.owner = owner; }, status: 400 },
        { name: "tipo incorreto", change: msg => { msg.req.files[0].mimetype = "audio/mpeg"; }, status: 415 },
        { name: "assinatura de container inválida", change: msg => { msg.req.files[0].buffer = Buffer.from("invalid-audio-fixture"); }, status: 415 },
        { name: "arquivo grande", change: msg => { msg.req.files[0].buffer = Buffer.alloc(2 * 1024 * 1024 + 1); }, status: 413 },
        { name: "data civil impossível", change: msg => { msg.req.body.reference_date = "2026-02-30"; }, status: 400 },
        { name: "data repetida no multipart", change: msg => { msg.req.body.reference_date = ["2026-11-10", "2026-11-11"]; }, status: 400 },
        { name: "token ausente", change: msg => { delete msg.req.headers.authorization; }, status: 401 },
    ]) {
        test(`recusa ${scenario.name} sem iniciar request`, () => {
            const msg = message();
            scenario.change(msg);

            const [next, rejected] = audio.receive(msg, environment);

            assert.equal(next, null);
            assert.equal(rejected.statusCode, scenario.status);
            assert.equal(rejected.audioToken, undefined);
            assert.deepEqual(rejected.req.files, []);
        });
    }

    test("recusa configuração ausente sem revelar dados", () => {
        const [next, rejected] = audio.receive(message(), { get: () => undefined });

        assert.equal(next, null);
        assert.equal(rejected.statusCode, 503);
        assert.equal(rejected.payload.error.code, "unavailable");
    });

    for (const address of ["http://example.test", "https://user:secret@example.test", "https://example.test?token=fixture"]) {
        test(`recusa URL insegura: ${address}`, () => {
            const [next, rejected] = audio.receive(message(), { get: name => name === "POCKETBASE_URL" ? address : environment.get(name) });

            assert.equal(next, null);
            assert.equal(rejected.statusCode, 503);
        });
    }

    for (const status of [401, 403, 429, 500]) {
        test(`não chama Gemini quando autenticação retorna ${status}`, () => {
            const msg = message();
            audio.receive(msg, environment);
            msg.statusCode = status;
            msg.payload = "remote-sensitive-message";

            const [next, rejected] = audio.authenticated(msg, environment);

            assert.equal(next, null);
            assert.equal(rejected.statusCode, status === 401 || status === 403 ? 401 : 503);
            assert.ok(!JSON.stringify(rejected.payload).includes("remote-sensitive-message"));
        });
    }

    test("recusa record de outra coleção", () => {
        const msg = message();
        audio.receive(msg, environment);
        msg.statusCode = 200;
        msg.payload = JSON.stringify({ record: { id: owner, collectionName: "_superusers", verified: true } });

        const [next, rejected] = audio.authenticated(msg, environment);

        assert.equal(next, null);
        assert.equal(rejected.statusCode, 502);
    });

    test("não aceita sessão não verificada nem inicia interpretação", () => {
        const msg = message();
        audio.receive(msg, environment);
        msg.statusCode = 200;
        msg.payload = JSON.stringify({ record: { id: owner, collectionName: "users", verified: false } });

        const [next, rejected, logs] = audio.authenticated(msg, environment);

        assert.equal(next, null);
        assert.equal(rejected.statusCode, 502);
        assert.equal(msg.audio.accepted, undefined);
        assert.equal(msg.audioFile, undefined);
        assert.ok(!logs.some(entry => entry.payload.event === "request.accepted"));
    });
});

describe("Gemini e validação financeira", () => {
    test("envia áudio inline sem token do usuário, sem ferramentas e sem armazenamento da interação", () => {
        const msg = authenticatedMessage();

        assert.equal(msg.url, "https://generativelanguage.googleapis.com/v1beta/interactions");
        assert.equal(msg.headers["x-goog-api-key"], geminiKey);
        assert.equal(msg.headers.Authorization, undefined);
        assert.equal(msg.payload.store, false);
        assert.equal(msg.payload.tools, undefined);
        assert.equal(msg.payload.input[0].mime_type, "audio/m4a");
        assert.ok(!JSON.stringify(msg.payload).includes(token));
        assert.ok(!JSON.stringify(msg.payload).includes(owner));
        assert.equal(msg.req, undefined);
        assert.equal(msg.res, undefined);
        assert.equal(msg.audioFile, undefined);
        assert.equal(msg.requestTimeout, 45000);
    });

    test("monta somente campos aprovados e usa proprietário autenticado", () => {
        const msg = pendingExpense();

        assert.deepEqual(msg.payload, {
            owner, description: "Despesa fictícia", amount: 1250, category: "food", occurred_on: "2026-11-09 00:00:00.000Z",
        });
        assert.equal(msg.url, "https://pocketbase.example.test/api/collections/expenses/records");
        assert.equal(msg.headers.Authorization, token);
        assert.equal(msg.headers["x-goog-api-key"], undefined);
        assert.equal(msg.followRedirects, false);
    });

    for (const scenario of [
        { name: "centavos fracionários", fields: { amount: 12.5 } },
        { name: "valor textual", fields: { amount: "1250" } },
        { name: "zero", fields: { amount: 0 } },
        { name: "valor negativo", fields: { amount: -1 } },
        { name: "inteiro inseguro", fields: { amount: Number.MAX_SAFE_INTEGER + 1 } },
        { name: "categoria desconhecida", fields: { category: "invalid" } },
        { name: "data impossível", fields: { occurred_on: "2026-02-30" } },
        { name: "descrição vazia", fields: { description: "  " } },
        { name: "descrição extensa", fields: { description: "a".repeat(257) } },
        { name: "caractere de controle", fields: { description: "fixture\nfixture" } },
        { name: "owner vindo do modelo", fields: { owner: "anotherowner001" } },
    ]) {
        test(`não persiste ${scenario.name}`, () => {
            const msg = authenticatedMessage();
            geminiResponse(msg, extraction(scenario.fields));

            const [next, replied, logs] = audio.interpreted(msg);

            assert.equal(next, null);
            assert.equal(replied, null);
            assert.equal(logs.at(-1).payload.code, "invalid_interpretation");
        });
    }

    for (const decision of ["multiple_expenses", "unclear_audio", "not_expense"]) {
        test(`não salva interpretação ${decision}`, () => {
            const msg = authenticatedMessage();
            geminiResponse(msg, { decision, expense: null });

            const [next, replied, logs] = audio.interpreted(msg);

            assert.equal(next, null);
            assert.equal(replied, null);
            assert.equal(logs.at(-1).payload.status, 422);
            assert.equal(logs.at(-1).payload.code, decision);
        });
    }

    for (const payload of ["not-json", JSON.stringify({ status: "failed", steps: [] }), JSON.stringify({ status: "completed", steps: [] })]) {
        test(`recusa resposta inválida: ${payload}`, () => {
            const msg = authenticatedMessage();
            msg.statusCode = 200;
            msg.payload = payload;

            const [next, replied, logs] = audio.interpreted(msg);

            assert.equal(next, null);
            assert.equal(replied, null);
            assert.equal(logs.at(-1).payload.status, 502);
        });
    }
});

describe("persistência, cancelamento e logs", () => {
    test("conclui cadastro sem segunda resposta e limpa credenciais transitórias", () => {
        const msg = pendingExpense();
        msg.statusCode = 200;
        msg.payload = JSON.stringify({ id: "fixtureexpense1", ...msg.audioExpense });

        const [next, completed, logs] = audio.persisted(msg);

        assert.equal(next, null);
        assert.equal(completed, null);
        assert.equal(msg.payload, undefined);
        assert.equal(msg.audioToken, undefined);
        assert.equal(msg.audioConfiguration, undefined);
        assert.equal(msg.headers, undefined);
        assert.equal(logs.at(-1).payload.event, "request.completed");
    });

    test("resposta inválida após POST é cadastro incerto, nunca sucesso ou retry", () => {
        const msg = pendingExpense();
        msg.statusCode = 200;
        msg.payload = "{}";

        const [next, replied, logs] = audio.persisted(msg);

        assert.equal(next, null);
        assert.equal(replied, null);
        assert.equal(logs.at(-1).payload.status, 502);
        assert.equal(logs.at(-1).payload.code, "persistence_unknown");
    });

    test("timeout de persistência não repete o POST nem revela erro remoto", () => {
        const msg = pendingExpense();
        msg.error = { message: token + geminiKey };

        const [next, replied, logs] = audio.caught(msg);

        assert.equal(next, null);
        assert.equal(replied, null);
        assert.equal(logs.at(-1).payload.code, "persistence_unknown");
        assert.equal(msg.error, undefined);
        assert.ok(!JSON.stringify(logs).includes(token));
        assert.ok(!JSON.stringify(logs).includes(geminiKey));
    });

    test("não chama próximo serviço após desconexão do cliente", () => {
        const msg = message();
        audio.receive(msg, environment);
        msg.res._res.destroyed = true;

        const [next, replied, logs] = audio.authenticated(msg, environment);

        assert.equal(next, null);
        assert.equal(replied, null);
        assert.equal(logs[0].payload.event, "request.aborted");
        assert.equal(msg.audioToken, undefined);
    });

    test("responde 202 após autenticação sem expor dados e continua sem conexão HTTP", () => {
        const msg = message();
        audio.receive(msg, environment);
        msg.statusCode = 200;
        msg.payload = JSON.stringify({ record: { id: owner, collectionName: "users", verified: true } });

        const [next, accepted, logs] = audio.authenticated(msg, environment);

        assert.equal(next, msg);
        assert.equal(accepted.statusCode, 202);
        assert.deepEqual(accepted.payload, { request_id: requestId, status: "processing" });
        assert.deepEqual(Object.keys(accepted).sort(), ["headers", "payload", "req", "res", "statusCode"]);
        assert.deepEqual(accepted.req.files, []);
        assert.deepEqual(accepted.req.body, {});
        assert.equal(msg.req, undefined);
        assert.equal(msg.res, undefined);
        assert.equal(msg.audio.accepted, true);
        assert.ok(logs.some(entry => entry.payload.event === "request.accepted"));

        accepted.res._res.destroyed = true;
        geminiResponse(msg, extraction());
        const [persistence, replied] = audio.interpreted(msg);

        assert.equal(persistence, msg);
        assert.equal(replied, null);
        assert.equal(msg.audio.stage, "persistence");
    });

    test("logger remove todo conteúdo fora da allowlist", () => {
        const entries = [];
        const safeMessage = audio.audit({ payload: {
            request_id: requestId, event: "request.failed", stage: "persistence", elapsed_ms: 10,
            code: "persistence_unknown", token, geminiKey, description: "private-fixture", amount: 1250,
            headers: { Authorization: token }, audio: Buffer.from("private-audio"),
        } }, { log: entry => entries.push(entry) });

        assert.deepEqual(safeMessage.payload, {
            request_id: requestId, event: "request.failed", elapsed_ms: 10, stage: "persistence", code: "persistence_unknown",
        });
        assert.equal(entries.length, 1);
        assert.ok(!entries[0].includes(token));
        assert.ok(!entries[0].includes(geminiKey));
        assert.ok(!entries[0].includes("private-fixture"));
    });
});

describe("admissão antes de carregar multipart", () => {
    function admission(t, headers = {}) {
        t.mock.method(console, "info", () => {});
        const req = { headers: {
            authorization: "Bearer " + token,
            "content-type": "multipart/form-data; boundary=fixture",
            "content-length": "1000",
            ...headers,
        } };
        const res = new EventEmitter();
        res.setHeader = () => {};
        res.status = status => { res.statusCode = status; return res; };
        res.json = payload => { res.payload = payload; };
        t.after(() => req.cordatoAudio.release?.());
        let admitted = false;
        audio.requestGate(req, res, () => { admitted = true; });
        return { req, res, admitted };
    }

    for (const scenario of [
        { name: "token ausente", headers: { authorization: undefined }, status: 401 },
        { name: "tipo incompatível", headers: { "content-type": "application/json" }, status: 415 },
        { name: "Content-Length ausente", headers: { "content-length": undefined }, status: 411 },
        { name: "corpo excessivo", headers: { "content-length": "9999999" }, status: 413 },
    ]) {
        test(`bloqueia ${scenario.name}`, t => {
            const { res, admitted } = admission(t, scenario.headers);

            assert.equal(admitted, false);
            assert.equal(res.statusCode, scenario.status);
            assert.ok(!JSON.stringify(res.payload).includes(token));
        });
    }

    test("limita quatro requests e não libera processamento ativo só porque o cliente desconectou", t => {
        const requests = Array.from({ length: 4 }, () => admission(t));
        assert.ok(requests.every(request => request.admitted));
        requests[0].req.cordatoAudio.processing = true;
        requests[0].res.emit("finish");
        requests[0].res.emit("close");

        const blocked = admission(t);

        assert.equal(blocked.admitted, false);
        assert.equal(blocked.res.statusCode, 429);
        requests[0].req.cordatoAudio.release();
        assert.equal(admission(t).admitted, true);
    });

    for (const outcome of ["success", "interpretation_failure", "persistence_failure"]) {
        test(`mantém vaga após 202 e libera uma vez ao terminar: ${outcome}`, t => {
            const request = admission(t);
            const msg = message();
            msg.req.cordatoAudio = request.req.cordatoAudio;
            audio.receive(msg, environment);
            msg.statusCode = 200;
            msg.payload = JSON.stringify({ record: { id: owner, collectionName: "users", verified: true } });
            audio.authenticated(msg, environment);
            request.res.emit("finish");
            const others = Array.from({ length: 3 }, () => admission(t));
            assert.ok(others.every(entry => entry.admitted));
            assert.equal(admission(t).admitted, false);

            if (outcome === "interpretation_failure") {
                audio.caught(msg);
            } else {
                geminiResponse(msg, extraction());
                audio.interpreted(msg);
                if (outcome === "success") {
                    msg.statusCode = 200;
                    msg.payload = JSON.stringify({ id: "fixtureexpense1", ...msg.audioExpense });
                    audio.persisted(msg);
                } else {
                    audio.caught(msg);
                }
            }

            assert.equal(admission(t).admitted, true);
            request.req.cordatoAudio.release();
            assert.equal(admission(t).admitted, false);
        });
    }
});

test("export completo usa nós nativos, saídas válidas e catch sem resposta duplicada", () => {
    const nodes = JSON.parse(fs.readFileSync(path.join(__dirname, "../flows/audio/flows.json"), "utf8"));
    const ids = new Set(nodes.map(node => node.id));
    assert.equal(ids.size, nodes.length);
    for (const node of nodes) {
        assert.ok(["tab", "http in", "http response", "http request", "function", "catch", "debug"].includes(node.type));
        for (const target of (node.wires || []).flat()) {
            assert.ok(ids.has(target));
        }
        if (node.type === "http request") {
            assert.equal(node.senderr, true);
            assert.equal(node.method, "POST");
        }
        if (node.type === "debug") {
            assert.equal(node.complete, "payload");
        }
    }
    const authentication = nodes.find(node => node.func?.includes(".authenticated("));
    const interpretation = nodes.find(node => node.type === "http request" && node.name.startsWith("Gemini:"));
    const response = nodes.find(node => node.type === "http response");
    assert.deepEqual(authentication.wires[0], [interpretation.id]);
    assert.deepEqual(authentication.wires[1], [response.id]);
});
