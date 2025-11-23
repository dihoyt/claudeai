#!/bin/bash
################################################################################
# MeshCentral Installation and Configuration
################################################################################

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

main() {
    log "=== Starting MeshCentral Installation ==="

    check_root

    # Create meshcentral user
    if ! id -u meshcentral &>/dev/null; then
        log "Creating meshcentral user..."
        useradd -m -s /bin/bash meshcentral
    fi

    # Create directories
    log "Creating MeshCentral directories..."
    create_directory "${MESHCENTRAL_DIR}" "meshcentral" "meshcentral" "755"
    create_directory "${MESHCENTRAL_DIR}/meshcentral-data" "meshcentral" "meshcentral" "755"
    create_directory "${MESHCENTRAL_DIR}/meshcentral-files" "meshcentral" "meshcentral" "755"
    create_directory "${MESHCENTRAL_DIR}/meshcentral-backup" "meshcentral" "meshcentral" "755"

    cd "${MESHCENTRAL_DIR}"

    # Install MeshCentral
    log "Installing MeshCentral via npm..."
    npm install meshcentral@latest || error "Failed to install MeshCentral"

    # Create MeshCentral config
    log "Configuring MeshCentral..."
    cat > "${MESHCENTRAL_DIR}/meshcentral-data/config.json" <<EOF
{
  "settings": {
    "Cert": "${MESH_DOMAIN}",
    "WANonly": true,
    "Minify": 1,
    "Port": ${MESH_PORT},
    "AliasPort": 443,
    "RedirPort": ${MESH_REDIR_PORT},
    "TlsOffload": "127.0.0.1",
    "trustedProxy": "127.0.0.1"
  },
  "domains": {
    "": {
      "Title": "TacticalRMM MeshCentral",
      "Title2": "Remote Management",
      "NewAccounts": false,
      "CertUrl": "https://${API_DOMAIN}",
      "GeoLocation": true,
      "CookieIpCheck": false,
      "mstsc": true
    }
  }
}
EOF

    chown meshcentral:meshcentral "${MESHCENTRAL_DIR}/meshcentral-data/config.json"

    # Create systemd service for MeshCentral
    log "Creating MeshCentral systemd service..."
    cat > /etc/systemd/system/meshcentral.service <<EOF
[Unit]
Description=MeshCentral Server
After=network.target

[Service]
Type=simple
User=meshcentral
Group=meshcentral
ExecStart=/usr/bin/node ${MESHCENTRAL_DIR}/node_modules/meshcentral
WorkingDirectory=${MESHCENTRAL_DIR}
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    chown -R meshcentral:meshcentral "${MESHCENTRAL_DIR}"

    systemctl daemon-reload
    enable_and_start_service meshcentral

    log "=== MeshCentral Installation Completed ==="
}

main "$@"
