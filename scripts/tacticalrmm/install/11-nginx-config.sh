#!/bin/bash
################################################################################
# Nginx Configuration
################################################################################

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

main() {
    log "=== Starting Nginx Configuration ==="

    check_root

    # API configuration
    log "Creating Nginx API configuration..."
    cat > /etc/nginx/sites-available/rmm-api.conf <<EOF
upstream tacticalrmm {
    server 127.0.0.1:${GUNICORN_PORT};
}

server {
    listen 80;
    server_name ${API_DOMAIN};
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ${API_DOMAIN};

    ssl_certificate ${SSL_CERT_PATH};
    ssl_certificate_key ${SSL_KEY_PATH};
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    client_max_body_size 300M;

    location /static/ {
        alias ${INSTALL_DIR}/api/tacticalrmm/static/;
    }

    location /private/ {
        internal;
        alias ${INSTALL_DIR}/api/tacticalrmm/tacticalrmm/private/;
    }

    location / {
        proxy_pass http://tacticalrmm;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

    # Frontend configuration
    log "Creating Nginx frontend configuration..."
    cat > /etc/nginx/sites-available/rmm-frontend.conf <<EOF
server {
    listen 80;
    server_name ${RMM_DOMAIN};
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ${RMM_DOMAIN};

    ssl_certificate ${SSL_CERT_PATH};
    ssl_certificate_key ${SSL_KEY_PATH};
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    root ${WEB_ROOT};
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)\$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

    # MeshCentral configuration
    log "Creating Nginx MeshCentral configuration..."
    cat > /etc/nginx/sites-available/rmm-meshcentral.conf <<EOF
upstream meshcentral {
    server 127.0.0.1:${MESH_PORT};
}

server {
    listen 80;
    server_name ${MESH_DOMAIN};
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ${MESH_DOMAIN};

    ssl_certificate ${SSL_CERT_PATH};
    ssl_certificate_key ${SSL_KEY_PATH};
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    location / {
        proxy_pass http://meshcentral;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_buffering off;
        proxy_read_timeout 86400;
    }
}
EOF

    # Enable sites
    log "Enabling Nginx sites..."
    ln -sf /etc/nginx/sites-available/rmm-api.conf /etc/nginx/sites-enabled/
    ln -sf /etc/nginx/sites-available/rmm-frontend.conf /etc/nginx/sites-enabled/
    ln -sf /etc/nginx/sites-available/rmm-meshcentral.conf /etc/nginx/sites-enabled/

    # Remove default site
    rm -f /etc/nginx/sites-enabled/default

    # Test configuration
    log "Testing Nginx configuration..."
    nginx -t || error "Nginx configuration test failed"

    log "=== Nginx Configuration Completed ==="
    info "Note: Nginx will not start until SSL certificates are in place"
}

main "$@"
