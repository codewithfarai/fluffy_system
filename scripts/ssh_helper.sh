#!/bin/bash
# Fluffy System SSH Helper Script - High Availability Edition
# Simplifies SSH access to bastion and internal nodes

set -e

# Color codes
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration from your actual deployment
BASTION_IP="${BASTION_IP:-157.90.126.147}"
SSH_KEY="${SSH_KEY:-~/.ssh/fluffy-system-key}"
SSH_USER="${SSH_USER:-root}"

# Function to display usage
usage() {
    echo -e "${BLUE}Fluffy System SSH Helper - High Availability${NC}"
    echo ""
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  connect <host>     - SSH into a host"
    echo "  verify <host>      - Run security verification on a host"
    echo "  verify-all         - Run verification on all nodes"
    echo "  list               - List all available hosts"
    echo "  copy-verify        - Copy verification script to bastion"
    echo ""
    echo "Hosts:"
    echo "  bastion            - Bastion host (public access)"
    echo "  manager1           - Docker Swarm manager 1 (primary)"
    echo "  manager2           - Docker Swarm manager 2"
    echo "  manager3           - Docker Swarm manager 3"
    echo "  edge1              - Edge/Load balancer 1"
    echo "  edge2              - Edge/Load balancer 2"
    echo "  worker1-5          - Docker Swarm workers"
    echo ""
    echo "Environment Variables:"
    echo "  BASTION_IP         - Public IP of bastion (default: 157.90.126.147)"
    echo "  SSH_KEY            - Path to SSH private key (default: ~/.ssh/id_rsa)"
    echo "  SSH_USER           - SSH username (default: root)"
    echo ""
    echo "Examples:"
    echo "  $0 connect bastion"
    echo "  $0 connect manager1"
    echo "  $0 connect edge1"
    echo "  $0 verify bastion"
    echo "  $0 verify-all"
    exit 1
}

# Check if bastion IP is set
check_bastion_ip() {
    if [[ -z "$BASTION_IP" ]]; then
        echo -e "${RED}Error: BASTION_IP not set${NC}"
        echo ""
        echo "Please set BASTION_IP environment variable:"
        echo "  export BASTION_IP=157.90.126.147"
        exit 1
    fi
}

# Get internal IP for a host
get_internal_ip() {
    local host="$1"
    case "$host" in
        bastion)
            echo "$BASTION_IP"
            ;;
        # Managers
        manager1|manager)
            echo "10.0.1.10"
            ;;
        manager2)
            echo "10.0.1.11"
            ;;
        manager3)
            echo "10.0.1.12"
            ;;
        # Edge nodes
        edge1|edge)
            echo "10.0.1.20"
            ;;
        edge2)
            echo "10.0.1.21"
            ;;
        # Workers
        worker1)
            echo "10.0.2.15"
            ;;
        worker2)
            echo "10.0.2.16"
            ;;
        worker3)
            echo "10.0.2.17"
            ;;
        worker4)
            echo "10.0.2.18"
            ;;
        worker5)
            echo "10.0.2.19"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Connect to a host
connect_host() {
    local host="$1"
    local internal_ip=$(get_internal_ip "$host")
    
    if [[ -z "$internal_ip" ]]; then
        echo -e "${RED}Error: Unknown host '$host'${NC}"
        echo "Use '$0 list' to see available hosts"
        exit 1
    fi
    
    check_bastion_ip
    
    echo -e "${BLUE}Connecting to $host ($internal_ip)...${NC}"
    
    if [[ "$host" == "bastion" ]]; then
        # Direct connection to bastion
        ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@$BASTION_IP"
    else
        # ProxyJump through bastion for internal nodes
        ssh -i "$SSH_KEY" \
            -o StrictHostKeyChecking=no \
            -o ProxyJump="$SSH_USER@$BASTION_IP" \
            "$SSH_USER@$internal_ip"
    fi
}

# Copy verification script to bastion
copy_verify_script() {
    check_bastion_ip
    
    if [[ ! -f "verify_hardening.sh" ]]; then
        echo -e "${RED}Error: verify_hardening.sh not found${NC}"
        echo "Please ensure the verification script is in the current directory"
        exit 1
    fi
    
    echo -e "${BLUE}Copying verification script to bastion...${NC}"
    scp -i "$SSH_KEY" -o StrictHostKeyChecking=no \
        verify_hardening.sh "$SSH_USER@$BASTION_IP:/root/"
    
    echo -e "${GREEN}Making script executable...${NC}"
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no \
        "$SSH_USER@$BASTION_IP" "chmod +x /root/verify_hardening.sh"
    
    echo -e "${GREEN}✓ Verification script copied to bastion${NC}"
}

