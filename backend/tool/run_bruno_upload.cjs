const fs = require("node:fs");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

function upload(extraArguments) {
  const audioFile = process.env.CORDATO_DEVELOPMENT_AUDIO_FILE;
  if (!audioFile || !path.isAbsolute(audioFile) || /[\r\n()]/.test(audioFile) || !fs.statSync(audioFile).isFile()) {
    throw new Error("AUDIO_FILE deve apontar para um arquivo absoluto de teste, sem parênteses ou quebras de linha no caminho.");
  }
  const root = path.resolve(__dirname, "..");
  const temporaryRoot = path.join(root, ".temp");
  fs.mkdirSync(temporaryRoot, { recursive: true, mode: 0o700 });
  const workspace = fs.mkdtempSync(path.join(temporaryRoot, "bruno-upload-"));
  try {
    const files = ["bruno.json", "collection.bru", "environments/example.bru", "authentication/01-login.bru", "audio/02-upload-file.bru"];
    for (const filename of files) {
      const destination = path.join(workspace, filename === "environments/example.bru" ? "environments/development.bru" : filename);
      fs.mkdirSync(path.dirname(destination), { recursive: true, mode: 0o700 });
      const source = fs.readFileSync(path.join(root, "bruno", filename), "utf8");
      const content = filename === "audio/02-upload-file.bru" ? source.replace("@file({{audioFile}})", "@file(" + audioFile + ")") : source;
      fs.writeFileSync(destination, content, { mode: 0o600 });
    }
    const execution = spawnSync("bru", ["run", "authentication/01-login.bru", "audio/02-upload-file.bru", "-r", "--env", "development",
      "--sandbox", "safe", "--noproxy", "--bail", "--delay", "300", "--reporter-skip-all-headers", "--reporter-skip-body", ...extraArguments],
    { cwd: workspace, env: process.env, stdio: "inherit" });
    if (execution.error) {
      throw new Error("Não foi possível executar a CLI Bruno instalada.");
    }
    return execution.status ?? 1;
  } finally {
    fs.rmSync(workspace, { recursive: true, force: true });
  }
}

module.exports = { upload };

if (require.main === module) {
  try {
    process.exitCode = upload(process.argv.slice(2));
  } catch (failure) {
    process.stderr.write("Não foi possível preparar o upload binário. Confira CLI, ambiente e AUDIO_FILE privado.\n");
    process.exitCode = 1;
  }
}
