#!/bin/bash

#############################################
# Bagisto Quick Setup Script (Unix/macOS/Linux)
#############################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo ""
echo "============================================"
echo "       Bagisto Quick Setup Script"
echo "============================================"
echo ""

# Check PHP
print_step "Checking PHP installation..."
if ! command -v php &> /dev/null; then
    print_error "PHP is not installed. Please install PHP 8.2+ first."
    exit 1
fi
PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
print_success "PHP $PHP_VERSION found"

# Check if Composer is available
print_step "Checking Composer..."
if command -v composer &> /dev/null; then
    COMPOSER_CMD="composer"
    print_success "Composer found globally"
elif [ -f "./composer" ]; then
    COMPOSER_CMD="php ./composer"
    print_success "Composer found locally"
elif [ -f "./composer.phar" ]; then
    COMPOSER_CMD="php ./composer.phar"
    print_success "Composer.phar found locally"
else
    print_warning "Composer not found. Downloading..."
    curl -sS https://getcomposer.org/installer | php -- --filename=composer
    COMPOSER_CMD="php ./composer"
    print_success "Composer downloaded"
fi

# Check Node.js/npm
print_step "Checking Node.js/npm..."
if ! command -v npm &> /dev/null; then
    print_warning "npm not found. Frontend assets won't be built."
    HAS_NPM=false
else
    NPM_VERSION=$(npm -v)
    print_success "npm $NPM_VERSION found"
    HAS_NPM=true
fi

# Create .env file
print_step "Setting up environment file..."
if [ ! -f ".env" ]; then
    cp .env.example .env
    print_success ".env file created"
else
    print_warning ".env file already exists, skipping"
fi

# Database configuration
echo ""
echo "============================================"
echo "       Database Configuration"
echo "============================================"
echo ""
echo "Choose database setup:"
echo "  1) MySQL (Docker) - Recommended for quick start"
echo "  2) MySQL (Local) - Use existing MySQL installation"
echo "  3) Skip - Configure manually later"
echo ""
read -p "Enter choice [1-3]: " DB_CHOICE

case $DB_CHOICE in
    1)
        print_step "Setting up MySQL with Docker..."
        if ! command -v docker &> /dev/null; then
            print_error "Docker is not installed. Please install Docker first."
            exit 1
        fi

        # Check if Docker is running
        if ! docker info &> /dev/null 2>&1; then
            print_warning "Docker daemon not running. Attempting to start..."
            if command -v colima &> /dev/null; then
                colima start
            else
                print_error "Please start Docker Desktop manually and re-run this script."
                exit 1
            fi
        fi

        # Check if container already exists
        if docker ps -a | grep -q bagisto-mysql; then
            print_warning "bagisto-mysql container already exists"
            docker start bagisto-mysql 2>/dev/null || true
        else
            docker run --name bagisto-mysql \
                -e MYSQL_ROOT_PASSWORD=bagisto \
                -e MYSQL_DATABASE=bagisto \
                -p 3306:3306 \
                -d mysql:8.0
        fi

        print_step "Waiting for MySQL to be ready..."
        sleep 15

        # Update .env
        sed -i.bak 's/DB_HOST=.*/DB_HOST=127.0.0.1/' .env
        sed -i.bak 's/DB_PORT=.*/DB_PORT=3306/' .env
        sed -i.bak 's/DB_DATABASE=.*/DB_DATABASE=bagisto/' .env
        sed -i.bak 's/DB_USERNAME=.*/DB_USERNAME=root/' .env
        sed -i.bak 's/DB_PASSWORD=.*/DB_PASSWORD=bagisto/' .env
        rm -f .env.bak

        print_success "MySQL container started"
        ;;
    2)
        echo ""
        read -p "Database host [127.0.0.1]: " DB_HOST
        DB_HOST=${DB_HOST:-127.0.0.1}
        read -p "Database port [3306]: " DB_PORT
        DB_PORT=${DB_PORT:-3306}
        read -p "Database name [bagisto]: " DB_NAME
        DB_NAME=${DB_NAME:-bagisto}
        read -p "Database username [root]: " DB_USER
        DB_USER=${DB_USER:-root}
        read -sp "Database password: " DB_PASS
        echo ""

        sed -i.bak "s/DB_HOST=.*/DB_HOST=$DB_HOST/" .env
        sed -i.bak "s/DB_PORT=.*/DB_PORT=$DB_PORT/" .env
        sed -i.bak "s/DB_DATABASE=.*/DB_DATABASE=$DB_NAME/" .env
        sed -i.bak "s/DB_USERNAME=.*/DB_USERNAME=$DB_USER/" .env
        sed -i.bak "s/DB_PASSWORD=.*/DB_PASSWORD=$DB_PASS/" .env
        rm -f .env.bak

        print_success "Database configured"
        ;;
    3)
        print_warning "Skipping database setup. Configure .env manually before running migrations."
        ;;
esac

# Install Composer dependencies
print_step "Installing PHP dependencies..."
$COMPOSER_CMD install --no-interaction
print_success "PHP dependencies installed"

# Generate application key
print_step "Generating application key..."
php artisan key:generate --force
print_success "Application key generated"

# Create storage link
print_step "Creating storage link..."
php artisan storage:link 2>/dev/null || true
print_success "Storage link created"

# Run migrations (if database configured)
if [ "$DB_CHOICE" != "3" ]; then
    print_step "Running database migrations and seeders..."
    php artisan migrate --seed --force
    print_success "Database migrated and seeded"

    # Run indexer
    print_step "Indexing products..."
    php artisan indexer:index
    print_success "Products indexed"
fi

# Install npm and build assets
if [ "$HAS_NPM" = true ]; then
    print_step "Installing npm dependencies..."
    npm install
    print_success "npm dependencies installed"

    print_step "Building frontend assets..."
    npm run build
    print_success "Frontend assets built"
fi

# Clear caches
print_step "Clearing caches..."
php artisan config:clear
php artisan cache:clear
php artisan view:clear
print_success "Caches cleared"

echo ""
echo "============================================"
echo "       Setup Complete!"
echo "============================================"
echo ""
echo "To start the development server, run:"
echo "  php artisan serve"
echo ""
echo "Then open: http://localhost:8000"
echo ""
echo "Admin panel: http://localhost:8000/admin"
echo "  Email:    admin@example.com"
echo "  Password: admin123"
echo ""

# Ask if user wants to start server now
read -p "Start the development server now? [Y/n]: " START_SERVER
START_SERVER=${START_SERVER:-Y}
if [[ $START_SERVER =~ ^[Yy]$ ]]; then
    echo ""
    print_step "Starting development server..."
    php artisan serve
fi
