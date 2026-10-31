#!/usr/bin/env python3
"""
HelpDesk API - deliberately vulnerable Flask REST API.

Vulnerabilities (Week 9: API Security & Business Logic Flaws):
  - /api/openapi.json         : API spec disclosure of unlinked admin routes
  - /api/tickets/<id>         : BOLA/IDOR - no ownership check on ticket reads
  - /api/users/me (PATCH)     : mass assignment - no field allow-list, lets a
                                 caller set their own "role"
  - /api/tickets/<id>/attachment : broken function-level authorization - the
                                 admin-only check is correct, but it trusts a
                                 "role" the mass-assignment bug lets you forge
"""
import functools
import os
import secrets

from flask import Flask, g, jsonify, request, send_from_directory

app = Flask(__name__)

ATTACHMENT_DIR = "/opt/app/data/attachments"

USERS = {
    1: {
        "id": 1,
        "username": "alice",
        "password": "Welcome2026!",
        "role": "user",
        "full_name": "Alice Chen",
        "dept": "Support",
    },
    2: {
        "id": 2,
        "username": "bob",
        "password": "Summer2024",
        "role": "user",
        "full_name": "Bob Alvarez",
        "dept": "Infrastructure",
    },
    3: {
        "id": 3,
        "username": "admin",
        "password": "R00tAccess!2026",
        "role": "admin",
        "full_name": "System Administrator",
        "dept": "IT",
    },
}

TICKETS = {
    1: {
        "id": 1,
        "owner_id": 1,
        "title": "Can't connect to printer",
        "body": "My desk printer on the 3rd floor isn't responding, can someone check the queue?",
        "attachment": None,
    },
    2: {
        "id": 2,
        "owner_id": 2,
        "title": "VPN service key rotation - archive old key",
        "body": (
            "Rotating the opskey VPN service account key per policy. Archiving the "
            "outgoing private key here until the new one is confirmed in prod. "
            "FLAG{bola_idor_cross_tenant_ticket_read}"
        ),
        "attachment": "vpn_key_rotation.pem",
    },
    3: {
        "id": 3,
        "owner_id": 1,
        "title": "Need access to shared drive",
        "body": "Requesting read access to the \\\\fileserver\\shared drive for the new hire.",
        "attachment": None,
    },
}

# token -> user_id
TOKENS = {}


def user_by_username(username):
    for u in USERS.values():
        if u["username"] == username:
            return u
    return None


def require_auth(view):
    @functools.wraps(view)
    def wrapped(*args, **kwargs):
        auth = request.headers.get("Authorization", "")
        if not auth.startswith("Bearer "):
            return jsonify({"error": "missing bearer token"}), 401
        token = auth[len("Bearer "):]
        uid = TOKENS.get(token)
        if uid is None:
            return jsonify({"error": "invalid or expired token"}), 401
        g.uid = uid
        g.user = USERS[uid]
        return view(*args, **kwargs)
    return wrapped


def require_admin(view):
    @functools.wraps(view)
    @require_auth
    def wrapped(*args, **kwargs):
        if g.user.get("role") != "admin":
            return jsonify({"error": "admin role required"}), 403
        return view(*args, **kwargs)
    return wrapped


def public_profile(u):
    return {
        "id": u["id"],
        "username": u["username"],
        "role": u["role"],
        "full_name": u["full_name"],
        "dept": u["dept"],
    }


@app.route("/")
def index():
    return jsonify({
        "service": "HelpDesk API",
        "status": "ok",
        "docs": "/api/openapi.json",
    })


@app.route("/api/openapi.json")
def openapi_spec():
    # MISCONFIGURATION: the full route map, including admin-only endpoints
    # that are never linked from any UI, is published here unauthenticated.
    return jsonify({
        "openapi": "3.0.0",
        "info": {
            "title": "HelpDesk API",
            "version": "1.0.0",
            "x-discovery-note": "FLAG{api_endpoint_discovery_openapi_leak}",
        },
        "paths": {
            "/api/login": {"post": {"summary": "Obtain a bearer token"}},
            "/api/users/me": {
                "get": {"summary": "Get your own profile"},
                "patch": {"summary": "Update your own profile"},
            },
            "/api/tickets": {"get": {"summary": "List your own tickets"}},
            "/api/tickets/{id}": {"get": {"summary": "Get a ticket by id"}},
            "/api/tickets/{id}/attachment": {
                "get": {"summary": "Download a ticket's attachment (admin only)"}
            },
            "/api/admin/users": {
                "get": {"summary": "List all users (admin only)"}
            },
        },
    })


@app.route("/api/login", methods=["POST"])
def login():
    data = request.get_json(silent=True) or {}
    username = data.get("username", "")
    password = data.get("password", "")
    u = user_by_username(username)
    if not u or u["password"] != password:
        return jsonify({"error": "invalid credentials"}), 401
    token = secrets.token_hex(16)
    TOKENS[token] = u["id"]
    return jsonify({"token": token})


@app.route("/api/users/me", methods=["GET"])
@require_auth
def get_me():
    return jsonify(public_profile(g.user))


@app.route("/api/users/me", methods=["PATCH"])
@require_auth
def patch_me():
    # VULNERABLE: mass assignment. Every field the client sends is merged
    # straight into the user record with no allow-list, so a caller can
    # hand themselves {"role": "admin"} along with any legitimate field
    # (e.g. "full_name") they meant to update.
    data = request.get_json(silent=True) or {}
    USERS[g.uid].update(data)
    return jsonify(public_profile(USERS[g.uid]))


@app.route("/api/tickets", methods=["GET"])
@require_auth
def list_tickets():
    mine = [t for t in TICKETS.values() if t["owner_id"] == g.uid]
    return jsonify(mine)


@app.route("/api/tickets/<int:tid>", methods=["GET"])
@require_auth
def get_ticket(tid):
    # VULNERABLE: BOLA/IDOR. Looks the ticket up by id alone - never checks
    # that owner_id == g.uid, so any authenticated user can read any
    # other user's ticket just by guessing/incrementing the id.
    t = TICKETS.get(tid)
    if not t:
        return jsonify({"error": "not found"}), 404
    return jsonify(t)


@app.route("/api/tickets/<int:tid>/attachment", methods=["GET"])
@require_admin
def get_attachment(tid):
    # The admin check here is correctly implemented - the bug is upstream:
    # patch_me() lets a caller forge the "role" this check trusts.
    t = TICKETS.get(tid)
    if not t or not t.get("attachment"):
        return jsonify({"error": "not found"}), 404
    return send_from_directory(ATTACHMENT_DIR, t["attachment"], as_attachment=True)


@app.route("/api/admin/users", methods=["GET"])
@require_admin
def admin_list_users():
    return jsonify({
        "flag": "FLAG{mass_assignment_role_escalation}",
        "users": [public_profile(u) for u in USERS.values()],
    })


if __name__ == "__main__":
    os.makedirs(ATTACHMENT_DIR, exist_ok=True)
    app.run(host="0.0.0.0", port=8080)
