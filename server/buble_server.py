#!/usr/bin/env python3
"""Serverul Buble – backend gratuit, fără dependențe (Python 3.10+, doar biblioteca standard).

Pornire:
    python3 server/buble_server.py --port 8080 --db buble.db

Toate răspunsurile sunt JSON. Autentificare: antetul `Authorization: Bearer <token>`
primit la /v1/auth. Vezi server/README.md pentru lista completă de rute.
"""
import argparse
import json
import os
import random
import secrets
import sqlite3
import string
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

BUILDINGS = ["palat", "obs", "turn", "mag", "sera"]
MAX_LVL = 5
TEAM_SIZE = 4
RATE_LIMIT_PER_MIN = 240

SCHEMA = """
CREATE TABLE IF NOT EXISTS players (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id TEXT UNIQUE NOT NULL,
    token TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    code TEXT UNIQUE NOT NULL,
    island INTEGER NOT NULL DEFAULT 1,
    levels TEXT NOT NULL DEFAULT '{}',
    shields INTEGER NOT NULL DEFAULT 0,
    coins INTEGER NOT NULL DEFAULT 0,
    save TEXT,
    last_seen REAL NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS friends (a INTEGER NOT NULL, b INTEGER NOT NULL, PRIMARY KEY (a, b));
CREATE TABLE IF NOT EXISTS inbox (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    player INTEGER NOT NULL,
    kind TEXT NOT NULL,
    data TEXT NOT NULL,
    created REAL NOT NULL
);
CREATE TABLE IF NOT EXISTS teams (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    week TEXT NOT NULL,
    points INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS team_members (
    team INTEGER NOT NULL,
    player INTEGER NOT NULL,
    points INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (team, player)
);
CREATE TABLE IF NOT EXISTS raids (
    player INTEGER PRIMARY KEY,
    target INTEGER NOT NULL,
    cells TEXT NOT NULL,
    picked TEXT NOT NULL DEFAULT '[]',
    created REAL NOT NULL
);
"""


def week_id(t=None):
    import datetime
    y, w, _ = datetime.date.fromtimestamp(t or time.time()).isocalendar()
    return f"{y}-W{w:02d}"


def unit(island, levels):
    s = sum(levels.get(b, 1) for b in BUILDINGS)
    return round(20 * island * (1 + 0.04 * (s - 5)))


class Store:
    """Acces la baza de date SQLite (un singur fișier), protejat cu un lacăt."""

    def __init__(self, path):
        self.db = sqlite3.connect(path, check_same_thread=False)
        self.db.row_factory = sqlite3.Row
        self.db.executescript(SCHEMA)
        self.lock = threading.Lock()

    def q(self, sql, args=(), one=False):
        with self.lock:
            cur = self.db.execute(sql, args)
            self.db.commit()
            rows = cur.fetchall()
            return (rows[0] if rows else None) if one else rows

    def x(self, sql, args=()):
        with self.lock:
            cur = self.db.execute(sql, args)
            self.db.commit()
            return cur.lastrowid


def public(p):
    return {
        "id": p["id"], "name": p["name"], "island": p["island"],
        "levels": json.loads(p["levels"] or "{}"), "shields": p["shields"],
        "online": time.time() - p["last_seen"] < 300,
    }


def new_code(store):
    alphabet = string.ascii_uppercase.replace("O", "").replace("I", "") + "23456789"
    while True:
        c = "".join(random.choice(alphabet) for _ in range(6))
        if not store.q("SELECT 1 FROM players WHERE code=?", (c,), one=True):
            return c


