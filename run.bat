@echo off
chcp 65001 >nul 2>&1

echo.
echo ============================================
echo   Dipper Kernel Builder for Xiaomi Mi 8
echo   Kernel 4.9 + Droidspaces non-GKI
echo ============================================
echo.

REM Check Docker
where docker >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Docker is not installed or not in PATH!
    echo Please install Docker Desktop from: https://www.docker.com/products/docker-desktop
    pause
    exit /b 1
)

REM Check for --build flag
if "%1"=="--build" (
    REM Check if image exists
    docker images -q dipper-kernel-builder >nul 2>&1
    if errorlevel 1 (
        echo [INFO] Building Docker image first time...
        docker build -t dipper-kernel-builder .
        if errorlevel 1 (
            echo [ERROR] Docker build failed!
            pause
            exit /b 1
        )
    )
    echo [INFO] Starting automatic kernel build...
    docker run --rm -it --privileged ^
        -v "%~dp0scripts:/home/kernel-builder/scripts" ^
        -v "%~dp0config:/home/kernel-builder/config" ^
        -v "dipper-kernel-builder_kernel-output:/home/kernel-builder/output" ^
        --name dipper-kernel-builder ^
        dipper-kernel-builder ^
        bash -c "~/scripts/build.sh"
) else if "%1"=="--rebuild" (
    echo [INFO] Rebuilding Docker image...
    docker rm -f dipper-kernel-builder 2>nul
    docker rmi dipper-kernel-builder:latest 2>nul
    docker build -t dipper-kernel-builder .
) else if "%1"=="--clean" (
    echo [INFO] Cleaning up...
    docker rm -f dipper-kernel-builder 2>nul
    docker volume rm dipper-kernel-builder_kernel-output 2>nul
    docker rmi dipper-kernel-builder:latest 2>nul
    echo [INFO] Done.
) else (
    REM Check if image exists
    docker images -q dipper-kernel-builder >nul 2>&1
    if errorlevel 1 (
        echo [INFO] Building Docker image first time...
        docker build -t dipper-kernel-builder .
        if errorlevel 1 (
            echo [ERROR] Docker build failed!
            pause
            exit /b 1
        )
    )
    echo [INFO] Starting interactive shell...
    echo [INFO] Run ~/scripts/build.sh to start the build.
    echo.
    docker run --rm -it --privileged ^
        -v "%~dp0scripts:/home/kernel-builder/scripts" ^
        -v "%~dp0config:/home/kernel-builder/config" ^
        -v "dipper-kernel-builder_kernel-output:/home/kernel-builder/output" ^
        --name dipper-kernel-builder ^
        dipper-kernel-builder
)

pause
