#!/usr/bin/env python3
from flask import Flask, jsonify, request, Response

app = Flask(__name__)

VAULT_B64 = (
    "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"
)

# Expected key: md5("3.0.5_1.4.63") = e0f5cd26417945188abe34673b9bee56
VALID_KEY = "e0f5cd26417945188abe34673b9bee56"

@app.after_request
def apply_server_header(response):
    response.headers["Server"] = "lighttpd/1.4.63"
    return response

@app.route('/')
def index():
    return Response(
        "<html><body><h1>CyberCorp Internal Developer Services</h1><p>Visit <a href='/dev_portal/'>Developer Portal</a></p></body></html>",
        mimetype="text/html"
    )

@app.route('/dev_portal/')
@app.route('/dev_portal/index.html')
def dev_portal():
    html_content = """<!DOCTYPE html>
<html>
<head>
    <title>CyberCorp Developer Portal</title>
</head>
<body>
    <h1>CyberCorp Internal Dev Portal v1.4</h1>
    <p>Welcome, Engineers. Ensure all services are version-matched before deployment.</p>
    <!-- DEV NOTE: Debug API endpoint active at /dev_portal/api/v1/vault. Requires query param key derive: md5(service_versions) where service_versions = vsftpd_version + "_" + lighttpd_version (e.g. 3.0.5_1.4.63) -->
    <ul>
        <li>FTP Server: Active (Port 21)</li>
        <li>SSH Server: Active (Port 2222)</li>
        <li>Admin Gateway: Active (Port 9001)</li>
    </ul>
</body>
</html>"""
    return Response(html_content, mimetype="text/html")

@app.route('/dev_portal/api/v1/vault')
def get_vault():
    user_key = request.args.get('key', '')
    if user_key.lower() == VALID_KEY:
        return jsonify({
            "status": "success",
            "message": "Vault key verified. Download encrypted payload.",
            "vault_b64": VAULT_B64
        })
    else:
        return jsonify({
            "status": "error",
            "message": "Invalid authorization key. Usage: ?key=md5(vsftpd_version + '_' + lighttpd_version)"
        }), 403

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