# Run verification on a host
verify_host() {
    local host="$1"
    local internal_ip=$(get_internal_ip "$host")
    
    if [[ -z "$internal_ip" ]]; then
        echo -e "${RED}Error: Unknown host '$host'${NC}"
        exit 1
    fi
    
    check_bastion_ip
    
    echo -e "${BLUE}Running verification on $host ($internal_ip)...${NC}"
    echo ""
    
    if [[ "$host" == "bastion" ]]; then
        # Run directly on bastion
        if [[ -f "verify_hardening.sh" ]]; then
            ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no \
                "$SSH_USER@$BASTION_IP" "bash -s" < verify_hardening.sh
        else
            ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no \
                "$SSH_USER@$BASTION_IP" "/root/verify_hardening.sh"
        fi
    else
        # Run on internal node through bastion using ProxyJump
        ssh -i "$SSH_KEY" \
            -o StrictHostKeyChecking=no \
            -o ProxyJump="$SSH_USER@$BASTION_IP" \
            "$SSH_USER@$internal_ip" 'bash -s' < verify_hardening.sh
    fi
}

# Verify all nodes
verify_all() {
    check_bastion_ip
    
    local hosts=(
        "bastion"
        "manager1" "manager2" "manager3"
        "edge1" "edge2"
        "worker1" "worker2" "worker3" "worker4" "worker5"
    )
    
    echo -e "${BLUE}Running verification on all nodes (3 managers, 2 edge, 5 workers)...${NC}"
    echo ""
    
    for host in "${hosts[@]}"; do
        local internal_ip=$(get_internal_ip "$host")
        if [[ -n "$internal_ip" ]]; then
            echo -e "${GREEN}═══════════════════════════════════════${NC}"
            echo -e "${GREEN}Verifying: $host ($internal_ip)${NC}"
            echo -e "${GREEN}═══════════════════════════════════════${NC}"
            
            # Check if host is reachable first
            if [[ "$host" == "bastion" ]]; then
                if ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
                    "$SSH_USER@$BASTION_IP" "echo ok" >/dev/null 2>&1; then
                    verify_host "$host"
                else
                    echo -e "${RED}✗ Unable to reach $host${NC}"
                fi
            else
                if ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
                    -o ProxyJump="$SSH_USER@$BASTION_IP" \
                    "$SSH_USER@$internal_ip" 'echo ok' >/dev/null 2>&1; then
                    verify_host "$host"
                else
                    echo -e "${YELLOW}⚠ Skipping $host (unreachable)${NC}"
                fi
            fi
            
            echo ""
        fi
    done
    
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}Verification complete for all 11 nodes${NC}"
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
}

# List all hosts
list_hosts() {
    check_bastion_ip
    
    echo -e "${BLUE}Available Hosts:${NC}"
    echo ""
    echo -e "${YELLOW}Bastion:${NC}"
    echo -e "  ${GREEN}bastion${NC}     - $BASTION_IP (public)"
    echo ""
    echo -e "${YELLOW}Managers (3 nodes):${NC}"
    echo -e "  ${GREEN}manager1${NC}    - 10.0.1.10 (via bastion) [Primary]"
    echo -e "  ${GREEN}manager2${NC}    - 10.0.1.11 (via bastion)"
    echo -e "  ${GREEN}manager3${NC}    - 10.0.1.12 (via bastion)"
    echo ""
    echo -e "${YELLOW}Edge Nodes (2 nodes):${NC}"
    echo -e "  ${GREEN}edge1${NC}       - 10.0.1.20 (via bastion) [Public: 91.107.227.16]"
    echo -e "  ${GREEN}edge2${NC}       - 10.0.1.21 (via bastion) [Public: 162.55.186.121]"
    echo ""
    echo -e "${YELLOW}Workers (5 nodes):${NC}"
    echo -e "  ${GREEN}worker1${NC}     - 10.0.2.15 (via bastion)"
    echo -e "  ${GREEN}worker2${NC}     - 10.0.2.16 (via bastion)"
    echo -e "  ${GREEN}worker3${NC}     - 10.0.2.17 (via bastion)"
    echo -e "  ${GREEN}worker4${NC}     - 10.0.2.18 (via bastion)"
    echo -e "  ${GREEN}worker5${NC}     - 10.0.2.19 (via bastion)"
    echo ""
    echo "Total: 11 nodes (1 bastion + 3 managers + 2 edge + 5 workers)"
    echo ""
    echo "Use '$0 connect <host>' to SSH into a host"
    echo "Use '$0 verify <host>' to run security verification"
}

# Main script logic
case "${1:-}" in
    connect)
        if [[ -z "${2:-}" ]]; then
            echo -e "${RED}Error: No host specified${NC}"
            echo "Usage: $0 connect <host>"
            exit 1
        fi
        connect_host "$2"
        ;;
    verify)
        if [[ -z "${2:-}" ]]; then
            echo -e "${RED}Error: No host specified${NC}"
            echo "Usage: $0 verify <host>"
            exit 1
        fi
        verify_host "$2"
        ;;
    verify-all)
        verify_all
        ;;
    list)
        list_hosts
        ;;
    copy-verify)
        copy_verify_script
        ;;
    *)
        usage
        ;;
esac