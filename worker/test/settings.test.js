const assert = require("node:assert/strict");
const { spawnSync } = require("node:child_process");
const path = require("node:path");
const { test } = require("node:test");

const settingsPath = path.join(__dirname, "..", "settings.js");
const fixtureEnvironment = {
    NODE_RED_ADMIN_USERNAME: "fixture-admin",
    NODE_RED_ADMIN_PASSWORD_HASH: "$2b$08$" + "a".repeat(53),
    NODE_RED_CREDENTIAL_SECRET: "fixture-only-not-a-real-secret-32-characters",
};

function loadSettings(environment) {
    return spawnSync(process.execPath, [
        "-e",
        "process.stdout.write(JSON.stringify(require(process.argv[1])))",
        settingsPath,
    ], { env: environment, encoding: "utf8" });
}

test("configura autenticação obrigatória sem usuário anônimo", () => {
    const execution = loadSettings(fixtureEnvironment);
    assert.equal(execution.status, 0);

    const settings = JSON.parse(execution.stdout);
    assert.deepEqual(settings.adminAuth, {
        type: "credentials",
        sessionExpiryTime: 43200,
        users: [{
            username: fixtureEnvironment.NODE_RED_ADMIN_USERNAME,
            password: fixtureEnvironment.NODE_RED_ADMIN_PASSWORD_HASH,
            permissions: "*",
        }],
    });
    assert.equal(settings.credentialSecret, fixtureEnvironment.NODE_RED_CREDENTIAL_SECRET);
});

test("mantém dados no volume, habilita a API e desabilita instalações adicionais", () => {
    const execution = loadSettings(fixtureEnvironment);
    assert.equal(execution.status, 0);

    const settings = JSON.parse(execution.stdout);
    assert.equal(settings.userDir, "/data");
    assert.equal(settings.flowFile, "flows.json");
    assert.equal(settings.httpAdminRoot, "/admin");
    assert.equal(settings.httpNodeRoot, "/api");
    assert.deepEqual(settings.functionGlobalContext, { cordatoAudio: {} });
    assert.equal(settings.exportGlobalContextKeys, false);
    assert.equal(settings.functionExternalModules, false);
    assert.equal(settings.externalModules.autoInstall, false);
    assert.deepEqual(settings.externalModules.palette, {
        allowInstall: false,
        allowUpdate: false,
        allowUpload: false,
    });
    assert.equal(settings.externalModules.modules.allowInstall, false);
    assert.equal(settings.editorTheme.projects.enabled, false);
    assert.equal(settings.telemetry.enabled, false);
});

for (const variableName of Object.keys(fixtureEnvironment)) {
    test(`recusa inicialização sem ${variableName}`, () => {
        const environment = { ...fixtureEnvironment };
        delete environment[variableName];

        const execution = loadSettings(environment);

        assert.notEqual(execution.status, 0);
        assert.equal(execution.stdout, "");
        assert.ok(execution.stderr.includes(variableName));
        assert.ok(!execution.stderr.includes(fixtureEnvironment.NODE_RED_CREDENTIAL_SECRET));
    });
}

for (const invalidHash of ["", "plaintext-password", "$2b$08$short", "$2b$99$" + "a".repeat(53)]) {
    test(`recusa hash inválido: ${invalidHash || "vazio"}`, () => {
        const execution = loadSettings({
            ...fixtureEnvironment,
            NODE_RED_ADMIN_PASSWORD_HASH: invalidHash,
        });

        assert.notEqual(execution.status, 0);
        assert.ok(execution.stderr.includes("NODE_RED_ADMIN_PASSWORD_HASH"));
        assert.equal(execution.stdout, "");
    });
}

test("recusa usuário em branco", () => {
    const execution = loadSettings({ ...fixtureEnvironment, NODE_RED_ADMIN_USERNAME: "   " });

    assert.notEqual(execution.status, 0);
    assert.ok(execution.stderr.includes("NODE_RED_ADMIN_USERNAME"));
});

test("recusa chave curta ou composta por espaços", () => {
    for (const invalidSecret of ["short", " ".repeat(32)]) {
        const execution = loadSettings({
            ...fixtureEnvironment,
            NODE_RED_CREDENTIAL_SECRET: invalidSecret,
        });

        assert.notEqual(execution.status, 0);
        assert.ok(execution.stderr.includes("NODE_RED_CREDENTIAL_SECRET"));
        assert.equal(execution.stdout, "");
    }
});
