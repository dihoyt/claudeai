#!/bin/bash

################################################################################
# Proxmox Remove Cluster Configuration Script
#
# Removes all cluster configuration and returns the node to standalone mode.
# WARNING: Run this only when you are the last node in the cluster or want
# to completely destroy the cluster configuration.
#
# Usage: ./remove-cluster.sh
################################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

################################################################################
# Helper Functions
################################################################################

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
    exit 1
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

################################################################################
# Validation Functions
################################################################################

check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root"
    fi
}

get_current_node() {
    CURRENT_NODE=$(hostname)
    log "Running on node: $CURRENT_NODE"
}

check_cluster_exists() {
    if [ ! -f /etc/pve/corosync.conf ]; then
        warn "No cluster configuration found. System may already be standalone."
        exit 0
    fi
}

warn_about_cluster_nodes() {
    echo ""
    echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}                         WARNING${NC}"
    echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "This will completely remove cluster configuration from this node."
    echo "If other nodes are still in the cluster, remove them first using:"
    echo "  ./remove-node-from-cluster.sh"
    echo ""

    # Show current cluster status if available
    if command -v pvecm &> /dev/null; then
        echo -e "${BLUE}Current cluster nodes:${NC}"
        pvecm nodes 2>/dev/null | tail -n +3 || echo "Unable to query cluster nodes"
        echo ""
    fi

    echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
    echo ""

    read -p "Are you sure you want to remove cluster configuration? [y/N]: " -n 1 CONFIRM
    echo ""

    if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
        warn "Operation cancelled by user"
        exit 0
    fi
}

################################################################################
# Cluster Operations
################################################################################

stop_cluster_services() {
    log "Stopping cluster services"

    systemctl stop pve-cluster 2>/dev/null || true
    systemctl stop corosync 2>/dev/null || true

    log "Cluster services stopped"
}

remove_cluster_configuration() {
    log "Removing cluster configuration"

    # Kill any remaining cluster processes
    killall -9 pmxcfs 2>/dev/null || true

    # Unmount pve configuration filesystem
    if mountpoint -q /etc/pve; then
        umount /etc/pve || warn "Failed to unmount /etc/pve"
    fi

    # Remove cluster database
    if [ -f /var/lib/pve-cluster/config.db ]; then
        rm -f /var/lib/pve-cluster/config.db
        log "Removed cluster database"
    fi

    # Remove corosync configuration
    if [ -f /etc/corosync/corosync.conf ]; then
        rm -f /etc/corosync/corosync.conf
        log "Removed corosync configuration"
    fi

    # Remove cluster configuration directory
    if [ -d /etc/pve/nodes ]; then
        rm -rf /etc/pve/nodes/*
    fi

    # Remove cluster files
    rm -f /etc/pve/corosync.conf 2>/dev/null || true
    rm -rf /etc/corosync/* 2>/dev/null || true
}

restart_cluster_services() {
    log "Restarting cluster services in standalone mode"

    # Restart pve-cluster (will run in local mode)
    systemctl start pve-cluster

    # Wait for filesystem to mount
    sleep 5

    if mountpoint -q /etc/pve; then
        log "PVE filesystem mounted successfully"
    else
        error "Failed to mount PVE filesystem"
    fi
}

verify_standalone() {
    log "Verifying standalone configuration"

    # Check if we're in local mode
    if [ -f /var/lib/pve-cluster/.pmxcfs.lockfile ]; then
        log "System is now in standalone mode"
    fi

    # Try to access PVE
    if pvecm status 2>&1 | grep -q "no cluster"; then
        log "Confirmed: No cluster configuration"
    elif pvecm status 2>&1 | grep -q "Cannot initialize"; then
        log "Confirmed: Running in standalone mode"
    fi
}

################################################################################
# Main Script
################################################################################

main() {
    # Validations
    check_root
    get_current_node
    check_cluster_exists

    # Warning and confirmation
    warn_about_cluster_nodes

    log "Removing cluster configuration from $CURRENT_NODE"

    # Stop cluster services
    stop_cluster_services

    # Remove cluster configuration
    remove_cluster_configuration

    # Restart services in standalone mode
    restart_cluster_services

    # Verify standalone mode
    verify_standalone

    # Done
    log "Cluster configuration removed from $(hostname)"
    log "System is now running in standalone mode"
}

main "$@"