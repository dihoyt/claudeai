#!/bin/bash
################################################################################
# TacticalRMM Deployment Master Script
# For Ubuntu 24.04 LTS
#
# This script orchestrates the complete installation of TacticalRMM by running
# individual installation scripts in sequence and logging results for each.
################################################################################

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load common functions
source "${SCRIPT_DIR}/lib/common.sh"

# Service log directory
SERVICE_LOG_DIR="${SCRIPT_DIR}/logs"
mkdir -p "${SERVICE_LOG_DIR}"

# Color codes
BOLD='\033[1m'

################################################################################
# Service Execution Wrapper
################################################################################

run_service() {
    local script_name=$1
    local description=$2
    local script_path="${SCRIPT_DIR}/install/${script_name}"
    local service_log="${SERVICE_LOG_DIR}/${script_name}.log"

    echo ""
    echo "================================================================================"
    echo -e "${BOLD}${GREEN}Running: ${description}${NC}"
    echo "================================================================================"

    if [[ ! -f "$script_path" ]]; then
        error "Script not found: $script_path"
    fi

    # Make script executable
    chmod +x "$script_path"

    # Run the script and capture output
    local start_time=$(date +%s)

    if bash "$script_path" 2>&1 | tee "$service_log"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log "✓ ${description} completed successfully in ${duration}s"
        echo "SUCCESS" > "${service_log}.status"
        echo "$duration" > "${service_log}.duration"
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        error "✗ ${description} failed after ${duration}s - check log: ${service_log}"
    fi
}

################################################################################
# Post-Installation Tasks
################################################################################

start_services() {
    log "Starting TacticalRMM services..."

    # Start services in order
    enable_and_start_service tacticalrmm
    sleep 2
    enable_and_start_service celery
    sleep 2
    enable_and_start_service celerybeat

    log "Checking service status..."
    local services=("postgresql" "redis-server" "meshcentral" "tacticalrmm" "celery" "celerybeat")

    for service in "${services[@]}"; do
        check_service_status "$service"
    done
}

save_credentials() {
    log "Saving installation credentials..."

    local creds_file="${SCRIPT_DIR}/installation-credentials.txt"

    cat > "$creds_file" <<EOF
================================================================================
TacticalRMM Installation Credentials
Generated: $(date)
================================================================================

WEB INTERFACE:
--------------
Frontend URL: https://${RMM_DOMAIN}
API URL:      https://${API_DOMAIN}
Mesh URL:     https://${MESH_DOMAIN}

Admin Username: ${ADMIN_USERNAME}
Admin Password: ${ADMIN_PASSWORD}

DATABASE:
---------
PostgreSQL Database: ${POSTGRES_DB}
PostgreSQL User:     ${POSTGRES_USER}
PostgreSQL Password: ${POSTGRES_PASSWORD}

REDIS:
------
Redis Password: ${REDIS_PASSWORD}

MESHCENTRAL:
------------
Mesh Token: ${MESH_TOKEN}

IMPORTANT NOTES:
----------------
1. SSL certificates need to be in place at:
   ${SSL_CERT_PATH}
   ${SSL_KEY_PATH}

   Copy your *.hoyt.local wildcard certificate:
   cp /path/to/wildcard.crt ${SSL_CERT_PATH}
   cp /path/to/wildcard.key ${SSL_KEY_PATH}
   chmod 644 ${SSL_CERT_PATH}
   chmod 600 ${SSL_KEY_PATH}

2. After installing certificates, start nginx:
   systemctl start nginx

3. Change the admin password after first login!

4. DNS must be configured for:
   - ${DOMAIN}
   - ${API_DOMAIN}
   - ${RMM_DOMAIN}
   - ${MESH_DOMAIN}

5. This file contains sensitive information - protect it!
   chmod 600 ${creds_file}

TROUBLESHOOTING:
----------------
View service logs:
  journalctl -xeu tacticalrmm
  journalctl -xeu celery
  journalctl -xeu celerybeat
  journalctl -xeu meshcentral
  journalctl -xeu nginx

View installation log:
  cat ${LOG_FILE}

View individual service logs:
  ls -la ${SERVICE_LOG_DIR}/

================================================================================
EOF

    chmod 600 "$creds_file"

    log "Credentials saved to: $creds_file"
}

