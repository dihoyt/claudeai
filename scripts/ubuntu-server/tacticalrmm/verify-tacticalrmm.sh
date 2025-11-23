#!/bin/bash

################################################################################
# TacticalRMM Installation Verification Script
# For Ubuntu 24.04 LTS
#
# This script verifies that all TacticalRMM components were installed
# successfully and are running properly.
################################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Domain configuration (should match installation)
DOMAIN="tacticalrmm.hoyt.local"
API_DOMAIN="api.${DOMAIN}"
MESH_DOMAIN="mesh.${DOMAIN}"
RMM_DOMAIN="rmm.${DOMAIN}"

# Verification counters
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNING=0

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo ""
    echo "================================================================================"
    echo "$1"
    echo "================================================================================"
    echo ""
}

print_section() {
    echo ""
    echo -e "${BLUE}━━━ $1 ━━━${NC}"
}

check_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((CHECKS_PASSED++))
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
    ((CHECKS_FAILED++))
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((CHECKS_WARNING++))
}

check_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

################################################################################
# Verification Functions
################################################################################

verify_system() {
    print_section "System Requirements"

    # Check OS version
    if grep -q "Ubuntu 24.04" /etc/os-release 2>/dev/null; then
        check_pass "Ubuntu 24.04 LTS detected"
    else
        check_fail "Not running Ubuntu 24.04 LTS"
    fi

    # Check RAM
    local total_ram=$(free -g | awk '/^Mem:/{print $2}')
    if [[ $total_ram -ge 7 ]]; then
        check_pass "Sufficient RAM: ${total_ram}GB (recommended: 8GB+)"
    else
        check_warn "Low RAM: ${total_ram}GB (recommended: 8GB+)"
    fi

    # Check CPU cores
    local cpu_cores=$(nproc)
    if [[ $cpu_cores -ge 4 ]]; then
        check_pass "Sufficient CPU cores: ${cpu_cores} (recommended: 4+)"
    else
        check_warn "Low CPU cores: ${cpu_cores} (recommended: 4+)"
    fi

    # Check disk space
    local available_space=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ $available_space -ge 20 ]]; then
        check_pass "Sufficient disk space: ${available_space}GB available (recommended: 30GB+)"
    else
        check_warn "Low disk space: ${available_space}GB available (recommended: 30GB+)"
    fi
}

verify_users() {
    print_section "User Accounts"

    if id -u tactical &>/dev/null; then
        check_pass "User 'tactical' exists"
    else
        check_fail "User 'tactical' not found"
    fi

    if id -u meshcentral &>/dev/null; then
        check_pass "User 'meshcentral' exists"
    else
        check_fail "User 'meshcentral' not found"
    fi
}

verify_directories() {
    print_section "Directory Structure"

    local directories=(
        "/rmm"
        "/rmm/api/tacticalrmm"
        "/rmm/env"
        "/var/log/celery"
        "/var/www/rmm"
        "/meshcentral"
        "/meshcentral/meshcentral-data"
        "/etc/nginx/ssl"
    )

    for dir in "${directories[@]}"; do
        if [[ -d "$dir" ]]; then
            check_pass "Directory exists: $dir"
        else
            check_fail "Directory missing: $dir"
        fi
    done
}

verify_postgresql() {
    print_section "PostgreSQL Database"

    # Check if PostgreSQL is installed
    if command -v psql &>/dev/null; then
        local pg_version=$(psql --version | grep -oP '\d+' | head -1)
        check_pass "PostgreSQL $pg_version installed"
    else
        check_fail "PostgreSQL not installed"
        return
    fi

    # Check if PostgreSQL service is running
    if systemctl is-active --quiet postgresql; then
        check_pass "PostgreSQL service is running"
    else
        check_fail "PostgreSQL service is not running"
    fi

    # Check if database exists
    if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw tacticalrmm; then
        check_pass "Database 'tacticalrmm' exists"
    else
        check_fail "Database 'tacticalrmm' not found"
    fi

    # Check if user exists
    if sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='tacticalrmm'" | grep -q 1; then
        check_pass "Database user 'tacticalrmm' exists"
    else
        check_fail "Database user 'tacticalrmm' not found"
    fi
}

