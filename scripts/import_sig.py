import json
import os
import re
import sys

src, out = sys.argv[1], sys.argv[2]

SUFFIXES = [
    r",? Inc\.?$", r",? Incorporated$", r",? Ltd\.?$", r",? Limited$", r",? LLC$", r",? L\.L\.C\.$",
    r",? Co\.,? ?Ltd\.?$", r",? Co\.$", r",? Corp\.?$", r",? Corporation$", r",? GmbH( & Co\. KG)?$",
    r",? AG$", r",? ASA$", r",? AS$", r",? A/S$", r",? AB( \(publ\))?$", r",? Oy$", r",? S\.A\.$", r",? SA$",
    r",? S\.p\.A\.$", r",? SpA$", r",? B\.V\.$", r",? BV$", r",? N\.V\.$", r",? Pty\.? Ltd\.?$", r",? PLC$",
    r",? plc$", r",? K\.K\.$", r",? SAS$", r",? S\.A\.S\.$", r",? s\.r\.o\.$", r",? Sp\. z o\.o\.$",
    r",? Holding(s)?$", r",? Group$", r",? International$",
]

OVERRIDES = {
    0x004C: "Apple", 0x0006: "Microsoft", 0x0075: "Samsung", 0x00E0: "Google", 0x0059: "Nordic",
    0x038F: "Xiaomi", 0x027D: "Huawei", 0x0171: "Amazon", 0x0087: "Garmin", 0x009E: "Bose",
    0x0057: "Harman", 0x012D: "Sony", 0x00C4: "LG", 0x01DA: "Logitech", 0x0499: "Ruuvi",
    0x0157: "Huami", 0x022B: "Tesla", 0x02E5: "Espressif", 0x000D: "Texas Instruments",
    0x000F: "Broadcom", 0x000A: "Qualcomm", 0x001D: "Qualcomm", 0x0002: "Intel", 0x0046: "MediaTek",
    0x005D: "Realtek", 0x02FF: "Silicon Labs", 0x0030: "STMicro", 0x0131: "Cypress", 0x00D2: "Dialog",
    0x006B: "Polar", 0x05A7: "Sonos", 0x0078: "Nike", 0x0065: "HP", 0x0001: "Nokia", 0x0118: "Radius Networks",
}


def clean(name):
    name = name.strip()
    for _ in range(3):
        for pattern in SUFFIXES:
            name = re.sub(pattern, "", name, flags=re.I).strip().rstrip(",").strip()
    if name.isupper() and len(name) > 5:
        name = " ".join(w if len(w) <= 3 else w.capitalize() for w in name.split())
    return name


def entries(path, key):
    text = open(path, encoding="utf-8").read()
    pattern = re.compile(r"-\s*(?:uuid|value):\s*(0x[0-9A-Fa-f]+)\s*\n\s*name:\s*'?\"?(.*?)'?\"?\s*\n", re.M)
    return [(int(v, 16), n.replace("''", "'")) for v, n in pattern.findall(text)]


companies = {}
for value, name in entries(os.path.join(src, "company_identifiers.yaml"), "value"):
    companies[str(value)] = OVERRIDES.get(value, clean(name))

services = {}
for value, name in entries(os.path.join(src, "service_uuids.yaml"), "uuid"):
    services[f"{value:04X}"] = name
for value, name in entries(os.path.join(src, "member_uuids.yaml"), "uuid"):
    services.setdefault(f"{value:04X}", clean(name))

characteristics = {}
for value, name in entries(os.path.join(src, "characteristic_uuids.yaml"), "uuid"):
    characteristics[f"{value:04X}"] = name

extra_services = {
    "6E400001-B5A3-F393-E0A9-E50E24DCCA9E": "Nordic UART",
    "0000FFE0-0000-1000-8000-00805F9B34FB": "Serial (HM-10)",
    "FFE0": "Serial (HM-10)",
    "FE2C": "Google Fast Pair",
    "FD6F": "Exposure Notifications",
    "FEAA": "Eddystone",
    "FD5A": "Samsung SmartTag",
    "FEED": "Tile",
    "FEEC": "Tile",
    "FE95": "Xiaomi MiBeacon",
}
extra_chars = {
    "6E400002-B5A3-F393-E0A9-E50E24DCCA9E": "UART RX",
    "6E400003-B5A3-F393-E0A9-E50E24DCCA9E": "UART TX",
    "FFE1": "Serial data (HM-10)",
}
services.update(extra_services)
characteristics.update(extra_chars)

def dump(name, data):
    with open(os.path.join(out, name), "w", encoding="utf-8") as handle:
        json.dump(data, handle, ensure_ascii=False, separators=(",", ":"), sort_keys=True)

dump("companies.json", companies)
dump("services.json", services)
dump("characteristics.json", characteristics)
print(len(companies), len(services), len(characteristics))
