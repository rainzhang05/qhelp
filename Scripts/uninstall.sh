#!/bin/bash
set -e

INSTALL_DIR="/usr/local/bin"

if [ -f "$INSTALL_DIR/clip" ]; then
    echo "Removing $INSTALL_DIR/clip..."
    sudo rm "$INSTALL_DIR/clip"
    echo ""
    echo "✓ ClipAI uninstalled successfully."
else
    echo "ClipAI is not installed at $INSTALL_DIR/clip."
fi