verify_redis() {
    print_section "Redis Cache"

    # Check if Redis is installed
    if command -v redis-cli &>/dev/null; then
        check_pass "Redis installed"
    else
        check_fail "Redis not installed"
        return
    fi

    # Check if Redis service is running
    if systemctl is-active --quiet redis-server; then
        check_pass "Redis service is running"
    else
        check_fail "Redis service is not running"
    fi

    # Check Redis configuration
    local redis_conf=$(find /etc -name redis.conf 2>/dev/null | head -1)
    if [[ -f "$redis_conf" ]]; then
        if grep -q "^requirepass" "$redis_conf"; then
            check_pass "Redis password authentication configured"
        else
            check_warn "Redis password authentication not configured"
        fi
    else
        check_warn "Redis configuration file not found"
    fi
}

verify_python() {
    print_section "Python Environment"

    # Check Python version
    if command -v python3 &>/dev/null; then
        local python_version=$(python3 --version | grep -oP '\d+\.\d+')
        check_pass "Python $python_version installed"
    else
        check_fail "Python 3 not installed"
        return
    fi

    # Check virtual environment
    if [[ -d "/rmm/env" ]]; then
        check_pass "Python virtual environment exists"

        # Check if virtual environment has required packages
        if [[ -f "/rmm/env/bin/pip" ]]; then
            check_pass "pip installed in virtual environment"
        else
            check_fail "pip not found in virtual environment"
        fi

        if [[ -f "/rmm/env/bin/gunicorn" ]]; then
            check_pass "gunicorn installed in virtual environment"
        else
            check_fail "gunicorn not found in virtual environment"
        fi

        if [[ -f "/rmm/env/bin/celery" ]]; then
            check_pass "celery installed in virtual environment"
        else
            check_fail "celery not found in virtual environment"
        fi
    else
        check_fail "Python virtual environment not found"
    fi
}

verify_nodejs() {
    print_section "Node.js & npm"

    if command -v node &>/dev/null; then
        local node_version=$(node --version)
        check_pass "Node.js installed: $node_version"
    else
        check_fail "Node.js not installed"
    fi

    if command -v npm &>/dev/null; then
        local npm_version=$(npm --version)
        check_pass "npm installed: $npm_version"
    else
        check_fail "npm not installed"
    fi
}

verify_meshcentral() {
    print_section "MeshCentral"

    # Check if MeshCentral is installed
    if [[ -d "/meshcentral/node_modules/meshcentral" ]]; then
        check_pass "MeshCentral installed"
    else
        check_fail "MeshCentral not found"
    fi

    # Check MeshCentral configuration
    if [[ -f "/meshcentral/meshcentral-data/config.json" ]]; then
        check_pass "MeshCentral configuration exists"
    else
        check_fail "MeshCentral configuration not found"
    fi

    # Check MeshCentral service
    if systemctl is-enabled --quiet meshcentral 2>/dev/null; then
        check_pass "MeshCentral service is enabled"
    else
        check_fail "MeshCentral service is not enabled"
    fi

    if systemctl is-active --quiet meshcentral; then
        check_pass "MeshCentral service is running"
    else
        check_fail "MeshCentral service is not running"
    fi

    # Check if MeshCentral is listening
    if ss -tlnp | grep -q ":4430"; then
        check_pass "MeshCentral listening on port 4430"
    else
        check_fail "MeshCentral not listening on port 4430"
    fi
}

