#!/bin/bash
set -euo pipefail

# ============================================================
#  Xiaomi Mi 8 (dipper) Kernel 4.9 Builder
#  with Droidspaces non-GKI support
#  Toolchain: Proton Clang 12 + Linaro GCC 7.5
# ============================================================

# --- Configuration ---
KERNEL_REPO="https://github.com/MiCode/Xiaomi_Kernel_OpenSource.git"
KERNEL_BRANCH="${KERNEL_BRANCH:-dipper-q-oss}"
DEFCONFIG="${DEFCONFIG:-dipper_user_defconfig}"
KERNEL_IMAGE="Image"
USE_OUT_DIR=1
MENUCONFIG=0

# --- Paths ---
HOME_DIR="${HOME}"
TOOLCHAINS_DIR="${HOME_DIR}/toolchains"
CLANG="${TOOLCHAINS_DIR}/proton-12"
GCC="${TOOLCHAINS_DIR}/aarch64-linaro-7.5"
KERNEL_SRC="${HOME_DIR}/kernel_src"
OUTPUT_DIR="${HOME_DIR}/output"
CONFIG_DIR="${HOME_DIR}/config"
SCRIPTS_DIR="${HOME_DIR}/scripts"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "\n${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "\n${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "\n${RED}[ERROR]${NC} $*" >&2; }
fatal() { error "$*"; exit 1; }

# ============================================================
# Step 1: Clone kernel source
# ============================================================
clone_kernel() {
    if [ -d "${KERNEL_SRC}/.git" ]; then
        info "Kernel source already exists at ${KERNEL_SRC}"
        cd "${KERNEL_SRC}"
        info "Current branch: $(git branch --show-current)"
        info "Latest commit: $(git log --oneline -1)"
        return 0
    fi

    info "Cloning Xiaomi Mi 8 kernel source (branch: ${KERNEL_BRANCH})..."
    info "This will take a while depending on your network speed..."

    git clone --depth=1 -b "${KERNEL_BRANCH}" "${KERNEL_REPO}" "${KERNEL_SRC}" \
        || fatal "Failed to clone kernel source from ${KERNEL_REPO}"

    cd "${KERNEL_SRC}"
    info "Kernel cloned successfully!"
    info "Kernel version: $(make kernelversion 2>/dev/null || echo 'unknown')"
}

# ============================================================
# Step 2: Apply patches
# ============================================================
apply_patches() {
    cd "${KERNEL_SRC}"
    info "Applying patches..."

    local patch_dir="${HOME_DIR}/patches"
    mkdir -p "${patch_dir}"

    # --- Droidspaces non-GKI patches ---
    info "Downloading Droidspaces non-GKI patches..."

    local droidspaces_patches=(
        "01.fix_kernel_panic_in_xt_qtaguid.patch"
        "02.fix_restore cgroup file prefix handling .patch"
    )

    local droidspaces_base="https://raw.githubusercontent.com/ravindu644/Droidspaces-OSS/main/Documentation/resources/kernel-patches/non-GKI"

    for patch_file in "${droidspaces_patches[@]}"; do
        local dest="${patch_dir}/droidspaces_${patch_file// /_}"
        if curl -Lf -o "${dest}" "${droidspaces_base}/${patch_file// /%20}" 2>/dev/null; then
            info "Applying: ${patch_file}"
            if patch -p1 --dry-run < "${dest}" 2>/dev/null; then
                patch -p1 < "${dest}" || warn "Patch ${patch_file} failed to apply (may already be applied)"
            else
                warn "Patch ${patch_file} does not apply cleanly (may already be applied or not needed)"
            fi
        else
            warn "Could not download ${patch_file} from Droidspaces-OSS"
        fi
    done

    # --- Build fix patches from Android-Kernel-Tutorials ---
    info "Downloading build fix patches..."

    local fix_patches=(
        "009.fix-Werror.patch"
        "018.yylloc.patch"
        "017.nuke_dirty_string.patch"
    )

    local fixes_base="https://raw.githubusercontent.com/ravindu644/Android-Kernel-Tutorials/main/patches"

    for patch_file in "${fix_patches[@]}"; do
        local dest="${patch_dir}/${patch_file}"
        if curl -Lf -o "${dest}" "${fixes_base}/${patch_file}" 2>/dev/null; then
            info "Applying: ${patch_file}"
            if patch -p1 --dry-run < "${dest}" 2>/dev/null; then
                patch -p1 < "${dest}" || warn "Patch ${patch_file} failed to apply"
            else
                warn "Patch ${patch_file} does not apply cleanly (may already be applied or not needed)"
            fi
        else
            warn "Could not download ${patch_file}"
        fi
    done

    info "Patches applied."
}

