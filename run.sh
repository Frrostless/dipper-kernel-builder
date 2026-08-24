#!/bin/bash
set -e

cd "$(dirname "$(realpath "$0")")"

echo ""
echo "============================================"
echo "  Dipper Kernel Builder for Xiaomi Mi 8"
echo "  Kernel 4.9 + Droidspaces non-GKI"
echo "============================================"
echo ""

if ! command -v docker &>/dev/null; then
    echo "[ERROR] Docker is not installed!"
    exit 1
fi

if [[ "$1" == "--rebuild" ]]; then
    echo "[INFO] Rebuilding Docker image..."
    docker rm -f dipper-kernel-builder 2>/dev/null || true
    docker rmi dipper-kernel-builder:latest 2>/dev/null || true
    docker build -t dipper-kernel-builder .
elif [[ "$1" == "--clean" ]]; then
    echo "[INFO] Cleaning up..."
    docker rm -f dipper-kernel-builder 2>/dev/null || true
    docker volume rm dipper-kernel-builder_kernel-output 2>/dev/null || true
    docker rmi dipper-kernel-builder:latest 2>/dev/null || true
    exit 0
elif [[ "$1" == "--build" ]]; then
    IMAGE_ID=$(docker images -q dipper-kernel-builder 2>/dev/null)
    if [ -z "$IMAGE_ID" ]; then
        echo "[INFO] Building Docker image (first time)..."
        docker build -t dipper-kernel-builder .
    fi
    echo "[INFO] Starting automatic kernel build..."
    docker run --rm -it --privileged \
        -v "$(pwd)/scripts:/home/kernel-builder/scripts" \
        -v "$(pwd)/config:/home/kernel-builder/config" \
        -v "dipper-kernel-builder_kernel-output:/home/kernel-builder/output" \
        --name dipper-kernel-builder \
        dipper-kernel-builder \
        bash -c "~/scripts/build.sh"
    exit 0
else
    IMAGE_ID=$(docker images -q dipper-kernel-builder 2>/dev/null)
    if [ -z "$IMAGE_ID" ]; then
        echo "[INFO] Building Docker image (first time)..."
        docker build -t dipper-kernel-builder .
    fi
    echo "[INFO] Starting interactive shell..."
    echo "[INFO] Run ~/scripts/build.sh to start the build."
    echo ""
    docker run --rm -it --privileged \
        -v "$(pwd)/scripts:/home/kernel-builder/scripts" \
        -v "$(pwd)/config:/home/kernel-builder/config" \
        -v "dipper-kernel-builder_kernel-output:/home/kernel-builder/output" \
        --name dipper-kernel-builder \
        dipper-kernel-builder
fi
