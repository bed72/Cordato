"""Testes sem serviços, rede, Docker ou leitura de arquivos de segredos."""

import os
from pathlib import Path
import shutil
import shlex
import sqlite3
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class EntrypointTest(unittest.TestCase):
    def run_entrypoint(self, key):
        with tempfile.TemporaryDirectory(prefix="cordato-entrypoint-") as directory:
            executable = Path(directory) / "pocketbase"
            executable.write_text('#!/bin/sh\nprintf "%s\\n" "$@"\n')
            executable.chmod(0o700)
            env = {"PATH": f"{directory}:/usr/bin:/bin"}
            if key is not None:
                env["POCKETBASE_ENCRYPTION_KEY"] = key
            return subprocess.run(
                ["sh", str(ROOT / "docker/entrypoint.sh")],
                env=env, capture_output=True, text=True, timeout=5,
            )

    def test_missing_or_invalid_key_fails_without_showing_value(self):
        for key in (None, "", "short-secret", "x" * 31, "x" * 33):
            with self.subTest(length=None if key is None else len(key)):
                result = self.run_entrypoint(key)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, "")
                self.assertIn("POCKETBASE_ENCRYPTION_KEY", result.stderr)
                if key:
                    self.assertNotIn(key, result.stderr)

    def test_valid_key_executes_only_fixed_safe_server_options(self):
        key = "a" * 32
        result = self.run_entrypoint(key)
        self.assertEqual(result.returncode, 0, result.stderr)
        args = result.stdout.splitlines()
        self.assertEqual(args, [
            "serve", "--http=0.0.0.0:8090", "--dir=/pb/pb_data",
            "--migrationsDir=/opt/cordato/migrations",
            "--hooksDir=/opt/cordato/no-hooks", "--publicDir=/opt/cordato/no-public",
            "--automigrate=false", "--encryptionEnv=POCKETBASE_ENCRYPTION_KEY",
        ])
        self.assertNotIn(key, result.stdout + result.stderr)

    def test_counts_key_bytes_not_unicode_characters(self):
        result = self.run_entrypoint("á" * 32)
        self.assertNotEqual(result.returncode, 0)


class RepositoryTest(unittest.TestCase):
    def test_migration_directories_are_traversable_and_files_stay_read_only(self):
        dockerfile = (ROOT / "Dockerfile").read_text()
        copy = "COPY --chmod=0444 pb_migrations/ /opt/cordato/migrations/"
        fix = "RUN find /opt/cordato/migrations -type d -exec chmod 0555 {} +"
        self.assertIn(copy, dockerfile)
        self.assertIn(fix, dockerfile)
        self.assertLess(dockerfile.index(copy), dockerfile.index(fix))
        self.assertLess(dockerfile.index(fix), dockerfile.index("USER 10001:10001"))
        with tempfile.TemporaryDirectory(prefix="cordato-permissions-") as directory:
            migrations = Path(directory) / "migrations"
            nested = migrations / "nested"
            nested.mkdir(parents=True)
            migration = nested / "initial.js"
            migration.write_text("")
            migration.chmod(0o444)
            command = shlex.split(fix.removeprefix("RUN "))
            command[1] = str(migrations)
            try:
                result = subprocess.run(command, capture_output=True, text=True, timeout=5)
                self.assertEqual(result.returncode, 0, result.stderr)
                for path in (migrations, nested):
                    self.assertEqual(path.stat().st_mode & 0o777, 0o555)
                self.assertEqual(migration.stat().st_mode & 0o777, 0o444)
            finally:
                migrations.chmod(0o755)
                nested.chmod(0o755)

    def test_private_paths_are_ignored(self):
        paths = [".env", ".env.production", "pb_data/data.db", "backups/private.zip",
                 "pocketbase", "pocketbase_0.41.1_darwin_arm64.zip"]
        result = subprocess.run(
            ["git", "check-ignore", "--", *paths], cwd=ROOT,
            capture_output=True, text=True, timeout=5,
        )
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.splitlines(), paths)

    def test_no_hooks_or_node_runtime(self):
        self.assertFalse((ROOT / "pb_hooks").exists())
        self.assertFalse((ROOT / "package.json").exists())
        self.assertFalse((ROOT / "src").exists())


@unittest.skipUnless(os.environ.get("POCKETBASE_TEST_BINARY"),
                     "Defina POCKETBASE_TEST_BINARY para testar migrations com PocketBase real.")