# ============================================================
# Step 3: Copy config fragments
# ============================================================
copy_configs() {
    cd "${KERNEL_SRC}"
    info "Copying config fragments to arch/arm64/configs/..."

    local configs_dir="arch/arm64/configs"
    mkdir -p "${configs_dir}"

    cp "${CONFIG_DIR}/droidspaces.config" "${configs_dir}/droidspaces.config" 2>/dev/null \
        || warn "droidspaces.config not found in ${CONFIG_DIR}"
    cp "${CONFIG_DIR}/custom.config" "${configs_dir}/custom.config" 2>/dev/null \
        || warn "custom.config not found in ${CONFIG_DIR}"

    info "Config fragments copied."
}

# ============================================================
# Step 4: Build the kernel
# ============================================================
build_kernel() {
    cd "${KERNEL_SRC}"
    info "Starting kernel build..."

    # Verify toolchains
    [ -d "${CLANG}/bin" ] || fatal "Proton Clang not found at ${CLANG}"
    [ -d "${GCC}/bin" ] || fatal "Linaro GCC not found at ${GCC}"

    export PATH="${CLANG}/bin:${GCC}/bin:${PATH}"
    export LD_LIBRARY_PATH="${CLANG}/lib:${CLANG}/lib64:${LD_LIBRARY_PATH:-}"

    # Verify compilers
    info "CC: $(clang --version 2>&1 | head -1)"
    info "CROSS_COMPILE: $(aarch64-linux-gnu-gcc --version 2>&1 | head -1)"

    local BUILD_OPTIONS=(
        -j"$(nproc)"
        ARCH=arm64
        CC=clang
        CROSS_COMPILE=aarch64-linux-gnu-
        CLANG_TRIPLE=aarch64-linux-gnu-
    )

    if [ "${USE_OUT_DIR}" = 1 ]; then
        BUILD_OPTIONS+=(O="${KERNEL_SRC}/out")
        local BOOT_DIR="${KERNEL_SRC}/out/arch/arm64/boot"
    else
        local BOOT_DIR="${KERNEL_SRC}/arch/arm64/boot"
    fi

    # Generate .config
    info "Generating .config from ${DEFCONFIG} + droidspaces.config + custom.config..."
    make "${BUILD_OPTIONS[@]}" "${DEFCONFIG}" droidspaces.config custom.config \
        || fatal "Failed to generate .config"

    # Merge config and check for missing options
    info "Running olddefconfig to resolve dependencies..."
    make "${BUILD_OPTIONS[@]}" olddefconfig || fatal "olddefconfig failed"

    # Show kernel version
    info "Kernel version: $(make "${BUILD_OPTIONS[@]}" kernelversion 2>/dev/null || echo 'unknown')"

    # Build
    info "Compiling kernel with $(nproc) threads..."
    info "This will take 10-30 minutes depending on your CPU..."

    make "${BUILD_OPTIONS[@]}" "${KERNEL_IMAGE}" || {
        error "Build failed!"
        error "Common fixes:"
        error "  - Check if all patches applied correctly"
        error "  - Try disabling CONFIG_ANDROID_PARANOID_NETWORK"
        error "  - Check the error messages above"
        fatal "Kernel compilation failed"
    }

    # Copy result
    mkdir -p "${OUTPUT_DIR}"
    cp "${BOOT_DIR}/${KERNEL_IMAGE}" "${OUTPUT_DIR}/"
    info "Kernel image saved to: ${OUTPUT_DIR}/${KERNEL_IMAGE}"

    # Also copy .config for reference
    if [ "${USE_OUT_DIR}" = 1 ]; then
        cp "${KERNEL_SRC}/out/.config" "${OUTPUT_DIR}/kernel.config"
    fi

    info "Build completed successfully!"
    ls -lh "${OUTPUT_DIR}/${KERNEL_IMAGE}"
}

