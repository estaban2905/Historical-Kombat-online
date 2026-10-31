"""Servidor falso con la forma de la API de Supabase, solo para pruebas locales.
Uso:  python tests/mock_supabase.py [puerto]     (por defecto 54329)
Imita: registro, login, refresh, logout y lectura de players, con los mismos
códigos de error que usa Supabase. POST /__expire invalida los access tokens
para probar la renovación automática de sesión.
"""
import json
import re
import sys
import uuid
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs

ANON_KEY = "test-anon-key"
users = {}          # email -> {id, password, username}
players = {}        # id -> fila de la tabla players
access_tokens = {}  # token -> user id
refresh_tokens = {} # token -> user id


def new_session(uid):
    access = "access-" + uuid.uuid4().hex
    refresh = "refresh-" + uuid.uuid4().hex
    access_tokens[access] = uid
    refresh_tokens[refresh] = uid
    email = next(e for e, u in users.items() if u["id"] == uid)
    return {"access_token": access, "refresh_token": refresh, "token_type": "bearer",
            "expires_in": 3600, "user": {"id": uid, "email": email}}


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def reply(self, code, body=None):
        raw = b"" if body is None else json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def error(self, code, error_code, msg):
        self.reply(code, {"code": code, "error_code": error_code, "msg": msg})

    def body(self):
        n = int(self.headers.get("Content-Length", 0))
        return json.loads(self.rfile.read(n) or b"{}")

    def bearer_user(self):
        auth = self.headers.get("Authorization", "")
        return access_tokens.get(auth.removeprefix("Bearer "))

    def do_POST(self):
        url = urlparse(self.path)
        if url.path == "/__expire":
            access_tokens.clear()
            return self.reply(200, {})
        if self.headers.get("apikey") != ANON_KEY:
            return self.reply(401, {"message": "No API key found in request"})
        data = self.body()
        if url.path == "/auth/v1/signup":
            email, pw = data.get("email", ""), data.get("password", "")
            name = (data.get("data") or {}).get("username", "")
            if len(pw) < 6:
                return self.error(422, "weak_password", "Password should be at least 6 characters.")
            if email in users:
                return self.error(422, "user_already_exists", "User already registered")
            if not re.fullmatch(r"[A-Za-z0-9_]{3,16}", name or "") or \
                    any(p["username"] == name for p in players.values()):
                return self.error(500, "unexpected_failure", "Database error saving new user")
            uid = str(uuid.uuid4())
            users[email] = {"id": uid, "password": pw}
            players[uid] = {"id": uid, "username": name, "points": 1000, "wins": 0, "losses": 0}
            return self.reply(200, new_session(uid))
        if url.path == "/auth/v1/token":
            grant = parse_qs(url.query).get("grant_type", [""])[0]
            if grant == "password":
                u = users.get(data.get("email", ""))
                if not u or u["password"] != data.get("password"):
                    return self.error(400, "invalid_credentials", "Invalid login credentials")
                return self.reply(200, new_session(u["id"]))
            if grant == "refresh_token":
                uid = refresh_tokens.pop(data.get("refresh_token", ""), None)
                if uid is None:
                    return self.error(400, "refresh_token_not_found", "Invalid Refresh Token")
                return self.reply(200, new_session(uid))
        if url.path == "/auth/v1/logout":
            return self.reply(204)
        self.reply(404, {"message": "not found"})

    def do_GET(self):
        url = urlparse(self.path)
        if self.headers.get("apikey") != ANON_KEY:
            return self.reply(401, {"message": "No API key found in request"})
        if url.path == "/rest/v1/players":
            uid = self.bearer_user()
            if uid is None:
                return self.reply(401, {"code": "PGRST301", "message": "JWT expired"})
            wanted = parse_qs(url.query).get("id", [""])[0].removeprefix("eq.")
            return self.reply(200, [players[wanted]] if wanted in players else [])
        self.reply(404, {"message": "not found"})


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 54329
    HTTPServer(("127.0.0.1", port), Handler).serve_forever()
