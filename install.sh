#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${HOME}/.local/bin"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing ct to ${INSTALL_DIR}..."

# Create install directory if needed
mkdir -p "$INSTALL_DIR"

# Copy script
cp "${SCRIPT_DIR}/ct" "${INSTALL_DIR}/ct"
chmod +x "${INSTALL_DIR}/ct"

# Create session directory
mkdir -p "${HOME}/.ct"

echo "Done!"
echo ""
echo "Make sure ${INSTALL_DIR} is in your PATH."
echo "Add to ~/.zshrc if needed:"
echo "    export PATH=\"\${HOME}/.local/bin:\${PATH}\""
echo ""
echo "Usage: ct <session-name>"
