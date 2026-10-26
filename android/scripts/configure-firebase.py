#!/usr/bin/env python3
"""Convert downloaded public Firebase app config to release runtime config.

Download google-services.json using Firebase CLI first. This script never
reads service-account credentials and never prints the API key.
"""
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
source = json.loads((root / "app/google-services.json").read_text())
client = next(c for c in source["client"] if c["client_info"]["android_client_info"]["package_name"] == "com.damianomiazzi.mymoney")
target = root / "app/src/main/assets/firebase-config.json"
target.parent.mkdir(parents=True, exist_ok=True)
target.write_text(json.dumps({
    "projectId": source["project_info"]["project_id"],
    "appId": client["client_info"]["mobilesdk_app_id"],
    "apiKey": client["api_key"][0]["current_key"],
    "emulator": False,
}, indent=2) + "\n")
print("Local release Firebase configuration prepared; debug still uses the emulator.")
