"""Общие функции для скриптов настройки PocketBase (только стандартная библиотека)."""
import json
import os
import urllib.error
import urllib.request

BASE = os.environ.get("PB_URL", "http://127.0.0.1:8090")
SUPER_EMAIL = os.environ.get("PB_SUPER_EMAIL", "root@shop.local")
SUPER_PASSWORD = os.environ.get("PB_SUPER_PASSWORD", "RootPass#2026")

_token = None


def call(method, path, body=None, token=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", token)
    try:
        with urllib.request.urlopen(req) as r:
            raw = r.read()
            return json.loads(raw) if raw else None
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"{method} {path} -> {e.code}: {e.read().decode()}")


def superuser_token():
    global _token
    if _token is None:
        r = call(
            "POST",
            "/api/collections/_superusers/auth-with-password",
            {"identity": SUPER_EMAIL, "password": SUPER_PASSWORD},
        )
        _token = r["token"]
    return _token


def admin(method, path, body=None):
    return call(method, path, body, superuser_token())
