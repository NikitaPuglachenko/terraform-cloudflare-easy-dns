#!/usr/bin/env python3
"""Checks schema/records.schema.json: valid documents must pass and documents with
typical mistakes must fail. Requires the jsonschema and pyyaml packages."""
import json
import sys
from pathlib import Path

import yaml
from jsonschema import Draft7Validator, FormatChecker

ROOT = Path(__file__).resolve().parent.parent
validator = Draft7Validator(json.loads((ROOT / "schema/records.schema.json").read_text()), format_checker=FormatChecker())

VALID = {
    "all record types (tests/fixtures/all-types.yaml)": (ROOT / "tests/fixtures/all-types.yaml").read_text(),
    "numbers as strings in data": """
records:
  _sip._tcp:
    SRV: [{ data: { priority: "10", weight: "5", port: "5060", target: sip.example.com } }]
""",
    "empty records": "records: {}",
}

INVALID = {
    "misspelled attribute": 'records: { app: { A: [{ content: 192.0.2.10, proxid: true }] } }',
    "misspelled setting": 'records: { app: { AAAA: [{ content: "2001:db8::1", settings: { ipv6_onyl: true } }] } }',
    "unknown record type": 'records: { app: { CNAMe: [{ content: target.example.net }] } }',
    "TTL as text": 'records: { app: { A: [{ content: 192.0.2.10, ttl: 5m }] } }',
    "TTL out of range": 'records: { app: { A: [{ content: 192.0.2.10, ttl: 5 }] } }',
    "proxied as text": 'records: { app: { A: [{ content: 192.0.2.10, proxied: "yes" }] } }',
    "proxied TXT": 'records: { app: { TXT: [{ content: x, proxied: true }] } }',
    "IPv6 in A": 'records: { app: { A: [{ content: "2001:db8::1" }] } }',
    "invalid IPv4": 'records: { app: { A: [{ content: 192.168.1.300 }] } }',
    "IPv4 in AAAA": 'records: { app: { AAAA: [{ content: 192.0.2.1 }] } }',
    "missing content": 'records: { app: { A: [{ ttl: 300 }] } }',
    "MX without priority": 'records: { app: { MX: [{ content: mx.example.com }] } }',
    "CAA with an unknown tag": 'records: { app: { CAA: [{ content: letsencrypt.org, tag: isue }] } }',
    "SRV without port": 'records: { _sip._tcp: { SRV: [{ data: { priority: 10, weight: 5, target: sip.example.com } }] } }',
    "SRV with an unknown field": 'records: { _sip._tcp: { SRV: [{ data: { priority: 10, weight: 5, port: 1, target: x, proto: _tcp } }] } }',
    "data on an A record": 'records: { app: { A: [{ content: 192.0.2.10, data: { target: x } }] } }',
    "URI without priority": 'records: { _ftp._tcp: { URI: [{ data: { weight: 1, target: "ftp://x/" } }] } }',
    "LOC with an invalid direction": 'records: { o: { LOC: [{ data: { lat_degrees: 1, lat_minutes: 1, lat_seconds: 1, lat_direction: X, long_degrees: 1, long_minutes: 1, long_seconds: 1, long_direction: E } }] } }',
    "invalid name": 'records: { "my app": { A: [{ content: 192.0.2.10 }] } }',
    "invalid alias": 'records: { app: { ALIASES: [{ content: -bad }] } }',
    "key with whitespace": 'records: { app: { TXT: [{ content: x, key: "my key" }] } }',
    "record that is not an object": 'records: { app: { A: [192.0.2.10] } }',
}

failures = 0
for name, document in VALID.items():
    errors = list(validator.iter_errors(yaml.safe_load(document)))
    if errors:
        failures += 1
        print(f"FAIL: {name} should be valid: {errors[0].message} at {list(errors[0].absolute_path)}")
    else:
        print(f"ok - valid: {name}")
for name, document in INVALID.items():
    if validator.is_valid(yaml.safe_load(document)):
        failures += 1
        print(f"FAIL: {name} should be invalid")
    else:
        print(f"ok - rejected: {name}")

for path in sys.argv[1:]:
    errors = list(validator.iter_errors(yaml.safe_load(Path(path).read_text()) or {}))
    print(f"{'ok' if not errors else 'FAIL'} - {path}" + (f": {errors[0].message}" if errors else ""))
    failures += bool(errors)

sys.exit(1 if failures else 0)
