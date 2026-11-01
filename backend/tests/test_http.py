"""Opt-in: somente contra o servidor descartável criado por run_container_tests.py."""

import json
import os
import time
import unittest
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen


@unittest.skipUnless(os.environ.get("CORDATO_DISPOSABLE_HTTP_TEST") == "1",
                     "Execute tests/run_container_tests.py para testar HTTP isolado.")
class HttpTest(unittest.TestCase):
    base = "http://127.0.0.1:8090"

    @classmethod
    def request(cls, method, path, body=None, token=None):
        headers = {"Content-Type": "application/json"}
        if token:
            headers["Authorization"] = token
        req = Request(cls.base + path, method=method, headers=headers,
                      data=None if body is None else json.dumps(body).encode())
        try:
            response = urlopen(req, timeout=5)
        except HTTPError as error:
            response = error
        with response:
            data = response.read()
            return response.status, json.loads(data) if data else None

    @classmethod
    def setUpClass(cls):
        deadline = time.monotonic() + 30
        while True:
            try:
                status, _ = cls.request("GET", "/api/health")
                if status == 200:
                    break
            except (URLError, TimeoutError):
                pass
            if time.monotonic() >= deadline:
                raise AssertionError("O servidor descartável não ficou saudável em 30s.")
            time.sleep(0.2)
        cls.sessions = {}
        for name in ("alice", "bob"):
            status, result = cls.request("POST", "/api/collections/users/auth-with-password",
                                         {"identity": name + "@example.com", "password": "ValidPass9"})
            if status != 200:
                raise AssertionError("Falha de login da fixture descartável.")
            cls.sessions[name] = result

    def setUp(self):
        self.alice = self.sessions["alice"]
        self.bob = self.sessions["bob"]
        self.created = []

    def tearDown(self):
        for record_id in self.created:
            self.request("DELETE", "/api/collections/expenses/records/" + record_id,
                         token=self.alice["token"])

    def expense(self, **changes):
        body = {"owner": self.alice["record"]["id"], "amount": 2590, **changes}
        status, result = self.request("POST", "/api/collections/expenses/records", body,
                                      self.alice["token"])
        self.assertEqual(status, 200)
        self.created.append(result["id"])
        return result

    def test_own_crud_and_optional_fields(self):
        record = self.expense()
        self.assertEqual(record["category"], "")
        self.assertEqual(record["occurred_on"], "")
        self.assertTrue(record["created"])
        self.assertTrue(record["updated"])
        path = "/api/collections/expenses/records/" + record["id"]
        status, changed = self.request("PATCH", path, {
            "description": "Almoço", "category": "food",
            "occurred_on": "2026-11-01T12:30:00Z",
        }, self.alice["token"])
        self.assertEqual(status, 200)
        self.assertEqual(changed["category"], "food")
        self.assertEqual(changed["occurred_on"], "2026-11-01 12:30:00.000Z")
        self.assertEqual(self.request("GET", path, token=self.alice["token"])[0], 200)
        self.assertEqual(self.request("DELETE", path, token=self.alice["token"])[0], 204)
        self.assertEqual(self.request("GET", path, token=self.alice["token"])[0], 404)

    def test_other_user_cannot_list_read_update_or_delete(self):
        record = self.expense()
        path = "/api/collections/expenses/records/" + record["id"]
        for method, body in (("GET", None), ("PATCH", {"amount": 1}), ("DELETE", None)):
            self.assertEqual(self.request(method, path, body, self.bob["token"])[0], 404)
        status, listing = self.request("GET", "/api/collections/expenses/records?" +
                                       urlencode({"filter": "id='" + record["id"] + "'"}),
                                       token=self.bob["token"])
        self.assertEqual(status, 200)
        self.assertEqual(listing["items"], [])

    def test_owner_and_timestamps_cannot_be_forged(self):
        record = self.expense()
        path = "/api/collections/expenses/records/" + record["id"]
        for body in ({"owner": self.bob["record"]["id"]},
                     {"owner+": self.bob["record"]["id"]}, {"owner-": self.alice["record"]["id"]},
                     {"created": "2020-01-01 00:00:00.000Z"},
                     {"updated": "2020-01-01 00:00:00.000Z"}):
            self.assertEqual(self.request("PATCH", path, body, self.alice["token"])[0], 404)
        self.assertEqual(self.request("POST", "/api/collections/expenses/records",
                                     {"owner": self.bob["record"]["id"], "amount": 1},
                                     self.alice["token"])[0], 400)

    def test_native_amount_date_and_category_validation(self):
        for changes in ({"amount": 0}, {"amount": -1}, {"amount": 1.5},
                        {"amount": 9007199254740992}, {"category": "invalid-category"}):
            body = {"owner": self.alice["record"]["id"], "amount": 1, **changes}
            with self.subTest(changes=changes):
                self.assertEqual(self.request("POST", "/api/collections/expenses/records", body,
                                             self.alice["token"])[0], 400)
        self.assertEqual(self.expense(amount=9007199254740991)["amount"], 9007199254740991)
        # Date opcional nativo normaliza entrada inválida para vazio, não erro 400.
        self.assertEqual(self.expense(occurred_on="not-a-date")["occurred_on"], "")

    def test_user_profile_is_private_and_avatar_is_text(self):
        path = "/api/collections/users/records/" + self.alice["record"]["id"]
        self.assertEqual(self.request("GET", path, token=self.bob["token"])[0], 404)
        status, profile = self.request("PATCH", path, {"avatar": "stable-seed", "name": "Alice"},
                                       self.alice["token"])
        self.assertEqual(status, 200)
        self.assertEqual(profile["avatar"], "stable-seed")
        self.assertNotIn("tokenKey", profile)
        self.assertNotIn("password", profile)
        self.assertEqual(self.request("PATCH", path, {"verified": True}, self.alice["token"])[0], 404)
        self.assertEqual(self.request("PATCH", path, {"avatar": "x" * 2049}, self.alice["token"])[0], 400)

    def test_unverified_login_is_rejected_and_superuser_requires_mfa(self):
        self.assertEqual(self.request("POST", "/api/collections/users/auth-with-password",
                                     {"identity": "pending@example.com", "password": "ValidPass9"})[0], 403)
        status, challenge = self.request("POST", "/api/collections/_superusers/auth-with-password",
                                         {"identity": "admin@example.com", "password": "DisposableAdmin9!"})
        self.assertEqual(status, 401)
        self.assertIn("mfaId", challenge)
        self.assertNotIn("token", challenge)

    def test_public_signup_is_pending_verification_and_cannot_self_verify(self):
        body = {"email": "signup@example.com", "password": "ValidPass9", "passwordConfirm": "ValidPass9"}
        self.assertEqual(self.request("POST", "/api/collections/users/records",
                                     {**body, "verified": True})[0], 400)
        status, profile = self.request("POST", "/api/collections/users/records", body)
        self.assertEqual(status, 200)
        self.assertFalse(profile["verified"])
        self.assertNotIn("token", profile)

    def test_batch_is_disabled(self):
        status, _ = self.request("POST", "/api/batch", {"requests": []}, self.alice["token"])
        self.assertEqual(status, 403)


if __name__ == "__main__":
    unittest.main()