verify_tacticalrmm() {
    print_section "TacticalRMM Backend"

    # Check if TacticalRMM code exists
    if [[ -d "/rmm/api/tacticalrmm" ]]; then
        check_pass "TacticalRMM code directory exists"
    else
        check_fail "TacticalRMM code directory not found"
        return
    fi

    # Check Django settings
    if [[ -f "/rmm/api/tacticalrmm/tacticalrmm/local_settings.py" ]]; then
        check_pass "Django local settings configured"
    else
        check_fail "Django local settings not found"
    fi

    # Check if migrations have been run
    if [[ -d "/rmm/api/tacticalrmm/accounts/migrations" ]]; then
        check_pass "Django migrations directory exists"
    else
        check_warn "Django migrations directory not found"
    fi

    # Check static files
    if [[ -d "/rmm/api/tacticalrmm/static" ]]; then
        check_pass "Django static files collected"
    else
        check_warn "Django static files not found"
    fi
}

verify_frontend() {
    print_section "TacticalRMM Frontend"

    # Check if frontend is built
    if [[ -d "/var/www/rmm" ]] && [[ -f "/var/www/rmm/index.html" ]]; then
        check_pass "Frontend files deployed"
    else
        check_fail "Frontend files not found"
    fi

    # Check ownership
    if [[ -d "/var/www/rmm" ]]; then
        local owner=$(stat -c '%U' /var/www/rmm)
        if [[ "$owner" == "www-data" ]]; then
            check_pass "Frontend files owned by www-data"
        else
            check_warn "Frontend files not owned by www-data (owner: $owner)"
        fi
    fi
}

verify_nginx() {
    print_section "Nginx Web Server"

    # Check if Nginx is installed
    if command -v nginx &>/dev/null; then
        local nginx_version=$(nginx -v 2>&1 | grep -oP '\d+\.\d+\.\d+')
        check_pass "Nginx installed: $nginx_version"
    else
        check_fail "Nginx not installed"
        return
    fi

    # Check Nginx service
    if systemctl is-enabled --quiet nginx; then
        check_pass "Nginx service is enabled"
    else
        check_warn "Nginx service is not enabled"
    fi

    if systemctl is-active --quiet nginx; then
        check_pass "Nginx service is running"
    else
        check_warn "Nginx service is not running (expected - awaiting SSL certificates)"
    fi

    # Check Nginx configuration files
    local nginx_configs=(
        "/etc/nginx/sites-available/rmm-api.conf"
        "/etc/nginx/sites-available/rmm-frontend.conf"
        "/etc/nginx/sites-available/rmm-meshcentral.conf"
    )

    for config in "${nginx_configs[@]}"; do
        if [[ -f "$config" ]]; then
            check_pass "Nginx config exists: $(basename $config)"
        else
            check_fail "Nginx config missing: $(basename $config)"
        fi
    done

    # Check if sites are enabled
    local enabled_sites=(
        "/etc/nginx/sites-enabled/rmm-api.conf"
        "/etc/nginx/sites-enabled/rmm-frontend.conf"
        "/etc/nginx/sites-enabled/rmm-meshcentral.conf"
    )

    for site in "${enabled_sites[@]}"; do
        if [[ -L "$site" ]]; then
            check_pass "Site enabled: $(basename $site)"
        else
            check_fail "Site not enabled: $(basename $site)"
        fi
    done

    # Check SSL certificates
    if [[ -f "/etc/nginx/ssl/wildcard.crt" ]] && [[ -f "/etc/nginx/ssl/wildcard.key" ]]; then
        check_pass "SSL certificates installed"
    else
        check_warn "SSL certificates not installed yet (expected during initial setup)"
    fi

    # Test Nginx configuration
    if nginx -t &>/dev/null; then
        check_pass "Nginx configuration is valid"
    else
        check_warn "Nginx configuration has errors (may be due to missing SSL certificates)"
    fi
}

