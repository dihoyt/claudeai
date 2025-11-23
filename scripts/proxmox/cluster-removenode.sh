#!/bin/bash

################################################################################
# Proxmox Remove Node from Cluster Script
#
# Displays cluster nodes and allows selection of which node to remove from
# the cluster without destroying the cluster configuration.
#
# Usage: Run this on the node you want to KEEP
#        ./remove-node-from-cluster.sh
################################################################################

set -e

# Configuration
NODE_TO_REMOVE=""

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
        error "No cluster configuration found. System is not part of a cluster."
    fi
}

display_and_select_node() {
    echo ""
    echo -e "${BLUE}Current Cluster Nodes:${NC}"
    echo ""

    # Get list of nodes (skip header lines)
    pvecm nodes | tail -n +3

    echo ""

    # Get available nodes (excluding current node)
    # Extract the Name column (last column) and filter out current node and "(local)" marker
    AVAILABLE_NODES=$(pvecm nodes | tail -n +3 | awk '{
        # Get the last field (Name column)
        name = $NF
        # If it ends with "(local)", remove that marker
        if (name ~ /\(local\)$/) {
            sub(/[[:space:]]*\(local\)$/, "", $(NF-1))
            name = $(NF-1)
        }
        print name
    }' | grep -v "^$CURRENT_NODE$")

    if [ -z "$AVAILABLE_NODES" ]; then
        error "No other nodes found in cluster. Only the current node exists."
    fi

    # Display available nodes to remove
    echo -e "${YELLOW}Available nodes to remove (excluding current node $CURRENT_NODE):${NC}"
    echo "$AVAILABLE_NODES" | nl -w2 -s'. '
    echo ""

    # Prompt for selection
    while true; do
        read -p "Enter the number of the node to remove: " SELECTION

        # Get the node name from selection
        NODE_TO_REMOVE=$(echo "$AVAILABLE_NODES" | sed -n "${SELECTION}p")

        if [ -n "$NODE_TO_REMOVE" ]; then
            echo ""
            log "Selected node to remove: $NODE_TO_REMOVE"

            # Confirm selection
            echo ""
            read -p "Are you sure you want to remove $NODE_TO_REMOVE from the cluster? [y/N]: " -n 1 CONFIRM
            echo ""

            if [[ $CONFIRM =~ ^[Yy]$ ]]; then
                break
            else
                echo ""
                warn "Selection cancelled. Please choose again."
                echo "$AVAILABLE_NODES" | nl -w2 -s'. '
                echo ""
            fi
        else
            warn "Invalid selection. Please try again."
        fi
    done
}

################################################################################
# Cluster Operations
################################################################################

remove_node_from_cluster() {
    log "Removing node $NODE_TO_REMOVE from cluster"

    # Check if node exists in cluster
    if ! pvecm nodes | grep -q "$NODE_TO_REMOVE"; then
        warn "Node $NODE_TO_REMOVE not found in cluster"
        return 0
    fi

    # Remove the node
    if pvecm delnode "$NODE_TO_REMOVE"; then
        log "Node $NODE_TO_REMOVE removed from cluster successfully"
    else
        error "Failed to remove node $NODE_TO_REMOVE from cluster"
    fi
}

show_cluster_status() {
    echo ""
    echo -e "${BLUE}Updated Cluster Status:${NC}"
    echo ""
    pvecm nodes | tail -n +3
    echo ""
}

################################################################################
# Main Script
################################################################################

main() {
    # Validations
    check_root
    get_current_node
    check_cluster_exists

    # Display nodes and select which to remove
    display_and_select_node

    # Remove node from cluster
    remove_node_from_cluster

    # Show updated cluster status
    show_cluster_status

    # Done
    log "Node $NODE_TO_REMOVE removed from cluster"
    log "Cluster is still active with remaining nodes"
}

main "$@"