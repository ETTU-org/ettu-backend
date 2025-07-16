#!/bin/bash

# ETTU Backend Development Setup Script
# This script sets up the development environment for ETTU Backend

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check system requirements
check_requirements() {
    log_info "Checking system requirements..."
    
    # Check for required tools
    local missing_tools=()
    
    if ! command_exists "curl"; then
        missing_tools+=("curl")
    fi
    
    if ! command_exists "git"; then
        missing_tools+=("git")
    fi
    
    if ! command_exists "docker"; then
        missing_tools+=("docker")
    fi
    
    if ! command_exists "docker-compose"; then
        missing_tools+=("docker-compose")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Please install them before continuing."
        exit 1
    fi
    
    log_success "All required tools are installed"
}

# Install Rust
install_rust() {
    if command_exists "rustc"; then
        log_success "Rust is already installed"
        rustc --version
        return
    fi
    
    log_info "Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source ~/.cargo/env
    
    # Install additional components
    rustup component add rustfmt clippy
    
    log_success "Rust installed successfully"
}

# Install development tools
install_dev_tools() {
    log_info "Installing development tools..."
    
    # SQLx CLI
    if ! command_exists "sqlx"; then
        log_info "Installing SQLx CLI..."
        cargo install sqlx-cli --no-default-features --features postgres
    fi
    
    # Cargo watch
    if ! command_exists "cargo-watch"; then
        log_info "Installing cargo-watch..."
        cargo install cargo-watch
    fi
    
    # Cargo audit
    if ! command_exists "cargo-audit"; then
        log_info "Installing cargo-audit..."
        cargo install cargo-audit
    fi
    
    # Cargo deny
    if ! command_exists "cargo-deny"; then
        log_info "Installing cargo-deny..."
        cargo install cargo-deny
    fi
    
    # Cargo tarpaulin (for coverage)
    if ! command_exists "cargo-tarpaulin"; then
        log_info "Installing cargo-tarpaulin..."
        cargo install cargo-tarpaulin
    fi
    
    log_success "Development tools installed"
}

# Setup environment
setup_environment() {
    log_info "Setting up environment..."
    
    # Copy .env file if it doesn't exist
    if [ ! -f ".env" ]; then
        if [ -f ".env.example" ]; then
            cp .env.example .env
            log_success "Created .env file from .env.example"
        else
            log_error ".env.example file not found"
            exit 1
        fi
    else
        log_info ".env file already exists"
    fi
    
    # Generate random JWT secret if not set
    if ! grep -q "JWT_SECRET=" .env || grep -q "JWT_SECRET=$" .env; then
        log_info "Generating JWT secret..."
        JWT_SECRET=$(openssl rand -hex 32)
        sed -i "s/JWT_SECRET=.*/JWT_SECRET=$JWT_SECRET/" .env
        log_success "JWT secret generated"
    fi
}

# Start services
start_services() {
    log_info "Starting PostgreSQL and Redis services..."
    
    docker-compose -f docker-compose.dev.yml up -d postgres redis
    
    # Wait for services to be ready
    log_info "Waiting for services to start..."
    sleep 5
    
    # Check if services are healthy
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if docker-compose -f docker-compose.dev.yml ps postgres | grep -q "healthy" && \
           docker-compose -f docker-compose.dev.yml ps redis | grep -q "healthy"; then
            log_success "Services are ready"
            break
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            log_error "Services failed to start within expected time"
            exit 1
        fi
        
        log_info "Attempt $attempt/$max_attempts - waiting for services..."
        sleep 2
        ((attempt++))
    done
}

# Setup database
setup_database() {
    log_info "Setting up database..."
    
    # Load environment variables
    source .env
    
    # Create database
    if sqlx database create; then
        log_success "Database created"
    else
        log_info "Database already exists"
    fi
    
    # Run migrations
    if sqlx migrate run; then
        log_success "Migrations completed"
    else
        log_error "Migration failed"
        exit 1
    fi
}

# Install dependencies
install_dependencies() {
    log_info "Installing Rust dependencies..."
    
    if cargo build; then
        log_success "Dependencies installed successfully"
    else
        log_error "Failed to install dependencies"
        exit 1
    fi
}

# Run tests
run_tests() {
    log_info "Running tests..."
    
    if cargo test; then
        log_success "All tests passed"
    else
        log_warning "Some tests failed"
    fi
}

# Setup git hooks
setup_git_hooks() {
    log_info "Setting up git hooks..."
    
    # Create pre-commit hook
    cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
# Pre-commit hook for ETTU Backend

echo "Running pre-commit checks..."

# Check formatting
if ! cargo fmt --check; then
    echo "❌ Code formatting check failed"
    echo "Run 'cargo fmt' to fix formatting issues"
    exit 1
fi

# Run clippy
if ! cargo clippy -- -D warnings; then
    echo "❌ Clippy check failed"
    echo "Fix the clippy warnings before committing"
    exit 1
fi

# Run tests
if ! cargo test; then
    echo "❌ Tests failed"
    echo "Fix the failing tests before committing"
    exit 1
fi

echo "✅ All pre-commit checks passed"
EOF

    chmod +x .git/hooks/pre-commit
    log_success "Git hooks installed"
}

# Main setup function
main() {
    log_info "Starting ETTU Backend development setup..."
    
    # Check if we're in the right directory
    if [ ! -f "Cargo.toml" ]; then
        log_error "This script must be run from the project root directory"
        exit 1
    fi
    
    check_requirements
    install_rust
    install_dev_tools
    setup_environment
    start_services
    setup_database
    install_dependencies
    run_tests
    setup_git_hooks
    
    log_success "Development environment setup completed!"
    echo
    log_info "Next steps:"
    echo "  1. Start the development server: cargo run"
    echo "  2. Or use watch mode: cargo watch -x run"
    echo "  3. Run tests: cargo test"
    echo "  4. Check formatting: cargo fmt"
    echo "  5. Run linter: cargo clippy"
    echo
    log_info "Database tools:"
    echo "  - Adminer: http://localhost:8081"
    echo "  - Redis Commander: http://localhost:8082"
    echo
    log_info "Happy coding! 🚀"
}

# Run main function
main "$@"