class Api:
    def __init__(self, store):
        self.store = store
        self.hits = {}

    # ---------- utilitare ----------
    def rate_ok(self, key):
        now = time.time()
        lst = [t for t in self.hits.get(key, []) if now - t < 60]
        lst.append(now)
        self.hits[key] = lst
        return len(lst) <= RATE_LIMIT_PER_MIN

    def me(self, token):
        if not token:
            return None
        p = self.store.q("SELECT * FROM players WHERE token=?", (token,), one=True)
        if p:
            self.store.x("UPDATE players SET last_seen=? WHERE id=?", (time.time(), p["id"]))
        return p

    def notify(self, player, kind, data):
        self.store.x("INSERT INTO inbox (player, kind, data, created) VALUES (?,?,?,?)", (player, kind, json.dumps(data), time.time()))

    # ---------- rute ----------
    def auth(self, body, _p):
        dev = str(body.get("device_id", "")).strip()
        if len(dev) < 8:
            return 400, {"error": "device_id lipsă"}
        name = str(body.get("name") or "Jucător")[:24]
        p = self.store.q("SELECT * FROM players WHERE device_id=?", (dev,), one=True)
        if not p:
            tok = secrets.token_urlsafe(24)
            self.store.x("INSERT INTO players (device_id, token, name, code, levels, last_seen) VALUES (?,?,?,?,?,?)",
                         (dev, tok, name, new_code(self.store), json.dumps({b: 1 for b in BUILDINGS}), time.time()))
            p = self.store.q("SELECT * FROM players WHERE device_id=?", (dev,), one=True)
        return 200, {"player_id": p["id"], "token": p["token"], "code": p["code"], "name": p["name"]}

    def get_me(self, _b, p):
        out = public(p)
        out["code"] = p["code"]
        return 200, out

    def put_island(self, body, p):
        levels = {b: max(1, min(MAX_LVL, int(body.get("levels", {}).get(b, 1)))) for b in BUILDINGS}
        self.store.x("UPDATE players SET island=?, levels=?, shields=?, coins=?, name=? WHERE id=?",
                     (max(1, int(body.get("island", 1))), json.dumps(levels), max(0, min(3, int(body.get("shields", 0)))),
                      max(0, int(body.get("coins", 0))), str(body.get("name") or p["name"])[:24], p["id"]))
        return 200, {"ok": True}

    def put_save(self, body, p):
        data = body.get("data")
        if not isinstance(data, dict) or len(json.dumps(data)) > 200_000:
            return 400, {"error": "salvare invalidă"}
        self.store.x("UPDATE players SET save=? WHERE id=?", (json.dumps(data), p["id"]))
        return 200, {"ok": True}

    def get_save(self, _b, p):
        return 200, {"data": json.loads(p["save"]) if p["save"] else None}

    def add_friend(self, body, p):
        code = str(body.get("code", "")).strip().upper()
        f = self.store.q("SELECT * FROM players WHERE code=?", (code,), one=True)
        if not f or f["id"] == p["id"]:
            return 404, {"error": "cod necunoscut"}
        self.store.x("INSERT OR IGNORE INTO friends (a, b) VALUES (?,?)", (p["id"], f["id"]))
        self.store.x("INSERT OR IGNORE INTO friends (a, b) VALUES (?,?)", (f["id"], p["id"]))
        self.notify(f["id"], "friend", {"from": p["name"]})
        return 200, {"friend": public(f)}

    def list_friends(self, _b, p):
        rows = self.store.q("SELECT pl.* FROM friends fr JOIN players pl ON pl.id = fr.b WHERE fr.a=?", (p["id"],))
        return 200, {"friends": [public(r) for r in rows]}

    def targets(self, _b, p):
        """Ținte pentru atac/jaf: prieteni întâi, apoi jucători activi recent (doar jucători reali)."""
        fr = self.store.q("SELECT pl.* FROM friends fr JOIN players pl ON pl.id = fr.b WHERE fr.a=?", (p["id"],))
        others = self.store.q("SELECT * FROM players WHERE id<>? AND last_seen>? ORDER BY RANDOM() LIMIT 10",
                              (p["id"], time.time() - 7 * 86400))
        fr_ids = {r["id"] for r in fr}
        seen, out = set(), []
        for r in list(fr) + list(others):
            if r["id"] not in seen:
                seen.add(r["id"])
                out.append(public(r) | {"friend": r["id"] in fr_ids})
        return 200, {"targets": out}

    def attack(self, body, p):
        t = self.store.q("SELECT * FROM players WHERE id=?", (int(body.get("target_id", 0)),), one=True)
        b = body.get("building")
        if not t or t["id"] == p["id"] or b not in BUILDINGS:
            return 400, {"error": "țintă invalidă"}
        mult = max(1, min(20, int(body.get("mult", 1))))
        my_levels = json.loads(p["levels"])
        u = unit(p["island"], my_levels) * mult
        levels = json.loads(t["levels"])
        blocked = t["shields"] > 0
        if blocked:
            self.store.x("UPDATE players SET shields=shields-1 WHERE id=?", (t["id"],))
            reward = u * 3
        else:
            levels[b] = max(1, levels.get(b, 1) - 1)
            self.store.x("UPDATE players SET levels=? WHERE id=?", (json.dumps(levels), t["id"]))
            reward = u * 8
        self.notify(t["id"], "attack", {"from": p["name"], "building": b, "blocked": blocked, "level": levels.get(b, 1)})
        return 200, {"blocked": blocked, "coins": reward, "levels": levels}

    def raid_start(self, body, p):
        t = self.store.q("SELECT * FROM players WHERE id=?", (int(body.get("target_id", 0)),), one=True)
        if not t or t["id"] == p["id"]:
            return 400, {"error": "țintă invalidă"}
        mult = max(1, min(20, int(body.get("mult", 1))))
        u = unit(p["island"], json.loads(p["levels"])) * mult
        cells = [u * random.randint(6, 10) for _ in range(3)] + [u * random.randint(2, 4) for _ in range(3)] + [0, 0, 0]
        random.shuffle(cells)
        self.store.x("INSERT OR REPLACE INTO raids (player, target, cells, picked, created) VALUES (?,?,?,?,?)",
                     (p["id"], t["id"], json.dumps(cells), "[]", time.time()))
        return 200, {"target": public(t), "cells": 9}

    def raid_pick(self, body, p):
        r = self.store.q("SELECT * FROM raids WHERE player=?", (p["id"],), one=True)
        if not r:
            return 400, {"error": "niciun jaf început"}
        cells, picked = json.loads(r["cells"]), json.loads(r["picked"])
        i = int(body.get("cell", -1))
        if i < 0 or i >= 9 or i in picked or len(picked) >= 3:
            return 400, {"error": "alegere invalidă"}
        picked.append(i)
        self.store.x("UPDATE raids SET picked=? WHERE player=?", (json.dumps(picked), p["id"]))
        v = cells[i]
        if len(picked) == 3:
            total = sum(cells[k] for k in picked)
            self.notify(r["target"], "raid", {"from": p["name"], "coins": total})
            self.store.x("DELETE FROM raids WHERE player=?", (p["id"],))
        return 200, {"value": v, "picked": len(picked)}

    def inbox(self, _b, p):
        rows = self.store.q("SELECT * FROM inbox WHERE player=? ORDER BY id", (p["id"],))
        self.store.x("DELETE FROM inbox WHERE player=?", (p["id"],))
        return 200, {"messages": [{"kind": r["kind"], "data": json.loads(r["data"]), "time": r["created"]} for r in rows]}

    def gift_card(self, body, p):
        to = int(body.get("to_id", 0))
        if not self.store.q("SELECT 1 FROM friends WHERE a=? AND b=?", (p["id"], to), one=True):
            return 403, {"error": "doar prietenilor"}
        card = str(body.get("card", ""))
        if not card or len(card) > 16:
            return 400, {"error": "carte invalidă"}
        self.notify(to, "card", {"from": p["name"], "card": card})
        return 200, {"ok": True}

    def team_join(self, _b, p):
        wk = week_id()
        row = self.store.q("SELECT tm.team FROM team_members tm JOIN teams t ON t.id = tm.team WHERE tm.player=? AND t.week=?", (p["id"], wk), one=True)
        if row:
            return self.team_get(None, p)
        open_team = self.store.q(
            "SELECT t.id FROM teams t LEFT JOIN team_members m ON m.team = t.id WHERE t.week=? GROUP BY t.id HAVING COUNT(m.player) < ? LIMIT 1",
            (wk, TEAM_SIZE), one=True)
        tid = open_team["id"] if open_team else self.store.x("INSERT INTO teams (week) VALUES (?)", (wk,))
        self.store.x("INSERT INTO team_members (team, player) VALUES (?,?)", (tid, p["id"]))
        return self.team_get(None, p)

    def team_points(self, body, p):
        pts = max(0, min(1000, int(body.get("points", 0))))
        row = self.store.q("SELECT tm.team FROM team_members tm JOIN teams t ON t.id = tm.team WHERE tm.player=? AND t.week=?", (p["id"], week_id()), one=True)
        if not row:
            return 400, {"error": "nu ești într-o echipă"}
        self.store.x("UPDATE team_members SET points = points + ? WHERE team=? AND player=?", (pts, row["team"], p["id"]))
        self.store.x("UPDATE teams SET points = points + ? WHERE id=?", (pts, row["team"]))
        return self.team_get(None, p)

    def team_get(self, _b, p):
        row = self.store.q("SELECT t.* FROM team_members tm JOIN teams t ON t.id = tm.team WHERE tm.player=? AND t.week=?", (p["id"], week_id()), one=True)
        if not row:
            return 200, {"team": None}
        members = self.store.q("SELECT pl.name, tm.points FROM team_members tm JOIN players pl ON pl.id = tm.player WHERE tm.team=?", (row["id"],))
        return 200, {"team": {"id": row["id"], "week": row["week"], "points": row["points"], "goal": 2000,
                               "members": [{"name": m["name"], "points": m["points"]} for m in members]}}

    def iap_verify(self, body, p):
        # Verificarea reală se face cu Google Play Developer API (purchases.products.get)
        # folosind un cont de serviciu. Fără configurare, serverul refuză să acorde bunuri.
        if not os.environ.get("BUBLE_GOOGLE_SERVICE_ACCOUNT"):
            return 501, {"ok": False, "reason": "verificarea plăților nu este configurată"}
        return 501, {"ok": False, "reason": "neimplementat"}

    ROUTES = {
        ("POST", "/v1/auth"): ("auth", False),
        ("GET", "/v1/me"): ("get_me", True),
        ("PUT", "/v1/island"): ("put_island", True),
        ("PUT", "/v1/save"): ("put_save", True),
        ("GET", "/v1/save"): ("get_save", True),
        ("POST", "/v1/friends"): ("add_friend", True),
        ("GET", "/v1/friends"): ("list_friends", True),
        ("GET", "/v1/targets"): ("targets", True),
        ("POST", "/v1/attack"): ("attack", True),
        ("POST", "/v1/raid/start"): ("raid_start", True),
        ("POST", "/v1/raid/pick"): ("raid_pick", True),
        ("GET", "/v1/inbox"): ("inbox", True),
        ("POST", "/v1/cards/gift"): ("gift_card", True),
        ("POST", "/v1/team/join"): ("team_join", True),
        ("POST", "/v1/team/points"): ("team_points", True),
        ("GET", "/v1/team"): ("team_get", True),
        ("POST", "/v1/iap/verify"): ("iap_verify", True),
    }

    def handle(self, method, path, body, token, ip):
        if path == "/health":
            return 200, {"ok": True, "name": "buble", "version": 1}
        route = self.ROUTES.get((method, path.split("?")[0]))
        if not route:
            return 404, {"error": "rută necunoscută"}
        if not self.rate_ok(token or ip):
            return 429, {"error": "prea multe cereri"}
        fn, needs_auth = route
        p = self.me(token) if needs_auth else None
        if needs_auth and not p:
            return 401, {"error": "neautentificat"}
        try:
            return getattr(self, fn)(body or {}, p)
        except (ValueError, TypeError, KeyError) as e:
            return 400, {"error": f"cerere invalidă: {e}"}