print_summary() {
    echo ""
    echo "================================================================================"
    echo -e "${BOLD}${GREEN}Installation Summary${NC}"
    echo "================================================================================"
    echo ""

    # Calculate total duration
    local total_duration=0
    for duration_file in "${SERVICE_LOG_DIR}"/*.duration; do
        if [[ -f "$duration_file" ]]; then
            total_duration=$((total_duration + $(cat "$duration_file")))
        fi
    done

    echo "Total installation time: ${total_duration}s ($(($total_duration / 60))m $(($total_duration % 60))s)"
    echo ""
    echo "Individual service results:"
    echo ""

    local failed=0
    for status_file in "${SERVICE_LOG_DIR}"/*.status; do
        if [[ -f "$status_file" ]]; then
            local script_name=$(basename "$status_file" .status)
            local duration=$(cat "${SERVICE_LOG_DIR}/${script_name}.duration" 2>/dev/null || echo "N/A")
            local status=$(cat "$status_file")

            if [[ "$status" == "SUCCESS" ]]; then
                echo -e "  ${GREEN}✓${NC} ${script_name} (${duration}s)"
            else
                echo -e "  ${RED}✗${NC} ${script_name} (${duration}s)"
                failed=$((failed + 1))
            fi
        fi
    done

    echo ""
    if [[ $failed -gt 0 ]]; then
        echo -e "${RED}${failed} service(s) failed. Check logs in: ${SERVICE_LOG_DIR}/${NC}"
        return 1
    else
        echo -e "${GREEN}All services completed successfully!${NC}"
    fi
}

################################################################################
# Main Installation Flow
################################################################################

main() {
    clear
    echo "================================================================================"
    echo "                    TacticalRMM Deployment Script"
    echo "                         Ubuntu 24.04 LTS"
    echo "================================================================================"
    echo ""
    echo "Domain Configuration:"
    echo "  Domain:       ${DOMAIN}"
    echo "  API Domain:   ${API_DOMAIN}"
    echo "  Mesh Domain:  ${MESH_DOMAIN}"
    echo "  RMM Domain:   ${RMM_DOMAIN}"
    echo ""
    echo "Installation will proceed in the following order:"
    echo "  1.  System Prerequisites"
    echo "  2.  PostgreSQL Database"
    echo "  3.  Redis Cache"
    echo "  4.  Nginx Web Server"
    echo "  5.  Node.js Runtime"
    echo "  6.  Python Environment"
    echo "  7.  MeshCentral Server"
    echo "  8.  TacticalRMM Backend"
    echo "  9.  Systemd Services"
    echo "  10. TacticalRMM Frontend"
    echo "  11. Nginx Configuration"
    echo "  12. Firewall Configuration"
    echo ""
    echo "Installation log: ${LOG_FILE}"
    echo "Service logs:     ${SERVICE_LOG_DIR}/"
    echo ""
    echo "================================================================================"
    echo ""

    read -p "Press Enter to continue or Ctrl+C to cancel..."

    log "Starting TacticalRMM deployment..."

    # Run installation scripts in sequence
    run_service "01-system-prerequisites.sh" "System Prerequisites"
    run_service "02-postgresql.sh" "PostgreSQL Installation"
    run_service "03-redis.sh" "Redis Installation"
    run_service "04-nginx.sh" "Nginx Installation"
    run_service "05-nodejs.sh" "Node.js Installation"
    run_service "06-python.sh" "Python Installation"
    run_service "07-meshcentral.sh" "MeshCentral Installation"
    run_service "08-tacticalrmm-backend.sh" "TacticalRMM Backend"
    run_service "09-systemd-services.sh" "Systemd Services Configuration"
    run_service "10-frontend.sh" "TacticalRMM Frontend"
    run_service "11-nginx-config.sh" "Nginx Configuration"
    run_service "12-firewall.sh" "Firewall Configuration"

    # Post-installation tasks
    start_services
    save_credentials

    # Print summary
    print_summary

    echo ""
    echo "================================================================================"
    echo "                    Installation Complete!"
    echo "================================================================================"
    echo ""
    echo -e "${GREEN}✓${NC} TacticalRMM has been deployed successfully!"
    echo ""
    echo "Next steps:"
    echo ""
    echo "1. Copy your wildcard SSL certificate:"
    echo -e "   ${YELLOW}cp /path/to/wildcard.crt ${SSL_CERT_PATH}${NC}"
    echo -e "   ${YELLOW}cp /path/to/wildcard.key ${SSL_KEY_PATH}${NC}"
    echo -e "   ${YELLOW}chmod 644 ${SSL_CERT_PATH}${NC}"
    echo -e "   ${YELLOW}chmod 600 ${SSL_KEY_PATH}${NC}"
    echo ""
    echo "2. Start nginx:"
    echo -e "   ${YELLOW}systemctl start nginx${NC}"
    echo ""
    echo "3. Access TacticalRMM:"
    echo -e "   ${GREEN}https://${RMM_DOMAIN}${NC}"
    echo ""
    echo "4. Review credentials:"
    echo -e "   ${YELLOW}cat ${SCRIPT_DIR}/installation-credentials.txt${NC}"
    echo ""
    echo "5. Verify all services:"
    echo -e "   ${YELLOW}systemctl status tacticalrmm celery celerybeat meshcentral nginx${NC}"
    echo ""
    echo "Installation logs: ${SERVICE_LOG_DIR}/"
    echo "================================================================================"
}

main "$@"
