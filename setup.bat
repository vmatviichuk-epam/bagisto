@echo off
setlocal enabledelayedexpansion

REM #############################################
REM # Bagisto Quick Setup Script (Windows)
REM #############################################

echo.
echo ============================================
echo        Bagisto Quick Setup Script
echo ============================================
echo.

REM Check PHP
echo [==>] Checking PHP installation...
where php >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] PHP is not installed. Please install PHP 8.2+ first.
    echo Download from: https://windows.php.net/download/
    pause
    exit /b 1
)
for /f "tokens=*" %%i in ('php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;"') do set PHP_VERSION=%%i
echo [OK] PHP %PHP_VERSION% found

REM Check Composer
echo [==>] Checking Composer...
where composer >nul 2>nul
if %errorlevel% equ 0 (
    set COMPOSER_CMD=composer
    echo [OK] Composer found globally
) else if exist "composer.phar" (
    set COMPOSER_CMD=php composer.phar
    echo [OK] Composer.phar found locally
) else (
    echo [WARNING] Composer not found. Downloading...
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
    php composer-setup.php
    del composer-setup.php
    set COMPOSER_CMD=php composer.phar
    echo [OK] Composer downloaded
)

REM Check npm
echo [==>] Checking Node.js/npm...
where npm >nul 2>nul
if %errorlevel% equ 0 (
    for /f "tokens=*" %%i in ('npm -v') do set NPM_VERSION=%%i
    echo [OK] npm !NPM_VERSION! found
    set HAS_NPM=true
) else (
    echo [WARNING] npm not found. Frontend assets won't be built.
    set HAS_NPM=false
)

REM Create .env file
echo [==>] Setting up environment file...
if not exist ".env" (
    copy .env.example .env >nul
    echo [OK] .env file created
) else (
    echo [WARNING] .env file already exists, skipping
)

REM Database configuration
echo.
echo ============================================
echo        Database Configuration
echo ============================================
echo.
echo Choose database setup:
echo   1) MySQL (Docker) - Recommended for quick start
echo   2) MySQL (Local) - Use existing MySQL installation
echo   3) Skip - Configure manually later
echo.
set /p DB_CHOICE="Enter choice [1-3]: "

if "%DB_CHOICE%"=="1" (
    echo [==>] Setting up MySQL with Docker...
    where docker >nul 2>nul
    if %errorlevel% neq 0 (
        echo [ERROR] Docker is not installed. Please install Docker Desktop first.
        echo Download from: https://www.docker.com/products/docker-desktop
        pause
        exit /b 1
    )

    REM Check if Docker is running
    docker info >nul 2>nul
    if %errorlevel% neq 0 (
        echo [ERROR] Docker daemon not running. Please start Docker Desktop.
        pause
        exit /b 1
    )

    REM Check if container already exists
    docker ps -a | findstr bagisto-mysql >nul 2>nul
    if %errorlevel% equ 0 (
        echo [WARNING] bagisto-mysql container already exists
        docker start bagisto-mysql >nul 2>nul
    ) else (
        docker run --name bagisto-mysql -e MYSQL_ROOT_PASSWORD=bagisto -e MYSQL_DATABASE=bagisto -p 3306:3306 -d mysql:8.0
    )

    echo [==>] Waiting for MySQL to be ready...
    timeout /t 15 /nobreak >nul

    REM Update .env using PowerShell for reliable replacement
    powershell -Command "(Get-Content .env) -replace 'DB_HOST=.*', 'DB_HOST=127.0.0.1' | Set-Content .env"
    powershell -Command "(Get-Content .env) -replace 'DB_PORT=.*', 'DB_PORT=3306' | Set-Content .env"
    powershell -Command "(Get-Content .env) -replace 'DB_DATABASE=.*', 'DB_DATABASE=bagisto' | Set-Content .env"
    powershell -Command "(Get-Content .env) -replace 'DB_USERNAME=.*', 'DB_USERNAME=root' | Set-Content .env"
    powershell -Command "(Get-Content .env) -replace 'DB_PASSWORD=.*', 'DB_PASSWORD=bagisto' | Set-Content .env"

    echo [OK] MySQL container started
)

if "%DB_CHOICE%"=="2" (
    echo.
    set /p DB_HOST="Database host [127.0.0.1]: "
    if "!DB_HOST!"=="" set DB_HOST=127.0.0.1
    set /p DB_PORT="Database port [3306]: "
    if "!DB_PORT!"=="" set DB_PORT=3306
    set /p DB_NAME="Database name [bagisto]: "
    if "!DB_NAME!"=="" set DB_NAME=bagisto
    set /p DB_USER="Database username [root]: "
    if "!DB_USER!"=="" set DB_USER=root
    set /p DB_PASS="Database password: "

    powershell -Command "(Get-Content .env) -replace 'DB_HOST=.*', 'DB_HOST=!DB_HOST!' | Set-Content .env"
    powershell -Command "(Get-Content .env) -replace 'DB_PORT=.*', 'DB_PORT=!DB_PORT!' | Set-Content .env"
    powershell -Command "(Get-Content .env) -replace 'DB_DATABASE=.*', 'DB_DATABASE=!DB_NAME!' | Set-Content .env"
    powershell -Command "(Get-Content .env) -replace 'DB_USERNAME=.*', 'DB_USERNAME=!DB_USER!' | Set-Content .env"
    powershell -Command "(Get-Content .env) -replace 'DB_PASSWORD=.*', 'DB_PASSWORD=!DB_PASS!' | Set-Content .env"

    echo [OK] Database configured
)

if "%DB_CHOICE%"=="3" (
    echo [WARNING] Skipping database setup. Configure .env manually before running migrations.
)

REM Install Composer dependencies
echo [==>] Installing PHP dependencies...
%COMPOSER_CMD% install --no-interaction
if %errorlevel% neq 0 (
    echo [ERROR] Failed to install PHP dependencies
    pause
    exit /b 1
)
echo [OK] PHP dependencies installed

REM Generate application key
echo [==>] Generating application key...
php artisan key:generate --force
echo [OK] Application key generated

REM Create storage link
echo [==>] Creating storage link...
php artisan storage:link 2>nul
echo [OK] Storage link created

REM Run migrations (if database configured)
if not "%DB_CHOICE%"=="3" (
    echo [==>] Running database migrations and seeders...
    php artisan migrate --seed --force
    if %errorlevel% neq 0 (
        echo [ERROR] Migration failed. Check your database configuration.
        pause
        exit /b 1
    )
    echo [OK] Database migrated and seeded

    echo [==>] Indexing products...
    php artisan indexer:index
    echo [OK] Products indexed
)

REM Install npm and build assets
if "%HAS_NPM%"=="true" (
    echo [==>] Installing npm dependencies...
    call npm install
    echo [OK] npm dependencies installed

    echo [==>] Building frontend assets...
    call npm run build
    echo [OK] Frontend assets built
)

REM Clear caches
echo [==>] Clearing caches...
php artisan config:clear
php artisan cache:clear
php artisan view:clear
echo [OK] Caches cleared

echo.
echo ============================================
echo        Setup Complete!
echo ============================================
echo.
echo To start the development server, run:
echo   php artisan serve
echo.
echo Then open: http://localhost:8000
echo.
echo Admin panel: http://localhost:8000/admin
echo   Email:    admin@example.com
echo   Password: admin123
echo.

set /p START_SERVER="Start the development server now? [Y/n]: "
if /i "%START_SERVER%"=="" set START_SERVER=Y
if /i "%START_SERVER%"=="Y" (
    echo.
    echo [==>] Starting development server...
    php artisan serve
)

pause
