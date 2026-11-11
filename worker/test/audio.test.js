const assert = require("node:assert/strict");
const { EventEmitter } = require("node:events");
const fs = require("node:fs");
const path = require("node:path");
const { describe, test } = require("node:test");
const { compileAudioFlow } = require("./support/audio_flow.js");
const requestGate = require("../middleware/audio_upload_gate.js");
const audio = { requestGate, ...compileAudioFlow() };

const token = "fixture.payload.signature";
const owner = "fixtureowner001";
const aiKey = "fixture-only-ai-key";
const requestId = "01234567-89ab-4cde-8fab-0123456789ab";
const environment = {
    get: name => ({ AI_API_KEY: aiKey, AI_BASE_URL: "https://openrouter.ai/api/v1", POCKETBASE_URL: "https://pocketbase.example.test", AI_MODEL: "google/gemini-3.8-flash" })[name],
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

function authenticatedMessage(env = environment) {
    const msg = message();
    audio.receive(msg, env);
    msg.statusCode = 200;
    msg.payload = JSON.stringify({ token: "discarded-refreshed-token", record: { id: owner, collectionName: "users", verified: true } });
    audio.authenticated(msg, env);
    return msg;
}

function extraction(overrides = {}) {
    return { decision: "single", expense: { description: "Despesa fictícia", amount: 1250, category: "food", occurred_on: "2026-11-09", ...overrides } };
}

function configuredEnvironment(values) {
    return { get: name => Object.hasOwn(values, name) ? values[name] : environment.get(name) };
}

function aiResponse(msg, content) {
    msg.statusCode = 200;
    msg.payload = JSON.stringify({ choices: [{ index: 0, finish_reason: "stop", message: { role: "assistant", content: JSON.stringify(content) } }] });
}

function pendingExpense() {
    const msg = authenticatedMessage();
    aiResponse(msg, extraction());
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
        test(`não chama IA quando autenticação retorna ${status}`, () => {
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

describe("configuração genérica da IA", () => {
    test("usa base e modelo padrão com chave configurada", () => {
        const msg = authenticatedMessage(configuredEnvironment({ AI_BASE_URL: undefined, AI_MODEL: undefined }));

        assert.equal(msg.url, "https://openrouter.ai/api/v1/chat/completions");
        assert.equal(msg.payload.model, "google/gemini-3.8-flash");
        assert.equal(msg.headers.Authorization, "Bearer " + aiKey);
    });

    test("base e modelo são configuráveis sem enviar parâmetros específicos a outros hosts", () => {
        const msg = authenticatedMessage(configuredEnvironment({
            AI_BASE_URL: "https://ai.example.test/custom/v1/",
            AI_MODEL: "vendor/fixture-model:variant",
        }));

        assert.equal(msg.url, "https://ai.example.test/custom/v1/chat/completions");
        assert.equal(msg.payload.model, "vendor/fixture-model:variant");
        assert.equal(msg.headers.Authorization, "Bearer " + aiKey);
        assert.equal(msg.payload.provider, undefined);
        assert.equal(msg.followRedirects, false);
    });

    test("host semelhante não recebe parâmetros exclusivos do OpenRouter", () => {
        const msg = authenticatedMessage(configuredEnvironment({ AI_BASE_URL: "https://openrouter.ai.example.test/api/v1" }));

        assert.equal(msg.payload.provider, undefined);
    });

    for (const [name, value] of [
        ["AI_BASE_URL", "http://ai.example.test/v1"],
        ["AI_BASE_URL", "https://user:private@ai.example.test/v1"],
        ["AI_BASE_URL", "https://ai.example.test/v1?key=private"],
        ["AI_BASE_URL", "https://ai.example.test/v1#fragment"],
        ["AI_BASE_URL", "https://ai.example.test/v1\n"],
        ["AI_BASE_URL", "not-a-url"],
        ["AI_BASE_URL", 7],
        ["AI_MODEL", "invalid model"],
        ["AI_MODEL", "https://ai.example.test/model"],
        ["AI_MODEL", "vendor/model\n"],
        ["AI_MODEL", 7],
        ["AI_API_KEY", undefined],
        ["AI_API_KEY", ""],
        ["AI_API_KEY", " "],
        ["AI_API_KEY", "private\nheader"],
        ["AI_API_KEY", 7],
    ]) {
        test(`recusa configuração inválida antes de autenticar: ${name} ${JSON.stringify(value)}`, () => {
            const [next, rejected, logs] = audio.receive(message(), configuredEnvironment({ [name]: value }));

            assert.equal(next, null);
            assert.equal(rejected.statusCode, 503);
            assert.equal(rejected.payload.error.code, "unavailable");
            assert.equal(rejected.audioConfiguration, undefined);
            assert.ok(!JSON.stringify(logs).includes("private"));
        });
    }

    test("não reutiliza credenciais GEMINI legadas como chave genérica", () => {
        const [next, rejected] = audio.receive(message(), {
            get: name => ({ GEMINI_API_KEY: "legacy-fixture-key", GEMINI_MODEL: "gemini-3.8-flash" })[name],
        });

        assert.equal(next, null);
        assert.equal(rejected.statusCode, 503);
    });
});

describe("Chat Completions e validação financeira", () => {
    test("envia áudio ao OpenRouter sem JWT e exige schema/privacidade sem fallback", () => {
        const msg = authenticatedMessage();

        assert.equal(msg.url, "https://openrouter.ai/api/v1/chat/completions");
        assert.equal(msg.headers.Authorization, "Bearer " + aiKey);
        assert.equal(msg.headers["x-goog-api-key"], undefined);
        assert.equal(msg.headers["Api-Revision"], undefined);
        assert.equal(msg.payload.stream, false);
        assert.equal(msg.payload.tools, undefined);
        assert.equal(msg.payload.messages[0].role, "system");
        assert.equal(msg.payload.messages[1].role, "user");
        assert.equal(msg.payload.messages[1].content[0].type, "input_audio");
        assert.equal(msg.payload.messages[1].content[0].input_audio.format, "m4a");
        assert.deepEqual(Buffer.from(msg.payload.messages[1].content[0].input_audio.data, "base64"), message().req.files[0].buffer);
        assert.deepEqual(msg.payload.provider, { require_parameters: true, data_collection: "deny", allow_fallbacks: false });
        assert.equal(msg.payload.response_format.type, "json_schema");
        assert.equal(msg.payload.response_format.json_schema.strict, true);
        assert.equal(msg.payload.response_format.json_schema.name, "expense_extraction");
        assert.deepEqual(msg.payload.response_format.json_schema.schema.required, ["decision", "expense"]);
        assert.equal(msg.payload.response_format.json_schema.schema.properties.expense.properties.amount.maximum, Number.MAX_SAFE_INTEGER);
        assert.ok(msg.payload.messages[0].content.includes("2026-11-10"));
        assert.ok(!JSON.stringify(msg.payload).includes(token));
        assert.ok(!JSON.stringify(msg.payload).includes(owner));
        assert.equal(msg.req, undefined);
        assert.equal(msg.res, undefined);
        assert.equal(msg.audioFile, undefined);
        assert.equal(msg.requestTimeout, 300000);
    });

    test("mantém modelo configurado e reasoning low compatível com OpenRouter", () => {
        const msg = authenticatedMessage();

        assert.equal(msg.payload.model, "google/gemini-3.8-flash");
        assert.equal(msg.payload.reasoning_effort, "low");
        assert.equal(msg.payload.max_tokens, 1024);
        assert.equal(msg.payload.generation_config, undefined);
    });

    test("orienta descrição com inicial maiúscula sem aplicar title case a marcas", () => {
        const msg = authenticatedMessage();
        const instructions = msg.payload.messages[0].content;

        assert.ok(instructions.includes("Escreva description com a primeira letra em maiúscula"));
        assert.ok(instructions.includes("Preserve a grafia de marcas, siglas e nomes próprios"));
        assert.ok(instructions.includes("não use maiúscula em todas as palavras"));
        assert.ok(instructions.includes("créditos no OpenRouter → Créditos no OpenRouter"));
    });

    test("preserva descrição da IA com inicial maiúscula e marca na escrita", () => {
        const msg = authenticatedMessage();
        aiResponse(msg, extraction({ description: "Créditos no OpenRouter" }));

        const [next, replied] = audio.interpreted(msg);

        assert.equal(next, msg);
        assert.equal(replied, null);
        assert.equal(msg.payload.description, "Créditos no OpenRouter");
    });

    test("monta somente campos aprovados e usa proprietário autenticado", () => {
        const msg = pendingExpense();

        assert.deepEqual(msg.payload, {
            owner, description: "Despesa fictícia", amount: 1250, category: "food", occurred_on: "2026-11-09 00:00:00.000Z",
        });
        assert.equal(msg.url, "https://pocketbase.example.test/api/collections/expenses/records");
        assert.equal(msg.headers.Authorization, token);
        assert.equal(msg.headers["x-goog-api-key"], undefined);
        assert.ok(!JSON.stringify(msg).includes(aiKey));
        assert.equal(msg.followRedirects, false);
    });

    for (const scenario of [
        { name: "saída truncada", change: completion => { completion.choices[0].finish_reason = "length"; } },
        { name: "filtro de conteúdo", change: completion => { completion.choices[0].finish_reason = "content_filter"; } },
        { name: "tool call", change: completion => { completion.choices[0].message.tool_calls = [{ function: { name: "private-tool" } }]; } },
        { name: "function call legado", change: completion => { completion.choices[0].message.function_call = { name: "private-tool" }; } },
        { name: "recusa", change: completion => { completion.choices[0].message.refusal = "private-refusal"; } },
        { name: "papel inesperado", change: completion => { completion.choices[0].message.role = "user"; } },
        { name: "conteúdo ausente", change: completion => { delete completion.choices[0].message.content; } },
        { name: "conteúdo nulo", change: completion => { completion.choices[0].message.content = null; } },
        { name: "conteúdo em partes", change: completion => { completion.choices[0].message.content = [{ type: "text", text: JSON.stringify(extraction()) }]; } },
        { name: "conteúdo não JSON", change: completion => { completion.choices[0].message.content = "private-invalid-json"; } },
        { name: "múltiplas escolhas", change: completion => { completion.choices.push(completion.choices[0]); } },
        { name: "lista de escolhas vazia", change: completion => { completion.choices = []; } },
        { name: "sem escolhas", change: completion => { delete completion.choices; } },
    ]) {
        test(`não cadastra resposta incompleta/inválida: ${scenario.name}`, () => {
            const msg = authenticatedMessage();
            aiResponse(msg, extraction());
            const completion = JSON.parse(msg.payload);
            scenario.change(completion);
            msg.payload = JSON.stringify(completion);

            const [next, replied, logs] = audio.interpreted(msg);

            assert.equal(next, null);
            assert.equal(replied, null);
            assert.equal(logs.at(-1).payload.code, "invalid_interpretation");
            assert.ok(!JSON.stringify(logs).includes("private"));
            assert.equal(msg.audioExpense, undefined);
            assert.equal(msg.audioToken, undefined);
        });
    }

    test("erro OpenRouter em HTTP 200 não vira cadastro e usa código local", () => {
        const msg = authenticatedMessage();
        msg.statusCode = 200;
        msg.payload = JSON.stringify({ error: { code: 503, message: "private-remote-error", metadata: { raw: aiKey } } });

        const [next, replied, logs] = audio.interpreted(msg);

        assert.equal(next, null);
        assert.equal(replied, null);
        assert.equal(logs.at(-1).payload.diagnostic, "ai_upstream_unavailable");
        assert.equal(msg.audioExpense, undefined);
        assert.ok(!JSON.stringify(logs).includes(aiKey));
        assert.ok(!JSON.stringify(logs).includes("private"));
    });

    test("aceita ausência explícita de recusa e tool calls em resposta completa", () => {
        const msg = authenticatedMessage();
        aiResponse(msg, extraction());
        const completion = JSON.parse(msg.payload);
        completion.choices[0].message.refusal = null;
        completion.choices[0].message.tool_calls = null;
        msg.payload = JSON.stringify(completion);

        const [next, replied] = audio.interpreted(msg);

        assert.equal(next, msg);
        assert.equal(replied, null);
        assert.equal(msg.payload.amount, 1250);
        assert.equal(msg.audio.stage, "persistence");
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
            aiResponse(msg, extraction(scenario.fields));

            const [next, replied, logs] = audio.interpreted(msg);

            assert.equal(next, null);
            assert.equal(replied, null);
            assert.equal(logs.at(-1).payload.code, "invalid_interpretation");
        });
    }

    for (const decision of ["multiple_expenses", "unclear_audio", "not_expense"]) {
        test(`não salva interpretação ${decision}`, () => {
            const msg = authenticatedMessage();
            aiResponse(msg, { decision, expense: null });

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

describe("diagnóstico sanitizado da IA", () => {
    const privateFixture = "private-fixture:" + token + ":" + aiKey;
    const reasonDetail = reason => ({
        "@type": "type.googleapis.com/google.rpc.ErrorInfo",
        reason,
        metadata: { privateFixture },
    });
    const fieldDetail = field => ({
        "@type": "type.googleapis.com/google.rpc.BadRequest",
        fieldViolations: [{ field, description: privateFixture }],
    });

    for (const scenario of [
        { name: "chave inválida", error: { details: [reasonDetail("API_KEY_INVALID")] }, diagnostic: "ai_api_key_invalid" },
        { name: "chave expirada", error: { details: [reasonDetail("API_KEY_EXPIRED")] }, diagnostic: "ai_api_key_invalid" },
        { name: "chave restrita por serviço", error: { details: [reasonDetail("API_KEY_SERVICE_BLOCKED")] }, diagnostic: "ai_api_key_restricted" },
        { name: "chave restrita por origem", error: { details: [reasonDetail("API_KEY_HTTP_REFERRER_BLOCKED")] }, diagnostic: "ai_api_key_restricted" },
        { name: "chave restrita por IP", error: { details: [reasonDetail("API_KEY_IP_ADDRESS_BLOCKED")] }, diagnostic: "ai_api_key_restricted" },
        { name: "serviço desabilitado", error: { details: [reasonDetail("SERVICE_DISABLED")] }, diagnostic: "ai_service_disabled" },
        { name: "faturamento desabilitado", error: { details: [reasonDetail("BILLING_DISABLED")] }, diagnostic: "ai_billing_required" },
        { name: "schema em campo estruturado", error: { details: [fieldDetail("response_format.json_schema.schema.properties.expense")] }, diagnostic: "ai_schema_request" },
        { name: "configuração em campo estruturado", error: { details: [fieldDetail("reasoning_effort")] }, diagnostic: "ai_generation_config" },
        { name: "áudio em campo estruturado", error: { details: [fieldDetail("messages[1].content[0].input_audio")] }, diagnostic: "ai_audio_request" },
        { name: "modelo em campo estruturado", error: { details: [fieldDetail("model")] }, diagnostic: "ai_model_request" },
        { name: "schema mencionado na mensagem", error: { message: "Invalid JSON schema. " + privateFixture }, diagnostic: "ai_schema_request" },
        { name: "thinking mencionado na mensagem", error: { message: "Unsupported reasoning_effort. " + privateFixture }, diagnostic: "ai_generation_config" },
        { name: "áudio mencionado na mensagem", error: { message: "Invalid audio. " + privateFixture }, diagnostic: "ai_audio_request" },
        { name: "modelo mencionado na mensagem", error: { message: "Unsupported model. " + privateFixture }, diagnostic: "ai_model_request" },
        { name: "argumento inválido genérico", error: { status: "INVALID_ARGUMENT" }, diagnostic: "ai_invalid_request" },
        { name: "pré-condição", error: { status: "FAILED_PRECONDITION" }, diagnostic: "ai_precondition_failed" },
        { name: "autenticação", error: { status: "UNAUTHENTICATED" }, diagnostic: "ai_authentication_failed" },
        { name: "permissão", error: { status: "PERMISSION_DENIED" }, diagnostic: "ai_permission_denied" },
        { name: "modelo ausente", error: { status: "NOT_FOUND" }, diagnostic: "ai_model_not_found" },
        { name: "cota antes de menção a modelo", error: { status: "RESOURCE_EXHAUSTED", message: "Model quota. " + privateFixture }, diagnostic: "ai_quota_exceeded" },
        { name: "serviço indisponível", error: { status: "UNAVAILABLE" }, diagnostic: "ai_upstream_unavailable" },
        { name: "erro interno", error: { status: "INTERNAL" }, diagnostic: "ai_upstream_unavailable" },
        { name: "timeout remoto", error: { status: "DEADLINE_EXCEEDED" }, diagnostic: "ai_upstream_timeout" },
        { name: "estrutura inesperada", error: { details: [null, 7, { fieldViolations: privateFixture }], status: privateFixture }, diagnostic: "ai_invalid_request" },
        { name: "mensagem extensa ignorada", error: { message: "audio" + "x".repeat(8192) }, diagnostic: "ai_invalid_request" },
        { name: "razão desconhecida ignorada", error: { details: [reasonDetail(privateFixture)] }, diagnostic: "ai_invalid_request" },
        { name: "campo desconhecido ignorado", error: { details: [fieldDetail(privateFixture)] }, diagnostic: "ai_invalid_request" },
        { name: "crédito insuficiente", error: { code: "insufficient_credits" }, diagnostic: "ai_payment_required" },
        { name: "erro OpenRouter numérico", error: { code: 503 }, diagnostic: "ai_upstream_unavailable" },
        { name: "erro Chat Completions textual", error: { code: "invalid_request_error", message: "Invalid response_format. " + privateFixture }, diagnostic: "ai_schema_request" },
        { name: "rota indisponível", error: { code: "no_available_provider" }, diagnostic: "ai_provider_unavailable" },
    ]) {
        for (const handler of ["interpreted", "caught"]) {
            test(`${handler}: ${scenario.name} sem ecoar conteúdo remoto`, () => {
                const msg = authenticatedMessage();
                msg.statusCode = 400;
                msg.payload = JSON.stringify({ error: { message: privateFixture, ...scenario.error } });
                msg.error = { message: privateFixture };

                const [next, replied, logs] = audio[handler](msg);
                const entries = [];
                const safeLog = audio.audit(logs.at(-1), { log: entry => entries.push(entry) });

                assert.equal(next, null);
                assert.equal(replied, null);
                assert.equal(safeLog.payload.diagnostic, scenario.diagnostic);
                assert.equal(safeLog.payload.code, "interpretation_unavailable");
                assert.equal(safeLog.payload.upstream_status, 400);
                assert.equal(safeLog.payload.stage, "interpretation");
                assert.equal(msg.payload, undefined);
                assert.equal(msg.error, undefined);
                assert.equal(msg.audioToken, undefined);
                assert.equal(msg.audioConfiguration, undefined);
                assert.equal(msg.url, undefined);
                assert.ok(!JSON.stringify(logs).includes(privateFixture));
                assert.ok(!entries[0].includes(token));
                assert.ok(!entries[0].includes(aiKey));
            });
        }
    }

    for (const [status, diagnostic] of [
        [400, "ai_invalid_request"],
        [401, "ai_authentication_failed"],
        [402, "ai_payment_required"],
        [403, "ai_permission_denied"],
        [404, "ai_model_not_found"],
        [429, "ai_quota_exceeded"],
        [500, "ai_upstream_unavailable"],
        [502, "ai_upstream_unavailable"],
        [503, "ai_upstream_unavailable"],
        [504, "ai_upstream_timeout"],
        [418, "ai_error_unclassified"],
        ["ETIMEDOUT", "ai_transport_failure"],
    ]) {
        test(`fallback por HTTP/transporte: ${status}`, () => {
            const msg = authenticatedMessage();
            msg.statusCode = status;
            msg.payload = privateFixture;

            const [next, replied, logs] = audio.interpreted(msg);

            assert.equal(next, null);
            assert.equal(replied, null);
            assert.equal(logs.at(-1).payload.diagnostic, diagnostic);
            assert.ok(!JSON.stringify(logs).includes(privateFixture));
        });
    }

    for (const payload of ["null", "[]", '{"error":null}', '{"error":{"details":[null,{"@type":"type.googleapis.com/google.rpc.BadRequest","fieldViolations":[null,{"field":{}}]}]}}', "x".repeat(262145)]) {
        test(`corpo inesperado não interrompe limpeza: ${payload.length} bytes ${payload.slice(0, 12)}`, () => {
            const msg = authenticatedMessage();
            msg.statusCode = 400;
            msg.payload = payload;

            const [next, replied, logs] = audio.interpreted(msg);

            assert.equal(next, null);
            assert.equal(replied, null);
            assert.equal(logs.at(-1).payload.diagnostic, "ai_invalid_request");
            assert.equal(msg.payload, undefined);
        });
    }

    for (const diagnostic of [privateFixture, "ai_audio_request " + privateFixture, { code: "ai_audio_request" }]) {
        test(`audit descarta diagnóstico fora da allowlist: ${typeof diagnostic}`, () => {
            const safeLog = audio.audit({ payload: {
                request_id: requestId, event: "request.failed", stage: "interpretation",
                code: "interpretation_unavailable", diagnostic,
            } }, { log: () => {} });

            assert.equal(safeLog.payload.diagnostic, undefined);
        });
    }

    test("audit descarta diagnóstico IA fora de falha de interpretação", () => {
        const safeLog = audio.audit({ payload: {
            request_id: requestId, event: "request.failed", stage: "persistence",
            code: "persistence_unknown", diagnostic: "ai_audio_request",
        } }, { log: () => {} });

        assert.equal(safeLog.payload.diagnostic, undefined);
    });
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
        msg.error = { message: token + aiKey };

        const [next, replied, logs] = audio.caught(msg);

        assert.equal(next, null);
        assert.equal(replied, null);
        assert.equal(logs.at(-1).payload.code, "persistence_unknown");
        assert.equal(msg.error, undefined);
        assert.ok(!JSON.stringify(logs).includes(token));
        assert.ok(!JSON.stringify(logs).includes(aiKey));
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
        aiResponse(msg, extraction());
        const [persistence, replied] = audio.interpreted(msg);

        assert.equal(persistence, msg);
        assert.equal(replied, null);
        assert.equal(msg.audio.stage, "persistence");
    });

    test("logger remove todo conteúdo fora da allowlist", () => {
        const entries = [];
        const safeMessage = audio.audit({ payload: {
            request_id: requestId, event: "request.failed", stage: "persistence", elapsed_ms: 10,
            code: "persistence_unknown", token, aiKey, description: "private-fixture", amount: 1250,
            headers: { Authorization: token }, audio: Buffer.from("private-audio"),
        } }, { log: entry => entries.push(entry) });

        assert.deepEqual(safeMessage.payload, {
            request_id: requestId, event: "request.failed", elapsed_ms: 10, stage: "persistence", code: "persistence_unknown",
        });
        assert.equal(entries.length, 1);
        assert.ok(!entries[0].includes(token));
        assert.ok(!entries[0].includes(aiKey));
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
                aiResponse(msg, extraction());
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
    const authentication = nodes.find(node => node.id === "c0da700000000104");
    const interpretation = nodes.find(node => node.type === "http request" && node.name.startsWith("IA:"));
    const response = nodes.find(node => node.type === "http response");
    assert.deepEqual(authentication.wires[0], [interpretation.id]);
    assert.deepEqual(authentication.wires[1], [response.id]);
});
