"""Teste pentru serverul Buble: python3 -m unittest server/test_server.py"""
import json
import os
import sys
import tempfile
import threading
import unittest
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import buble_server  # noqa: E402


class ServerTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.mkdtemp()
        cls.srv = buble_server.serve(0, os.path.join(cls.tmp, "t.db"), "127.0.0.1")
        cls.port = cls.srv.server_address[1]
        threading.Thread(target=cls.srv.serve_forever, daemon=True).start()

    @classmethod
    def tearDownClass(cls):
        cls.srv.shutdown()

    def call(self, method, path, body=None, token=None):
        req = urllib.request.Request(f"http://127.0.0.1:{self.port}{path}", method=method,
                                     data=json.dumps(body).encode() if body is not None else None,
                                     headers={"Content-Type": "application/json", **({"Authorization": "Bearer " + token} if token else {})})
        try:
            with urllib.request.urlopen(req) as r:
                return r.status, json.loads(r.read())
        except urllib.error.HTTPError as e:
            return e.code, json.loads(e.read())

    def player(self, dev, name):
        code, d = self.call("POST", "/v1/auth", {"device_id": dev, "name": name})
        self.assertEqual(code, 200)
        return d

    def test_flow(self):
        a = self.player("device-aaaa", "Ana")
        b = self.player("device-bbbb", "Bogdan")
        self.assertEqual(self.player("device-aaaa", "Ana")["token"], a["token"], "același dispozitiv = același cont")
        self.assertEqual(self.call("GET", "/v1/me")[0], 401)
        # insula și salvarea
        self.assertEqual(self.call("PUT", "/v1/island", {"island": 2, "levels": {"palat": 3}, "shields": 1, "name": "Bogdan"}, b["token"])[0], 200)
        self.assertEqual(self.call("PUT", "/v1/save", {"data": {"coins": 5}}, a["token"])[0], 200)
        self.assertEqual(self.call("GET", "/v1/save", token=a["token"])[1]["data"]["coins"], 5)
        # prieteni
        code, d = self.call("POST", "/v1/friends", {"code": b["code"]}, a["token"])
        self.assertEqual(code, 200)
        self.assertEqual(self.call("GET", "/v1/friends", token=b["token"])[1]["friends"][0]["name"], "Ana")
        targets = self.call("GET", "/v1/targets", token=a["token"])[1]["targets"]
        self.assertTrue(targets and targets[0]["friend"])
        # atac: primul e parat de scutul lui Bogdan, al doilea strică palatul
        r1 = self.call("POST", "/v1/attack", {"target_id": b["player_id"], "building": "palat"}, a["token"])[1]
        self.assertTrue(r1["blocked"])
        r2 = self.call("POST", "/v1/attack", {"target_id": b["player_id"], "building": "palat"}, a["token"])[1]
        self.assertFalse(r2["blocked"])
        self.assertEqual(r2["levels"]["palat"], 2)
        self.assertGreater(r2["coins"], 0)
        # jaf: 3 alegeri, apoi refuz
        self.assertEqual(self.call("POST", "/v1/raid/start", {"target_id": b["player_id"]}, a["token"])[0], 200)
        for i in range(3):
            self.assertEqual(self.call("POST", "/v1/raid/pick", {"cell": i}, a["token"])[0], 200)
        self.assertEqual(self.call("POST", "/v1/raid/pick", {"cell": 4}, a["token"])[0], 400)
        # cutia de mesaje a lui Bogdan
        msgs = self.call("GET", "/v1/inbox", token=b["token"])[1]["messages"]
        kinds = [m["kind"] for m in msgs]
        self.assertIn("attack", kinds)
        self.assertIn("raid", kinds)
        self.assertEqual(self.call("GET", "/v1/inbox", token=b["token"])[1]["messages"], [])
        # cadou de carte doar prietenilor
        self.assertEqual(self.call("POST", "/v1/cards/gift", {"to_id": b["player_id"], "card": "0:3"}, a["token"])[0], 200)
        c = self.player("device-cccc", "Cristi")
        self.assertEqual(self.call("POST", "/v1/cards/gift", {"to_id": b["player_id"], "card": "0:3"}, c["token"])[0], 403)
        # vizită și cadou zilnic (o dată pe zi)
        self.assertEqual(self.call("POST", "/v1/visit", {"target_id": b["player_id"]}, a["token"])[0], 200)
        self.assertEqual(self.call("POST", "/v1/gift", {"to_id": b["player_id"], "kind": "coins"}, a["token"])[0], 200)
        self.assertEqual(self.call("POST", "/v1/gift", {"to_id": b["player_id"], "kind": "coins"}, a["token"])[0], 429)
        msgs = self.call("GET", "/v1/inbox", token=b["token"])[1]["messages"]
        self.assertEqual(sorted(m["kind"] for m in msgs), ["card", "gift", "visit"])
        # echipe de 4
        for p in (a, b, c):
            self.assertEqual(self.call("POST", "/v1/team/join", token=p["token"])[0], 200)
        t = self.call("POST", "/v1/team/points", {"points": 30}, a["token"])[1]["team"]
        self.assertEqual(len(t["members"]), 3)
        self.assertEqual(t["points"], 30)
        # plăți: refuzate fără configurare
        self.assertEqual(self.call("POST", "/v1/iap/verify", {"product_id": "coins_small"}, a["token"])[0], 501)


if __name__ == "__main__":
    unittest.main()
