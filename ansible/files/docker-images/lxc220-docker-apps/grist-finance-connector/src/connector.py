"""Minimal grist-finance-connector placeholder."""
import os
from flask import Flask, jsonify

app = Flask(__name__)

GRIST_BASE_URL = os.environ.get("GRIST_BASE_URL", "http://grist:8484")
DRY_RUN = os.environ.get("DRY_RUN", "true")
SOURCE_NAME = os.environ.get("SOURCE_NAME", "starling_bank")

@app.route("/health")
def health():
    return jsonify({"status": "ok", "source": SOURCE_NAME, "dry_run": DRY_RUN == "true"})

@app.route("/")
def index():
    return jsonify({"service": "grist-finance-connector", "version": os.environ.get("IMAGE_TAG", "0.1.0")})

@app.route("/sync", methods=["GET"])
def sync():
    return jsonify({"status": "sync complete", "dry_run": DRY_RUN == "true", "records": 0})

if __name__ == "__main__":
    app.run(host=os.environ.get("SERVICE_HOST", "0.0.0.0"),
            port=int(os.environ.get("SERVICE_PORT", "8080")))