# ============================================================
# Step 5: Package boot.img (requires stock boot.img)
# ============================================================
package_boot() {
    cd "${KERNEL_SRC}"
    info "Packaging boot.img..."

    local magiskboot="${TOOLCHAINS_DIR}/magiskboot"
    local boot_img="${OUTPUT_DIR}/stock_boot.img"
    local kernel_image="${OUTPUT_DIR}/${KERNEL_IMAGE}"

    if [ ! -f "${magiskboot}" ]; then
        warn "magiskboot not found. Skipping boot.img packaging."
        warn "To package manually:"
        warn "  1. Place your stock boot.img at ${OUTPUT_DIR}/stock_boot.img"
        warn "  2. Run: cd ${OUTPUT_DIR} && ${magiskboot} unpack stock_boot.img"
        warn "  3. Replace 'kernel' with your compiled Image"
        warn "  4. Run: ${magiskboot} repack stock_boot.img"
        return 0
    fi

    if [ ! -f "${boot_img}" ]; then
        warn "Stock boot.img not found at ${boot_img}"
        warn "Please place your stock boot.img there and run:"
        warn "  ${magiskboot} unpack ${boot_img}"
        warn "  cp ${kernel_image} ${OUTPUT_DIR}/kernel"
        warn "  ${magiskboot} repack ${boot_img}"
        warn "  # Result: ${OUTPUT_DIR}/new-boot.img"
        return 0
    fi

    info "Unpacking stock boot.img..."
    cd "${OUTPUT_DIR}"
    "${magiskboot}" unpack "${boot_img}" || fatal "Failed to unpack boot.img"

    info "Replacing kernel..."
    cp "${kernel_image}" kernel

    info "Repacking boot.img..."
    "${magiskboot}" repack "${boot_img}" || fatal "Failed to repack boot.img"

    if [ -f "new-boot.img" ]; then
        mv new-boot.img droidspaces-boot.img
        info "Boot image saved to: ${OUTPUT_DIR}/droidspaces-boot.img"
        info "Flash with: fastboot flash boot droidspaces-boot.img"
    else
        fatal "Repack did not produce new-boot.img"
    fi
}

# ============================================================
# Main
# ============================================================
main() {
    echo -e "${CYAN}"
    echo "============================================"
    echo "  Xiaomi Mi 8 (dipper) Kernel 4.9 Builder"
    echo "  with Droidspaces non-GKI support"
    echo "============================================"
    echo -e "${NC}"

    clone_kernel
    apply_patches
    copy_configs
    build_kernel
    package_boot

    echo -e "${GREEN}"
    echo "============================================"
    echo "  Build Complete!"
    echo "============================================"
    echo -e "${NC}"
    echo "Output files in ${OUTPUT_DIR}:"
    ls -la "${OUTPUT_DIR}/" 2>/dev/null
    echo ""
    echo "Next steps:"
    echo "  1. If you have a stock boot.img, place it at ${OUTPUT_DIR}/stock_boot.img"
    echo "  2. Re-run this script to package, or use magiskboot manually"
    echo "  3. Flash to device: fastboot flash boot droidspaces-boot.img"
    echo "  4. In Droidspaces app: Settings -> Requirements -> Check Requirements"
}

main "$@"
