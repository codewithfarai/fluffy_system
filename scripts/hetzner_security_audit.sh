#!/bin/bash
# Hetzner Security Audit Script

HETZNER_API_TOKEN="${HETZNER_API_TOKEN}"

if [[ -z "$HETZNER_API_TOKEN" ]]; then
    echo "Error: HETZNER_API_TOKEN not set"
    echo "Export your token: export HETZNER_API_TOKEN='your-token'"
    exit 1
fi

API_BASE="https://api.hetzner.cloud/v1"

echo "======================================"
echo "Hetzner Cloud Security Audit"
echo "======================================"
echo ""

# List all firewalls
echo "1. FIREWALLS:"
echo "--------------------------------------"
curl -s -H "Authorization: Bearer $HETZNER_API_TOKEN" \
  "$API_BASE/firewalls" | jq -r '.firewalls[] | "Name: \(.name)\nID: \(.id)\nRules Count: \(.rules | length)\n"'

echo ""
echo "2. FIREWALL RULES DETAILS:"
echo "--------------------------------------"
curl -s -H "Authorization: Bearer $HETZNER_API_TOKEN" \
  "$API_BASE/firewalls" | jq -r '.firewalls[] | "
=== \(.name) ===
Inbound Rules:
\(.rules[] | select(.direction=="in") | "  - \(.protocol):\(.port) from \(.source_ips | join(", "))")

Outbound Rules:
\(.rules[] | select(.direction=="out") | "  - \(.protocol):\(.port) to \(.destination_ips | join(", "))")
"'

echo ""
echo "3. SERVERS AND THEIR SECURITY:"
echo "--------------------------------------"
curl -s -H "Authorization: Bearer $HETZNER_API_TOKEN" \
  "$API_BASE/servers" | jq -r '.servers[] | "
Server: \(.name)
  Public IP: \(.public_net.ipv4.ip // "NONE")
  Private IP: \(.private_net[0].ip // "NONE")
  Firewalls: \(.public_net.firewalls | map(.id) | join(", ") // "NONE")
  Status: \(.status)
"'

echo ""
echo "4. NETWORKS:"
echo "--------------------------------------"
curl -s -H "Authorization: Bearer $HETZNER_API_TOKEN" \
  "$API_BASE/networks" | jq -r '.networks[] | "
Network: \(.name)
  IP Range: \(.ip_range)
  Subnets: \(.subnets | map(.ip_range) | join(", "))
"'

echo ""
echo "======================================"
echo "Audit Complete"
echo "======================================"