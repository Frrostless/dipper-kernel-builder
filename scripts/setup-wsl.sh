#!/bin/bash
set -euo pipefail

# ============================================================
#  WSL Setup Script for Xiaomi Mi 8 (dipper) Kernel 4.9
#  Run this in WSL Ubuntu 22.04
#
#  Usage:
#    1. Open WSL (Ubuntu)
#    2. cd /mnt/c/Users/ddd/Documents/trea/dipper-kernel-builder
#    3. bash scripts/setup-wsl.sh
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
fatal() { error "$*"; exit 1; }

HOME_DIR="$HOME"
TOOLCHAINS_DIR="$HOME_DIR/toolchains"
KERNEL_SRC="$HOME_DIR/kernel_src"
OUTPUT_DIR="$HOME_DIR/output"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${CYAN}"
echo "============================================"
echo "  WSL Setup for Dipper Kernel Builder"
echo "  Xiaomi Mi 8 | Kernel 4.9 | Droidspaces"
echo "============================================"
echo -e "${NC}"

# ============================================================
# Step 1: Install dependencies
# ============================================================
info "Step 1: Installing build dependencies..."
sudo apt-get update
sudo apt-get install -y \
    build-essential bc bison flex patch pkg-config git curl tar xz-utils zip unzip \
    cpio rsync kmod perl python3 python-is-python3 libssl-dev libelf-dev pahole \
    libncurses-dev zlib1g-dev libyaml-dev lz4 zstd device-tree-compiler \
    jq wget
info "Dependencies installed."

# ============================================================
# Step 2: Setup toolchains
# ============================================================
info "Step 2: Setting up toolchains..."
mkdir -p "$TOOLCHAINS_DIR"

# Proton Clang 12
if [ ! -d "$TOOLCHAINS_DIR/proton-12/bin" ]; then
    info "Cloning Proton Clang 12..."
    git clone --depth=1 https://github.com/ravindu644/proton-12.git "$TOOLCHAINS_DIR/proton-12" \
        || fatal "Failed to clone Proton Clang 12"
else
    info "Proton Clang 12 already exists."
fi

# Linaro GCC 7.5
if [ ! -d "$TOOLCHAINS_DIR/aarch64-linaro-7.5/bin" ]; then
    info "Downloading Linaro GCC 7.5..."
    cd "$TOOLCHAINS_DIR"
    curl -Lf -o linaro.tar.xz \
        "https://github.com/ravindu644/Android-Kernel-Tutorials/releases/download/toolchains/linaro-aarch64-7.5.tar.xz" \
        || fatal "Failed to download Linaro GCC 7.5"
    mkdir -p aarch64-linaro-7.5
    tar -xJf linaro.tar.xz -C aarch64-linaro-7.5 --strip-components=1
    rm linaro.tar.xz
else
    info "Linaro GCC 7.5 already exists."
fi

# magiskboot
if [ ! -f "$TOOLCHAINS_DIR/magiskboot" ]; then
    info "Downloading magiskboot from latest Magisk release..."
    MAGISK_URL=$(curl -sL https://api.github.com/repos/topjohnwu/Magisk/releases/latest \
        | jq -r '.assets[] | select(.name | test("Magisk-v.*\.apk$")) | .browser_download_url' \
        | head -1)

    if [ -n "$MAGISK_URL" ]; then
        curl -Lf -o /tmp/magisk.apk "$MAGISK_URL"
        cd /tmp && unzip -o magisk.apk "lib/x86_64/libmagiskboot.so" 2>/dev/null \
            || unzip -o magisk.apk "lib/arm64-v8a/libmagiskboot.so" 2>/dev/null
        LIB_FILE=$(find /tmp/lib -name "libmagiskboot.so" 2>/dev/null | head -1)
        if [ -n "$LIB_FILE" ]; then
            cp "$LIB_FILE" "$TOOLCHAINS_DIR/magiskboot"
            chmod +x "$TOOLCHAINS_DIR/magiskboot"
            info "magiskboot installed."
        else
            warn "Could not extract magiskboot from Magisk APK."
        fi
        rm -rf /tmp/magisk.apk /tmp/lib
    else
        warn "Could not find Magisk download URL."
    fi
else
    info "magiskboot already exists."
fi

# Verify
info "CC: $($TOOLCHAINS_DIR/proton-12/bin/clang --version 2>&1 | head -1)"
info "GCC: $($TOOLCHAINS_DIR/aarch64-linaro-7.5/bin/aarch64-linux-gnu-gcc --version 2>&1 | head -1)"

# ============================================================
# Step 3: Clone kernel source
# ============================================================
KERNEL_BRANCH="${KERNEL_BRANCH:-dipper-q-oss}"

if [ ! -d "$KERNEL_SRC/.git" ]; then
    info "Step 3: Cloning Xiaomi Mi 8 kernel source (branch: $KERNEL_BRANCH)..."
    info "This will take a while..."
    git clone --depth=1 -b "$KERNEL_BRANCH" \
        https://github.com/MiCode/Xiaomi_Kernel_OpenSource.git "$KERNEL_SRC" \
        || fatal "Failed to clone kernel source"
else
    info "Step 3: Kernel source already exists."
fi

cd "$KERNEL_SRC"
info "Kernel version: $(make kernelversion 2>/dev/null || echo 'unknown')"

