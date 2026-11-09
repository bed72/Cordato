const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { createRequire } = require("node:module");

function loadLanguage(executable) {
  if (!executable) {
    throw new Error("Instale a CLI Bruno 4 antes de validar a coleção.");
  }
  const cliRequire = createRequire(fs.realpathSync(executable));
  return cliRequire("@usebruno/lang");
}

function collectionFiles(directory) {
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    if (entry.name.startsWith(".") || ["private", "reports"].includes(entry.name)) {
      return [];
    }
    const filename = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      return collectionFiles(filename);
    }
    return entry.name.endsWith(".bru") && !entry.name.endsWith(".local.bru") && filename !== path.join(__dirname, "../bruno/environments/development.bru") ? [filename] : [];
  });
}

function validateCollection(root, executable) {
  const language = loadLanguage(executable);
  const directory = path.join(root, "bruno");
  const requests = collectionFiles(directory).filter((filename) => !filename.includes(path.sep + "environments" + path.sep) && !["collection.bru", "folder.bru"].includes(path.basename(filename)));
  const expected = ["audio/02-upload-file.bru", "authentication/01-login.bru"];
  if (JSON.stringify(requests.map((filename) => path.relative(directory, filename)).sort()) !== JSON.stringify(expected)) {
    throw new Error("A coleção deve conter somente login e upload.");
  }
  const collection = language.collectionBruToJson(fs.readFileSync(path.join(directory, "collection.bru"), "utf8"));
  const documents = [collection, ...requests.map((filename) => language.bruToJsonV2(fs.readFileSync(filename, "utf8")))];
  for (const document of documents) {
    for (const source of [document.script?.req, document.script?.res, document.tests]) {
      if (source) {
        new vm.Script("(async function () {\n" + source + "\n})");
        if (/bru\.(setEnvVar|sendRequest)\s*\(|console\s*\./.test(source)) {
          throw new Error("Não persistir tokens, fazer login oculto ou logar credenciais.");
        }
      }
    }
  }
  const environment = language.bruToEnvJsonV2(fs.readFileSync(path.join(directory, "environments/example.bru"), "utf8"));
  for (const name of ["email", "password", "audioFile"]) {
    const input = environment.variables.find((variable) => variable.name === name);
    if (!input?.secret || input.value) {
      throw new Error("Credenciais versionadas não são permitidas.");
    }
  }
  return requests.length;
}

module.exports = { loadLanguage, collectionFiles, validateCollection };

if (require.main === module) {
  try {
    const count = validateCollection(path.resolve(__dirname, ".."), process.argv[2]);
    process.stdout.write("Coleção local válida: " + count + " requests (login e upload). Sem HTTP.\n");
  } catch (failure) {
    process.stderr.write(failure.message + "\n");
    process.exitCode = 1;
  }
}
