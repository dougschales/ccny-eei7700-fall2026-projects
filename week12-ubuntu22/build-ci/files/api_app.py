#!/usr/bin/env python3
"""
Ops CI API - deliberately vulnerable Flask REST API (Week 12 capstone).

Two-factor discovery gate before anything useful is reachable:
  - the correct tenant_id in the URL path (leaked via edge-web's LFI)
  - the correct X-Ops-Token header value (leaked via edge-web's SQLi)

Vulnerabilities, once both are known:
  - /api/projects/<tenant>/openapi.json          : spec disclosure of
                                                     unlinked admin routes
  - /api/projects/<tenant>/artifacts/<id>        : IDOR - no ownership
                                                     check on artifact reads
  - /api/projects/<tenant>/runners/me (PATCH)    : mass assignment - no
                                                     field allow-list, lets
                                                     a caller set their own
                                                     "role"
  - /api/projects/<tenant>/artifacts/<id>/download : broken function-level
                                                     authorization - trusts
                                                     the role the mass-
                                                     assignment bug forges
"""
import functools
import os

from flask import Flask, g, jsonify, request, send_from_directory, abort

app = Flask(__name__)

TENANT = "stage-7741"
VALID_TOKEN = "cibot_live_7f3a9c2e1d6b4f08"
ARTIFACT_DIR = "/opt/app/data/artifacts"

RUNNER = {"id": 1, "project": TENANT, "role": "viewer", "display_name": "ci-bot-01"}

ARTIFACTS = {
    1: {
        "id": 1,
        "name": "build-42881.log",
        "note": "Routine build log, nothing interesting.",
        "download": None,
    },
    2: {
        "id": 2,
        "name": "ci-runner-deploy-key-archive",
        "note": (
            "Archived outgoing deploy key for ci-runner during the last "
            "credential rotation window. "
            "FLAG{w12_4_idor_mass_assignment_artifact_leak}"
        ),
        "download": "ci_runner_deploy_key.pem.enc",
    },
    3: {
        "id": 3,
        "name": "build-42899.log",
        "note": "Routine build log, nothing interesting.",
        "download": None,
    },
}


def require_tenant(view):
    @functools.wraps(view)
    def wrapped(tenant, *args, **kwargs):
        if tenant != TENANT:
            abort(404)
        return view(*args, **kwargs)
    return wrapped


def require_auth(view):
    @functools.wraps(view)
    def wrapped(*args, **kwargs):
        token = request.headers.get("X-Ops-Token", "")
        if token != VALID_TOKEN:
            return jsonify({"error": "missing or invalid X-Ops-Token"}), 401
        g.runner = RUNNER
        return view(*args, **kwargs)
    return wrapped


def require_admin(view):
    @functools.wraps(view)
    @require_auth
    def wrapped(*args, **kwargs):
        if g.runner.get("role") != "admin":
            return jsonify({"error": "admin role required"}), 403
        return view(*args, **kwargs)
    return wrapped


@app.route("/")
def index():
    return jsonify({
        "service": "Ops CI API",
        "status": "ok",
        "docs": "/api/projects/<tenant_id>/openapi.json",
    })


@app.route("/api/projects/<tenant>/openapi.json")
@require_tenant
def openapi_spec(**_):
    return jsonify({
        "openapi": "3.0.0",
        "info": {"title": "Ops CI API", "version": "1.0.0"},
        "paths": {
            "/api/projects/{tenant}/runners/me": {
                "get": {"summary": "Get your own runner identity"},
                "patch": {"summary": "Update your own runner identity"},
            },
            "/api/projects/{tenant}/artifacts/{id}": {
                "get": {"summary": "Get a build artifact by id"}
            },
            "/api/projects/{tenant}/artifacts/{id}/download": {
                "get": {"summary": "Download an artifact (admin only)"}
            },
            "/api/projects/{tenant}/admin/runners": {
                "get": {"summary": "List all runners (admin only)"}
            },
        },
    })


@app.route("/api/projects/<tenant>/runners/me", methods=["GET"])
@require_tenant
@require_auth
def get_me(**_):
    return jsonify(g.runner)


@app.route("/api/projects/<tenant>/runners/me", methods=["PATCH"])
@require_tenant
@require_auth
def patch_me(**_):
    # VULNERABLE: mass assignment - every field in the request body is
    # merged straight into the runner record, no allow-list.
    data = request.get_json(silent=True) or {}
    RUNNER.update(data)
    return jsonify(RUNNER)


@app.route("/api/projects/<tenant>/artifacts/<int:aid>", methods=["GET"])
@require_tenant
@require_auth
def get_artifact(aid, **_):
    # VULNERABLE: IDOR - no check that this artifact belongs to the
    # caller's own project/runner.
    a = ARTIFACTS.get(aid)
    if not a:
        return jsonify({"error": "not found"}), 404
    return jsonify(a)


@app.route("/api/projects/<tenant>/artifacts/<int:aid>/download", methods=["GET"])
@require_tenant
@require_admin
def download_artifact(aid, **_):
    a = ARTIFACTS.get(aid)
    if not a or not a.get("download"):
        return jsonify({"error": "not found"}), 404
    return send_from_directory(ARTIFACT_DIR, a["download"], as_attachment=True)


@app.route("/api/projects/<tenant>/admin/runners", methods=["GET"])
@require_tenant
@require_admin
def admin_list_runners(**_):
    return jsonify({"runners": [RUNNER]})


if __name__ == "__main__":
    os.makedirs(ARTIFACT_DIR, exist_ok=True)
    app.run(host="0.0.0.0", port=8080)
