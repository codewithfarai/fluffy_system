#!/bin/bash
# Fluffy System SSH Helper Script
# Simplifies SSH access to bastion and internal nodes

set -e

# Color codes
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration (update these with your actual values)
BASTION_IP="${BASTION_IP:-}"
SSH_KEY="${SSH_KEY:-~/.ssh/id_rsa}"
SSH_USER="${SSH_USER:-root}"

# Function to display usage
usage() {
    echo -e "${BLUE}Fluffy System SSH Helper${NC}"
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
    echo "  manager            - Docker Swarm manager"
    echo "  worker1            - Docker Swarm worker 1"
    echo "  worker2            - Docker Swarm worker 2"
    echo "  workerN            - Docker Swarm worker N"
    echo "  services           - Services server (Redis + Vault)"
    echo ""
    echo "Environment Variables:"
    echo "  BASTION_IP         - Public IP of bastion host"
    echo "  SSH_KEY            - Path to SSH private key (default: ~/.ssh/id_rsa)"
    echo "  SSH_USER           - SSH username (default: root)"
    echo ""
    echo "Examples:"
    echo "  $0 connect bastion"
    echo "  $0 connect manager"
    echo "  $0 verify bastion"
    echo "  $0 verify-all"
    echo "  BASTION_IP=1.2.3.4 $0 connect manager"
    exit 1
}

# Check if bastion IP is set
check_bastion_ip() {
    if [[ -z "$BASTION_IP" ]]; then
        echo -e "${RED}Error: BASTION_IP not set${NC}"
        echo ""
        echo "Please set BASTION_IP environment variable:"
        echo "  export BASTION_IP=<your_bastion_public_ip>"
        echo ""
        echo "Or pass it inline:"
        echo "  BASTION_IP=<ip> $0 $@"
        echo ""
        
        # Try to get from Terraform output
        if [[ -f "terraform/main.tf" ]] || [[ -f "main.tf" ]]; then
            echo -e "${YELLOW}Tip: Get bastion IP from Terraform:${NC}"
            echo "  cd terraform && terraform output bastion_public_ip"
        fi
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
        manager)
            echo "10.0.1.10"
            ;;
        worker1)
            echo "10.0.2.11"
            ;;
        worker2)
            echo "10.0.2.12"
            ;;
        worker3)
            echo "10.0.2.13"
            ;;
        worker4)
            echo "10.0.2.14"
            ;;
        worker5)
            echo "10.0.2.15"
            ;;
        services)
            echo "10.0.3.10"
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
    
    local hosts=("bastion" "manager" "services")
    
    # Add workers based on common configurations
    for i in {1..3}; do
        hosts+=("worker$i")
    done
    
    echo -e "${BLUE}Running verification on all nodes...${NC}"
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
    echo -e "${GREEN}Verification complete for all nodes${NC}"
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
}

# List all hosts
list_hosts() {
    check_bastion_ip
    
    echo -e "${BLUE}Available Hosts:${NC}"
    echo ""
    echo -e "  ${GREEN}bastion${NC}   - $BASTION_IP (public)"
    echo -e "  ${GREEN}manager${NC}   - 10.0.1.10 (via bastion)"
    echo -e "  ${GREEN}services${NC}  - 10.0.3.10 (via bastion)"
    echo -e "  ${GREEN}worker1${NC}   - 10.0.2.11 (via bastion)"
    echo -e "  ${GREEN}worker2${NC}   - 10.0.2.12 (via bastion)"
    echo -e "  ${GREEN}worker3${NC}   - 10.0.2.13 (via bastion)"
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