#!/bin/bash
################################################################################
# PostgreSQL Installation and Configuration
################################################################################

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

main() {
    log "=== Starting PostgreSQL Installation ==="

    check_root

    log "Installing PostgreSQL..."
    install_packages postgresql postgresql-contrib

    enable_and_start_service postgresql

    # Create database and user
    log "Creating TacticalRMM database and user..."
    sudo -u postgres psql <<EOF
CREATE DATABASE ${POSTGRES_DB};
CREATE USER ${POSTGRES_USER} WITH PASSWORD '${POSTGRES_PASSWORD}';
ALTER ROLE ${POSTGRES_USER} SET client_encoding TO 'utf8';
ALTER ROLE ${POSTGRES_USER} SET default_transaction_isolation TO 'read committed';
ALTER ROLE ${POSTGRES_USER} SET timezone TO 'UTC';
ALTER DATABASE ${POSTGRES_DB} OWNER TO ${POSTGRES_USER};
GRANT ALL PRIVILEGES ON DATABASE ${POSTGRES_DB} TO ${POSTGRES_USER};
\c ${POSTGRES_DB}
GRANT ALL ON SCHEMA public TO ${POSTGRES_USER};
\q
EOF

    # Configure PostgreSQL for local connections
    log "Configuring PostgreSQL authentication..."
    PG_VERSION=$(psql --version | grep -oP '\d+' | head -1)
    PG_HBA="/etc/postgresql/${PG_VERSION}/main/pg_hba.conf"

    if [[ ! -f "$PG_HBA" ]]; then
        error "PostgreSQL configuration file not found at $PG_HBA"
    fi

    backup_file "$PG_HBA"

    if ! grep -q "${POSTGRES_DB}" "$PG_HBA"; then
        echo "local   ${POSTGRES_DB}     ${POSTGRES_USER}                             md5" >> "$PG_HBA"
        log "Added PostgreSQL authentication rule"
    fi

    systemctl restart postgresql
    check_service_status postgresql

    log "=== PostgreSQL Installation Completed ==="
}

main "$@"
