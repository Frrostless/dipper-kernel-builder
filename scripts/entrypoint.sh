#!/bin/bash
set -e

echo ""
echo "============================================"
echo "  Dipper Kernel Builder - Docker Container"
echo "  Xiaomi Mi 8 | Kernel 4.9 | Droidspaces"
echo "============================================"
echo ""

echo "[Environment Check]"
echo "  User: $(whoami)"
echo "  Home: ${HOME}"
echo "  Clang: $(clang --version 2>&1 | head -1)"
echo "  GCC:   $(aarch64-linux-gnu-gcc --version 2>&1 | head -1)"
echo "  Magiskboot: $(which magiskboot 2>/dev/null || echo ~/toolchains/magiskboot)"
echo ""

if [ -f ~/scripts/build.sh ]; then
    echo "Ready to build. Run:"
    echo "  ~/scripts/build.sh"
    echo ""
    echo "Or for interactive shell, just type 'bash'"
    echo ""
    exec "${@:-bash}"
else
    echo "Build script not found. Starting interactive shell."
    exec bash
fi
