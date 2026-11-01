import json
import os
import sys
from datetime import datetime, timezone

version, ipa_path, notes_path, out_path = sys.argv[1:5]
repo = os.environ.get("GITHUB_REPOSITORY", "OnlineKot/BlueTools")
base = f"https://github.com/{repo}/releases"
size = os.path.getsize(ipa_path)
notes = open(notes_path, encoding="utf-8").read().strip() if os.path.exists(notes_path) else ""
date = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
icon = f"{base}/latest/download/icon.png"
ipa = f"{base}/download/v{version}/BlueTools.ipa"
tint = "266EF5"

description = (
    "Skaner Bluetooth LE na iPhone'a. Pokazuje urządzenia w pobliżu, pozwala się z nimi połączyć, "
    "czytać i zapisywać charakterystyki, a w trybie szukania prowadzi do zgubionej słuchawki albo kluczy. "
    "Otwarty kod, bez reklam i bez analityki."
)

source = {
    "name": "BlueTools",
    "identifier": "io.github.onlinekot.bluetools.source",
    "subtitle": "Narzędzia Bluetooth LE na iPhone'a",
    "description": description,
    "iconURL": icon,
    "headerURL": f"{base}/latest/download/banner.png",
    "website": f"https://github.com/{repo}",
    "tintColor": tint,
    "featuredApps": ["io.github.onlinekot.bluetools"],
    "apps": [
        {
            "name": "BlueTools",
            "bundleIdentifier": "io.github.onlinekot.bluetools",
            "developerName": "OnlineKot",
            "subtitle": "Skaner i tester Bluetooth LE",
            "localizedDescription": description,
            "iconURL": icon,
            "tintColor": tint,
            "category": "utilities",
            "screenshots": [],
            "version": version,
            "versionDate": date,
            "versionDescription": notes,
            "downloadURL": ipa,
            "size": size,
            "versions": [
                {
                    "version": version,
                    "buildVersion": os.environ.get("BUILD_NUMBER", "1"),
                    "date": date,
                    "localizedDescription": notes,
                    "downloadURL": ipa,
                    "size": size,
                    "minOSVersion": "16.0",
                }
            ],
            "appPermissions": {
                "entitlements": [],
                "privacy": {
                    "NSBluetoothAlwaysUsageDescription": "BlueTools potrzebuje Bluetooth, żeby znaleźć urządzenia w pobliżu i się z nimi połączyć."
                },
            },
        }
    ],
    "news": [],
}

with open(out_path, "w", encoding="utf-8") as handle:
    json.dump(source, handle, ensure_ascii=False, indent=2)