class NativeMigrationTest(unittest.TestCase):
    """Opt-in: CLI migrate em banco novo descartável. Nunca inicia servidor."""

    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="cordato-migrations-")
        self.addCleanup(self.directory.cleanup)
        self.temp = Path(self.directory.name)
        self.migrations = self.temp / "migrations"
        shutil.copytree(ROOT / "pb_migrations", self.migrations)
        self.env = {"PATH": "/usr/bin:/bin", "HOME": str(self.temp),
                    "POCKETBASE_PUBLIC_URL": "https://pocketbase.example.com",
                    "POCKETBASE_ADMIN_EMAIL": "admin@example.com",
                    "POCKETBASE_ADMIN_PASSWORD": "DisposableAdmin9!",
                    "SMTP_PASSWORD": "fake-smtp-only-for-disposable-test",
                    "POCKETBASE_ENCRYPTION_KEY": "0123456789abcdef0123456789abcdef"}
        self.binary = str(Path(os.environ["POCKETBASE_TEST_BINARY"]).expanduser().resolve())
        version = subprocess.run([self.binary, "--version"], env=self.env,
                                 capture_output=True, text=True, timeout=10)
        self.assertEqual(version.returncode, 0, "O binário não pôde ser executado.")
        self.assertEqual(version.stdout.strip(), "pocketbase version 0.41.1")

    def migrate(self, env=None):
        return subprocess.run([
            self.binary, "migrate", "up", f"--dir={self.temp / 'data'}",
            f"--migrationsDir={self.migrations}", f"--hooksDir={self.temp / 'no-hooks'}",
            "--automigrate=false", "--encryptionEnv=POCKETBASE_ENCRYPTION_KEY",
        ], env=self.env if env is None else env, cwd=self.temp,
            capture_output=True, text=True, timeout=30)

    def assert_success(self, result):
        # Não despeje stdout/stderr: um erro nativo pode carregar valores de configuração.
        self.assertEqual(result.returncode, 0, "Falha no PocketBase real (saída privada suprimida).")

    def collections(self):
        with sqlite3.connect(self.temp / "data/data.db") as db:
            db.row_factory = sqlite3.Row
            return {row["name"]: dict(row) for row in db.execute("SELECT * FROM _collections")}

    def test_bootstrap_schema_encryption_and_restart(self):
        import json
        self.assert_success(self.migrate())
        collections = self.collections()
        self.assertIn("expenses", collections)
        users = collections["users"]
        expenses = collections["expenses"]
        fields = {field["name"]: field for field in json.loads(expenses["fields"])}
        self.assertEqual(fields["amount"]["min"], 1)
        self.assertEqual(fields["amount"]["max"], 9007199254740991)
        self.assertTrue(fields["amount"]["onlyInt"])
        self.assertTrue(fields["owner"]["cascadeDelete"])
        self.assertFalse(fields["category"]["required"])
        self.assertEqual(len(fields["category"]["values"]), 18)
        self.assertEqual(fields["occurred_on"]["type"], "date")
        self.assertFalse(fields["occurred_on"]["required"])
        for name in ("created", "updated"):
            self.assertEqual(fields[name]["type"], "autodate")
        user_fields = {field["name"]: field for field in json.loads(users["fields"])}
        self.assertEqual(user_fields["avatar"]["type"], "text")
        self.assertEqual(user_fields["avatar"]["max"], 2048)
        self.assertEqual(json.loads(users["options"])["authRule"], "verified = true")
        self.assertTrue(json.loads(collections["_superusers"]["options"])["mfa"]["enabled"])
        self.assertIn("owner:changed = false", expenses["updateRule"])
        with sqlite3.connect(self.temp / "data/data.db") as db:
            self.assertEqual(db.execute("SELECT COUNT(*) FROM _superusers").fetchone()[0], 1)
            raw_settings = db.execute("SELECT value FROM _params WHERE id = 'settings'").fetchone()[0]
            self.assertNotIn(self.env["SMTP_PASSWORD"], str(raw_settings))
            self.assertNotIn('"smtp"', str(raw_settings))
        # Após bootstrap, o histórico impede reconciliar senhas/settings pelo ambiente.
        env = {key: value for key, value in self.env.items()
               if key not in ("POCKETBASE_ADMIN_EMAIL", "POCKETBASE_ADMIN_PASSWORD", "SMTP_PASSWORD", "POCKETBASE_PUBLIC_URL")}
        self.assert_success(self.migrate(env))
        self.assertEqual(self.collections(), collections)

    def test_missing_bootstrap_secret_rolls_back_application_schema(self):
        env = dict(self.env)
        del env["SMTP_PASSWORD"]
        result = self.migrate(env)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("expenses", self.collections())
        self.assert_success(self.migrate())

    def test_invalid_public_url_is_rejected_and_can_be_retried(self):
        for url in ("http://example.com", "https://user:password@example.com", "https://example.com/#fragment"):
            env = dict(self.env, POCKETBASE_PUBLIC_URL=url)
            self.assertNotEqual(self.migrate(env).returncode, 0)
            self.assertNotIn("expenses", self.collections())
        self.assert_success(self.migrate())

    def test_settings_models_rules_and_cascade(self):
        shutil.copyfile(ROOT / "tests/fixtures/verify.js", self.migrations / "1793491201_verify.js")
        self.assert_success(self.migrate())


if __name__ == "__main__":
    unittest.main()