def make_handler(api):
    class H(BaseHTTPRequestHandler):
        server_version = "Buble/1"

        def _send(self, code, obj):
            data = json.dumps(obj, ensure_ascii=False).encode()
            self.send_response(code)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def _do(self, method):
            n = int(self.headers.get("Content-Length") or 0)
            if n > 256_000:
                return self._send(413, {"error": "cerere prea mare"})
            body = None
            if n:
                try:
                    body = json.loads(self.rfile.read(n) or b"{}")
                except json.JSONDecodeError:
                    return self._send(400, {"error": "JSON invalid"})
            auth = self.headers.get("Authorization", "")
            token = auth[7:] if auth.startswith("Bearer ") else ""
            code, obj = api.handle(method, self.path, body, token, self.client_address[0])
            self._send(code, obj)

        def do_GET(self):
            self._do("GET")

        def do_POST(self):
            self._do("POST")

        def do_PUT(self):
            self._do("PUT")

        def log_message(self, fmt, *args):
            pass

    return H


def serve(port=8080, db="buble.db", host="0.0.0.0"):
    api = Api(Store(db))
    srv = ThreadingHTTPServer((host, port), make_handler(api))
    return srv


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description="Serverul Buble")
    ap.add_argument("--port", type=int, default=8080)
    ap.add_argument("--db", default="buble.db")
    ap.add_argument("--host", default="0.0.0.0")
    a = ap.parse_args()
    srv = serve(a.port, a.db, a.host)
    print(f"Buble server pe http://{a.host}:{a.port}  (baza de date: {a.db})")
    srv.serve_forever()
