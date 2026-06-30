#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
GLOBAL_INSTALL_DIR="/usr/local/bin"
USER_INSTALL_DIR="${HOME}/.local/bin"

echo "Building qhelp (release)..."
cd "$PROJECT_DIR"
swift build -c release 2>&1

BIN_PATH="$(swift build -c release --show-bin-path)/qhelp"

install_to() {
    local target_dir="$1"
    local label="$2"

    mkdir -p "$target_dir"
    cp "$BIN_PATH" "$target_dir/qhelp"
    chmod +x "$target_dir/qhelp"

    echo ""
    echo "✓ qhelp installed to $target_dir/qhelp ($label)"
}

echo ""
if [ -w "$GLOBAL_INSTALL_DIR" ] 2>/dev/null || sudo -n true 2>/dev/null; then
    if [ -w "$GLOBAL_INSTALL_DIR" ]; then
        install_to "$GLOBAL_INSTALL_DIR" "global"
    else
        echo "Installing to $GLOBAL_INSTALL_DIR/qhelp (requires sudo)..."
        sudo mkdir -p "$GLOBAL_INSTALL_DIR"
        sudo cp "$BIN_PATH" "$GLOBAL_INSTALL_DIR/qhelp"
        sudo chmod +x "$GLOBAL_INSTALL_DIR/qhelp"
        echo ""
        echo "✓ qhelp installed to $GLOBAL_INSTALL_DIR/qhelp (global)"
    fi
else
    echo "Cannot write to $GLOBAL_INSTALL_DIR without sudo."
    echo "Installing to $USER_INSTALL_DIR instead (no password required)..."
    install_to "$USER_INSTALL_DIR" "user-local"
    echo ""
    echo "Ensure this directory is on your PATH:"
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

echo ""
echo "Usage:"
echo "  export ANTHROPIC_API_KEY=\"sk-ant-...\""
echo "  qhelp claude-sonnet-4-6"
echo ""
echo "Verify installation:"
echo "  which qhelp"
echo "  qhelp --help"