# ============================================================
# Step 4: Apply patches
# ============================================================
info "Step 4: Applying patches..."
PATCH_DIR="$HOME_DIR/patches"
mkdir -p "$PATCH_DIR"

# Droidspaces non-GKI patches
info "Downloading Droidspaces non-GKI patches..."
DROID_BASE="https://raw.githubusercontent.com/ravindu644/Droidspaces-OSS/main/Documentation/resources/kernel-patches/non-GKI"

curl -Lf -o "$PATCH_DIR/droid_01.patch" \
    "$DROID_BASE/01.fix_kernel_panic_in_xt_qtaguid.patch" 2>/dev/null || warn "Could not download droid_01 patch"

curl -Lf -o "$PATCH_DIR/droid_02.patch" \
    "$DROID_BASE/02.fix_restore%20cgroup%20file%20prefix%20handling%20.patch" 2>/dev/null || warn "Could not download droid_02 patch"

for p in "$PATCH_DIR"/droid_*.patch; do
    [ -f "$p" ] || continue
    info "Applying: $(basename "$p")"
    if patch -p1 --dry-run < "$p" 2>/dev/null; then
        patch -p1 < "$p" || warn "Patch $(basename "$p") failed"
    else
        warn "Patch $(basename "$p") not applicable (may already be applied)"
    fi
done

# Build fix patches
info "Downloading build fix patches..."
FIX_BASE="https://raw.githubusercontent.com/ravindu644/Android-Kernel-Tutorials/main/patches"
FIX_PATCHES=(
    "009.fix-Werror.patch"
    "018.yylloc.patch"
    "017.nuke_dirty_string.patch"
)

for p in "${FIX_PATCHES[@]}"; do
    curl -Lf -o "$PATCH_DIR/$p" "$FIX_BASE/$p" 2>/dev/null || { warn "Could not download $p"; continue; }
    info "Applying: $p"
    if patch -p1 --dry-run < "$PATCH_DIR/$p" 2>/dev/null; then
        patch -p1 < "$PATCH_DIR/$p" || warn "Patch $p failed"
    else
        warn "Patch $p not applicable (may already be applied)"
    fi
done

# ============================================================
# Step 5: Copy config fragments
# ============================================================
info "Step 5: Copying config fragments..."
mkdir -p arch/arm64/configs
cp "$PROJECT_DIR/config/droidspaces.config" arch/arm64/configs/
cp "$PROJECT_DIR/config/custom.config" arch/arm64/configs/
info "Config files copied."

# ============================================================
# Step 6: Build kernel
# ============================================================
DEFCONFIG="${DEFCONFIG:-dipper_user_defconfig}"

info "Step 6: Building kernel..."
export PATH="$TOOLCHAINS_DIR/proton-12/bin:$TOOLCHAINS_DIR/aarch64-linaro-7.5/bin:$TOOLCHAINS_DIR:$PATH"
export LD_LIBRARY_PATH="$TOOLCHAINS_DIR/proton-12/lib:$TOOLCHAINS_DIR/proton-12/lib64:${LD_LIBRARY_PATH:-}"

BUILD_OPTIONS=(
    -j"$(nproc)"
    ARCH=arm64
    CC=clang
    CROSS_COMPILE=aarch64-linux-gnu-
    CLANG_TRIPLE=aarch64-linux-gnu-
    O="$KERNEL_SRC/out"
)

info "Generating .config from $DEFCONFIG + droidspaces.config + custom.config..."
make "${BUILD_OPTIONS[@]}" "$DEFCONFIG" droidspaces.config custom.config

info "Running olddefconfig..."
make "${BUILD_OPTIONS[@]}" olddefconfig

info "Kernel version: $(make "${BUILD_OPTIONS[@]}" kernelversion)"
info "Compiling with $(nproc) threads..."
info "This will take 10-30 minutes depending on your CPU..."

make "${BUILD_OPTIONS[@]}" Image || {
    error "Build failed! Check the error messages above."
    error "Common fixes:"
    error "  - Make sure all patches applied correctly"
    error "  - Check for missing dependencies"
    fatal "Kernel compilation failed"
}

# Copy output
mkdir -p "$OUTPUT_DIR"
cp "$KERNEL_SRC/out/arch/arm64/boot/Image" "$OUTPUT_DIR/"
cp "$KERNEL_SRC/out/.config" "$OUTPUT_DIR/kernel.config"

echo -e "${GREEN}"
echo "============================================"
echo "  Build Complete!"
echo "============================================"
echo -e "${NC}"
echo "Output files:"
ls -lh "$OUTPUT_DIR/"

echo ""
echo "Output directory: $OUTPUT_DIR"
echo "  - Image         : Compiled kernel image"
echo "  - kernel.config : Kernel configuration"
echo ""
echo "Next steps:"
echo "  1. To package boot.img, place your stock boot.img at:"
echo "     $OUTPUT_DIR/stock_boot.img"
echo "  2. Then run:"
echo "     cd $OUTPUT_DIR"
echo "     $TOOLCHAINS_DIR/magiskboot unpack stock_boot.img"
echo "     cp Image kernel"
echo "     $TOOLCHAINS_DIR/magiskboot repack stock_boot.img"
echo "  3. Flash to device:"
echo "     fastboot flash boot new-boot.img"
echo "  4. In Droidspaces app: Settings -> Requirements -> Check Requirements"
echo ""
echo "Output files are also accessible from Windows at:"
echo "  \\\\wsl$\\Ubuntu-22.04$HOME/output/"
