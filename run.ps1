# PowerShell script to build and run the dipper kernel builder Docker container
# Usage:
#   .\run.ps1              - Build image and start interactive shell
#   .\run.ps1 -Build       - Build the kernel automatically
#   .\run.ps1 -Rebuild     - Rebuild the Docker image from scratch
#   .\run.ps1 -Clean       - Remove all build artifacts and start fresh

param(
    [switch]$Build,
    [switch]$Rebuild,
    [switch]$Clean
)

$ErrorActionPreference = "Stop"
$ProjectDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Dipper Kernel Builder for Xiaomi Mi 8" -ForegroundColor Cyan
Write-Host "  Kernel 4.9 + Droidspaces non-GKI" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Check Docker
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] Docker is not installed or not in PATH!" -ForegroundColor Red
    Write-Host "Please install Docker Desktop from: https://www.docker.com/products/docker-desktop"
    exit 1
}

# Clean mode
if ($Clean) {
    Write-Host "[INFO] Cleaning up..." -ForegroundColor Yellow
    docker rm -f dipper-kernel-builder 2>$null
    docker volume rm dipper-kernel-builder_kernel-output 2>$null
    docker rmi dipper-kernel-builder:latest 2>$null
    Write-Host "[INFO] Cleanup done." -ForegroundColor Green
    exit 0
}

# Build or rebuild image
if ($Rebuild) {
    Write-Host "[INFO] Rebuilding Docker image from scratch..." -ForegroundColor Yellow
    docker rm -f dipper-kernel-builder 2>$null
    docker rmi dipper-kernel-builder:latest 2>$null
    docker build -t dipper-kernel-builder "$ProjectDir"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Docker build failed!" -ForegroundColor Red
        exit 1
    }
} else {
    # Check if image exists
    $imageExists = docker images -q dipper-kernel-builder 2>$null
    if (-not $imageExists) {
        Write-Host "[INFO] Building Docker image (first time)..." -ForegroundColor Yellow
        docker build -t dipper-kernel-builder "$ProjectDir"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[ERROR] Docker build failed!" -ForegroundColor Red
            exit 1
        }
    }
}

Write-Host "[INFO] Docker image ready." -ForegroundColor Green

# Run the container
if ($Build) {
    Write-Host "[INFO] Starting automatic kernel build..." -ForegroundColor Yellow
    docker run --rm -it `
        -v "${ProjectDir}\scripts:/home/kernel-builder/scripts" `
        -v "${ProjectDir}\config:/home/kernel-builder/config" `
        -v "dipper-kernel-builder_kernel-output:/home/kernel-builder/output" `
        --privileged `
        --name dipper-kernel-builder `
        dipper-kernel-builder `
        bash -c "~/scripts/build.sh"
} else {
    Write-Host "[INFO] Starting interactive shell..." -ForegroundColor Yellow
    Write-Host "[INFO] Run ~/scripts/build.sh to start the build." -ForegroundColor Green
    Write-Host ""
    docker run --rm -it `
        -v "${ProjectDir}\scripts:/home/kernel-builder/scripts" `
        -v "${ProjectDir}\config:/home/kernel-builder/config" `
        -v "dipper-kernel-builder_kernel-output:/home/kernel-builder/output" `
        --privileged `
        --name dipper-kernel-builder `
        dipper-kernel-builder
}