verify_systemd_services() {
    print_section "Systemd Services"

    local services=(
        "postgresql"
        "redis-server"
        "meshcentral"
        "tacticalrmm"
        "celery"
        "celerybeat"
    )

    for service in "${services[@]}"; do
        # Check if service exists
        if systemctl list-unit-files | grep -q "^${service}.service"; then
            check_pass "Service exists: $service"

            # Check if enabled
            if systemctl is-enabled --quiet "$service" 2>/dev/null; then
                check_pass "  ├─ Enabled at boot"
            else
                check_warn "  ├─ Not enabled at boot"
            fi

            # Check if active
            if systemctl is-active --quiet "$service"; then
                check_pass "  └─ Currently running"
            else
                check_fail "  └─ Not running"
            fi
        else
            check_fail "Service not found: $service"
        fi
    done
}

verify_network() {
    print_section "Network Configuration"

    # Check firewall
    if command -v ufw &>/dev/null; then
        check_pass "UFW firewall installed"

        if ufw status | grep -q "Status: active"; then
            check_pass "Firewall is active"

            # Check if required ports are allowed
            if ufw status | grep -q "80/tcp"; then
                check_pass "HTTP port (80) allowed"
            else
                check_warn "HTTP port (80) not allowed"
            fi

            if ufw status | grep -q "443/tcp"; then
                check_pass "HTTPS port (443) allowed"
            else
                check_warn "HTTPS port (443) not allowed"
            fi

            if ufw status | grep -q "22/tcp"; then
                check_pass "SSH port (22) allowed"
            else
                check_warn "SSH port (22) not allowed"
            fi
        else
            check_warn "Firewall is not active"
        fi
    else
        check_warn "UFW firewall not installed"
    fi

    # Check if ports are listening
    print_section "Listening Ports"

    if ss -tlnp | grep -q ":8000"; then
        check_pass "TacticalRMM API listening on port 8000"
    else
        check_fail "TacticalRMM API not listening on port 8000"
    fi

    if ss -tlnp | grep -q ":4430"; then
        check_pass "MeshCentral listening on port 4430"
    else
        check_fail "MeshCentral not listening on port 4430"
    fi

    if systemctl is-active --quiet nginx; then
        if ss -tlnp | grep -q ":80"; then
            check_pass "Nginx listening on port 80 (HTTP)"
        else
            check_warn "Nginx not listening on port 80"
        fi

        if ss -tlnp | grep -q ":443"; then
            check_pass "Nginx listening on port 443 (HTTPS)"
        else
            check_warn "Nginx not listening on port 443"
        fi
    fi
}

verify_dns() {
    print_section "DNS Resolution"

    local domains=(
        "$RMM_DOMAIN"
        "$API_DOMAIN"
        "$MESH_DOMAIN"
    )

    for domain in "${domains[@]}"; do
        if host "$domain" &>/dev/null; then
            local ip=$(host "$domain" | grep "has address" | awk '{print $4}')
            check_pass "DNS resolves: $domain → $ip"
        else
            check_warn "DNS not configured: $domain"
        fi
    done
}

verify_logs() {
    print_section "Log Files"

    # Check installation log
    if [[ -f "/var/log/tacticalrmm-install.log" ]]; then
        check_pass "Installation log exists"
    else
        check_warn "Installation log not found"
    fi

    # Check Celery logs
    if [[ -f "/var/log/celery/celery.log" ]]; then
        check_pass "Celery log exists"
    else
        check_warn "Celery log not found"
    fi

    if [[ -f "/var/log/celery/beat.log" ]]; then
        check_pass "Celery beat log exists"
    else
        check_warn "Celery beat log not found"
    fi
}

verify_credentials() {
    print_section "Credentials File"

    if [[ -f "/root/tacticalrmm-credentials.txt" ]]; then
        check_pass "Credentials file exists"

        # Check permissions
        local perms=$(stat -c '%a' /root/tacticalrmm-credentials.txt)
        if [[ "$perms" == "600" ]]; then
            check_pass "Credentials file has correct permissions (600)"
        else
            check_warn "Credentials file permissions: $perms (should be 600)"
        fi
    else
        check_fail "Credentials file not found"
    fi
}

