const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { execFileSync } = require("node:child_process");
const { test } = require("node:test");
const { loadLanguage, validateCollection } = require("./check_bruno.cjs");

const executable = execFileSync("which", ["bru"], { encoding: "utf8" }).trim();
const language = loadLanguage(executable);
const root = path.resolve(__dirname, "../bruno");
const collection = language.collectionBruToJson(fs.readFileSync(path.join(root, "collection.bru"), "utf8"));
const login = language.bruToJsonV2(fs.readFileSync(path.join(root, "authentication/01-login.bru"), "utf8"));
const upload = language.bruToJsonV2(fs.readFileSync(path.join(root, "audio/02-upload-file.bru"), "utf8"));

function executeScript(source, { environment = {}, processInputs = {}, runtime = {}, status = 200, response = {}, url, body = JSON.parse(login.body.json) } = {}) {
  const request = { body };
  vm.runInNewContext(source, {
    bru: {
      getAllEnvVars: () => environment,
      getProcessEnv: (name) => processInputs[name],
      getVar: (name) => runtime[name],
      setVar: (name, value) => { runtime[name] = value; },
      deleteVar: (name) => { delete runtime[name]; },
      interpolate: () => environment.baseUrl || "http://127.0.0.1:8091"
    },
    req: {
      getUrl: () => url || login.http.url,
      getBody: () => request.body,
      setBody: (value) => { request.body = value; },
      setTimeout: (value) => { assert.equal(value, 10000); }
    },
    res: { getStatus: () => status, getBody: () => response }
  }, { timeout: 1000 });
  return { runtime, body: request.body };
}

test("coleção contém exatamente login e upload, sem produção ou requests extras", () => {
  assert.equal(validateCollection(path.resolve(root, ".."), executable), 2);
  assert.equal(fs.existsSync(path.join(root, "environments/production.bru")), false);
});

test("guarda permite somente loopback e API da origem selecionada", () => {
  executeScript(collection.script.req);
  for (const baseUrl of ["https://pocketbase.cordato.cloud", "http://example.test:8091", "http://127.0.0.1:8091.evil.test"]) {
    assert.throws(() => executeScript(collection.script.req, { environment: { baseUrl } }), /somente no servidor local/);
  }
  assert.throws(() => executeScript(collection.script.req, { url: "http://example.test/api/health" }), /somente no servidor local/);
});

test("login usa entradas do ambiente e preserva caracteres da senha", () => {
  const prepared = executeScript(login.script.req, { environment: { email: "fixture@example.test", password: ' A"b\\123{{ ' }, runtime: { token: "old" } });
  assert.equal(prepared.body.identity, "fixture@example.test");
  assert.equal(prepared.body.password, ' A"b\\123{{ ');
  assert.equal(prepared.runtime.token, undefined);
});

test("CLI aceita credenciais de processo e ambiente local prevalece", () => {
  const processInputs = { CORDATO_DEVELOPMENT_EMAIL: "fixture@example.test", CORDATO_DEVELOPMENT_PASSWORD: "Fixture123" };
  assert.equal(executeScript(login.script.req, { processInputs }).body.password, "Fixture123");
  assert.equal(executeScript(login.script.req, { processInputs, environment: { password: "Local123" } }).body.password, "Local123");
});

test("login sem credenciais falha e descarta token anterior", () => {
  const runtime = { token: "old" };
  assert.throws(() => executeScript(login.script.req, { runtime }), /email e password/);
  assert.equal(runtime.token, undefined);
});

test("login bem sucedido captura token somente em runtime", () => {
  assert.equal(executeScript(login.script.res, { response: { token: "captured" } }).runtime.token, "captured");
});

test("login recusado não captura sessão", () => {
  assert.equal(executeScript(login.script.res, { status: 403 }).runtime.token, undefined);
});

test("upload exige login explícito e usa body de arquivo", () => {
  assert.throws(() => executeScript(upload.script.req), /Login local/);
  executeScript(upload.script.req, { runtime: { token: "captured" } });
  assert.equal(upload.http.body, "file");
  assert.equal(upload.auth.bearer.token, "{{token}}");
});
