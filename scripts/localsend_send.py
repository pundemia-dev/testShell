#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
#
# Send a single file to a LocalSend device.
# Usage: localsend_send.py <file> <target-ip>

import sys, os, json, ssl, hashlib, subprocess, mimetypes
from urllib import request

PORT = 53317


def notify(body, icon="emblem-ok-symbolic"):
    try:
        subprocess.Popen(["notify-send", "LocalSend", body, "-i", icon])
    except Exception:
        pass


def die(msg):
    notify(msg, "dialog-error")
    sys.exit(1)


if len(sys.argv) < 3:
    die("Usage: localsend_send.py <file> <target-ip>")

FILE = sys.argv[1]
TARGET = sys.argv[2]

if not FILE or not os.path.isfile(FILE):
    die("File not found")
if not TARGET:
    die("No target device specified")

FILENAME = os.path.basename(FILE)
FILESIZE = os.path.getsize(FILE)
try:
    FILETYPE = subprocess.check_output(
        ["file", "-b", "--mime-type", FILE], text=True).strip()
except Exception:
    FILETYPE = mimetypes.guess_type(FILE)[0] or "application/octet-stream"
FILE_ID = "ps_" + hashlib.md5(os.urandom(16)).hexdigest()[:8]

# Identity fingerprint = SHA-256 of our TLS cert (shared with the receive
# server in ~/.cache/pshell_localsend). Generated on demand if absent so
# sending works even when the receive server has never run.
CACHE_DIR = os.path.expanduser("~/.cache/pshell_localsend")
CERT = os.path.join(CACHE_DIR, "cert.pem")
KEY = os.path.join(CACHE_DIR, "key.pem")
if not (os.path.exists(CERT) and os.path.exists(KEY)):
    os.makedirs(CACHE_DIR, exist_ok=True)
    subprocess.run([
        "openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes",
        "-keyout", KEY, "-out", CERT, "-days", "3650", "-subj", "/CN=pShell Stash",
    ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
with open(CERT) as _cf:
    FINGERPRINT = hashlib.sha256(ssl.PEM_cert_to_DER_cert(_cf.read())).hexdigest()

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE


def post(path, data, headers, timeout):
    req = request.Request(f"https://{TARGET}:{PORT}{path}", data=data,
                          headers=headers, method="POST")
    return request.urlopen(req, timeout=timeout, context=ctx)


body = json.dumps({
    "info": {
        "alias": "pShell Stash",
        "version": "2.1",
        "deviceModel": "pShell",
        "deviceType": "desktop",
        "fingerprint": FINGERPRINT,
        "port": PORT,
        "protocol": "https",
        "download": False,
    },
    "files": {
        FILE_ID: {
            "id": FILE_ID,
            "fileName": FILENAME,
            "size": FILESIZE,
            "fileType": FILETYPE,
            "sha256": None,
            "preview": None,
            "metadata": None,
        }
    },
}).encode()

try:
    resp = post("/api/localsend/v2/prepare-upload", body,
                {"Content-Type": "application/json"}, 30)
    prep = json.loads(resp.read().decode())
except Exception:
    die("Rejected or timed out")

SESSION = prep.get("sessionId", "")
TOKEN = prep.get("files", {}).get(FILE_ID, "")
if not SESSION or not TOKEN:
    die("Rejected or timed out")

try:
    with open(FILE, "rb") as f:
        post(f"/api/localsend/v2/upload?sessionId={SESSION}&fileId={FILE_ID}&token={TOKEN}",
             f.read(), {"Content-Type": FILETYPE}, 120)
    notify(f"Sent: {FILENAME}")
except Exception:
    die("Upload failed")