verify_qemu_agent() {
    print_section "Proxmox Integration"

    # Check if QEMU guest agent is installed
    if command -v qemu-ga &>/dev/null; then
        check_pass "QEMU Guest Agent installed"

        if systemctl is-active --quiet qemu-guest-agent; then
            check_pass "QEMU Guest Agent is running"
        else
            check_warn "QEMU Guest Agent is not running"
        fi
    else
        check_warn "QEMU Guest Agent not installed (optional for Proxmox)"
    fi
}

check_service_errors() {
    print_section "Recent Service Errors"

    local services=("tacticalrmm" "celery" "celerybeat" "meshcentral" "nginx")
    local errors_found=false

    for service in "${services[@]}"; do
        if systemctl list-unit-files | grep -q "^${service}.service"; then
            local errors=$(journalctl -u "$service" -p err -n 5 --no-pager --since "1 hour ago" 2>/dev/null)
            if [[ -n "$errors" ]]; then
                check_warn "Recent errors in $service service"
                errors_found=true
            fi
        fi
    done

    if ! $errors_found; then
        check_pass "No recent service errors detected"
    fi
}

################################################################################
# Main Verification Flow
################################################################################

main() {
    clear
    print_header "TacticalRMM Installation Verification"

    echo "This script will verify that TacticalRMM was installed correctly."
    echo "Domain: $DOMAIN"
    echo ""

    # Run all verification checks
    verify_system
    verify_users
    verify_directories
    verify_postgresql
    verify_redis
    verify_python
    verify_nodejs
    verify_meshcentral
    verify_tacticalrmm
    verify_frontend
    verify_nginx
    verify_systemd_services
    verify_network
    verify_dns
    verify_logs
    verify_credentials
    verify_qemu_agent
    check_service_errors

    # Summary
    print_header "Verification Summary"

    local total_checks=$((CHECKS_PASSED + CHECKS_FAILED + CHECKS_WARNING))

    echo -e "${GREEN}Passed:${NC}   $CHECKS_PASSED"
    echo -e "${RED}Failed:${NC}   $CHECKS_FAILED"
    echo -e "${YELLOW}Warnings:${NC} $CHECKS_WARNING"
    echo -e "Total:    $total_checks"
    echo ""

    if [[ $CHECKS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✓ Installation verification completed successfully!${NC}"
        echo ""

        if [[ $CHECKS_WARNING -gt 0 ]]; then
            echo -e "${YELLOW}Note: Some warnings were found but these may be expected during initial setup.${NC}"
            echo ""
        fi

        echo "Next steps:"
        echo "1. Install SSL certificates if not already done"
        echo "2. Start Nginx: systemctl start nginx"
        echo "3. Access TacticalRMM at: https://$RMM_DOMAIN"
        echo "4. Review credentials: cat /root/tacticalrmm-credentials.txt"

    else
        echo -e "${RED}✗ Installation verification found issues that need attention.${NC}"
        echo ""
        echo "Please review the failed checks above and:"
        echo "1. Check service logs: journalctl -xeu <service-name>"
        echo "2. Review installation log: /var/log/tacticalrmm-install.log"
        echo "3. Ensure all installation steps completed successfully"
    fi

    echo ""
    print_header "Detailed Service Status"

    # Show detailed status of key services
    systemctl status tacticalrmm --no-pager -l | head -n 15
    echo ""
    systemctl status celery --no-pager -l | head -n 15
    echo ""
    systemctl status meshcentral --no-pager -l | head -n 15

    echo ""
    echo "================================================================================"
    echo "Verification complete. For more details, check individual service logs."
    echo "================================================================================"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Error: This script must be run as root${NC}"
    echo "Please run: sudo $0"
    exit 1
fi

main "$@"
