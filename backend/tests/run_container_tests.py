"""Verificação opt-in Linux com Podman: recursos exclusivos, sem portas públicas ou SMTP real."""

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import uuid


ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--image", default="localhost/cordato-pocketbase:verification")
    parser.add_argument("--python-image", default="docker.io/library/python:3.14.7-slim")
    args = parser.parse_args()
    podman = shutil.which("podman")
    if not podman:
        raise SystemExit("Podman não encontrado. Este runner não instala nem inicia a engine.")

    def run(*command, **kwargs):
        return subprocess.run([podman, *command], check=True, timeout=120, **kwargs)

    identity = "cordato-test-" + uuid.uuid4().hex[:12]
    extraction = identity + "-extract"
    server = identity + "-http"
    volume = identity + "-data"
    created_containers = []
    created_volume = False
    try:
        with tempfile.TemporaryDirectory(prefix="cordato-container-") as directory:
            temp = Path(directory)
            run("create", "--pull=never", "--name", extraction, "--entrypoint", "/bin/true",
                args.image, capture_output=True)
            created_containers.append(extraction)
            run("cp", extraction + ":/usr/local/bin/pocketbase", str(temp / "pocketbase"))

            def python_test(module, network, extra_env):
                run("run", "--rm", "--pull=never", "--network=" + network, "--read-only",
                    "--tmpfs", "/tmp:rw,size=256m,mode=1777",
                    "-v", str(ROOT) + ":/workspace:ro", "-v", str(temp) + ":/tools:ro",
                    "-w", "/workspace/tests", "-e", "PYTHONDONTWRITEBYTECODE=1",
                    "-e", extra_env, args.python_image, "python3", "-m", "unittest", module, "-v")

            python_test("test_setup.NativeMigrationTest", "none", "POCKETBASE_TEST_BINARY=/tools/pocketbase")
            migrations = temp / "migrations"
            shutil.copytree(ROOT / "pb_migrations", migrations)
            migrations.chmod(0o755)
            shutil.copyfile(ROOT / "tests/fixtures/http_seed.js", migrations / "1793491201_http_seed.js")
            fixtures = {
                "POCKETBASE_PUBLIC_URL": "https://pocketbase.example.com",
                "POCKETBASE_ADMIN_EMAIL": "admin@example.com",
                "POCKETBASE_ADMIN_PASSWORD": "DisposableAdmin9!",
                "SMTP_PASSWORD": "fake-smtp-only-for-disposable-test",
                "POCKETBASE_ENCRYPTION_KEY": "0123456789abcdef0123456789abcdef",
            }
            run("volume", "create", volume, capture_output=True)
            created_volume = True
            command = ["run", "--detach", "--pull=never", "--name", server, "--network=none",
                       "--read-only", "--tmpfs", "/tmp:rw,noexec,nosuid,size=64m,mode=1777",
                       "--cap-drop=ALL", "--security-opt=no-new-privileges:true",
                       "-v", volume + ":/pb/pb_data", "-v", str(migrations) + ":/opt/cordato/migrations:ro"]
            for key in fixtures:
                command.extend(["-e", key])
            command.append(args.image)
            run(*command, env=dict(os.environ, **fixtures), capture_output=True)
            created_containers.append(server)
            # Mesmo namespace isolado: sem publicar portas nem permitir saída SMTP.
            python_test("test_http.HttpTest", "container:" + server, "CORDATO_DISPOSABLE_HTTP_TEST=1")
            print("Migrations e HTTP Linux aprovados; nenhum serviço remoto ou segredo real utilizado.")
    finally:
        for name in reversed(created_containers):
            subprocess.run([podman, "rm", "--force", name], capture_output=True, timeout=30, check=True)
        if created_volume:
            subprocess.run([podman, "volume", "rm", volume], capture_output=True, timeout=30, check=True)


if __name__ == "__main__":
    main()
