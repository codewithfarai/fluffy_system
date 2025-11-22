#!/bin/bash

# Docker Swarm Ansible Setup Script
# This script sets up the complete Docker Swarm infrastructure using Ansible

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$ANSIBLE_DIR")"

# Configuration
INVENTORY_FILE="${ANSIBLE_DIR}/inventory/hosts.ini"
ENVIRONMENT="production"
BASTION_IP=""
VERBOSE=false
DRY_RUN=false
SKIP_VERIFY=false

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    cat << EOF
Docker Swarm Ansible Setup Script

Usage: $0 [OPTIONS]

OPTIONS:
    -i, --inventory FILE    Use specific inventory file (default: production.ini)
    -e, --environment ENV   Environment to deploy (production|staging)
    -b, --bastion IP        Bastion host IP address
    -v, --verbose          Enable verbose output
    -n, --dry-run          Run in dry-run mode (check only)
    -s, --skip-verify      Skip connectivity verification
    -h, --help             Show this help message

EXAMPLES:
    # Basic setup with bastion
    $0 --bastion 1.2.3.4

    # Staging environment setup
    $0 --environment staging --bastion 1.2.3.4

    # Dry run to check configuration
    $0 --bastion 1.2.3.4 --dry-run

    # Verbose output for debugging
    $0 --bastion 1.2.3.4 --verbose

DEPLOYMENT PHASES:
    1. Prerequisites check
    2. Connectivity verification
    3. Docker Swarm initialization
    4. Infrastructure deployment (Traefik, Database, Monitoring)
    5. Verification and health checks

EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--inventory)
                INVENTORY_FILE="$2"
                shift 2
                ;;
            -e|--environment)
                ENVIRONMENT="$2"
                INVENTORY_FILE="${ANSIBLE_DIR}/inventories/${ENVIRONMENT}.ini"
                shift 2
                ;;
            -b|--bastion)
                BASTION_IP="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -s|--skip-verify)
                SKIP_VERIFY=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."

    # Check if running in correct directory
    if [[ ! -f "${ANSIBLE_DIR}/ansible.cfg" ]]; then
        print_error "Please run this script from the ansible directory or its subdirectories"
        exit 1
    fi

    # Check for required tools
    local missing_tools=()

    if ! command -v ansible >/dev/null 2>&1; then
        missing_tools+=("ansible")
    fi

    if ! command -v ansible-playbook >/dev/null 2>&1; then
        missing_tools+=("ansible-playbook")
    fi

    if ! command -v ssh >/dev/null 2>&1; then
        missing_tools+=("ssh")
    fi

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_status "Please install Ansible and SSH client"
        exit 1
    fi

    # Check inventory file
    if [[ ! -f "$INVENTORY_FILE" ]]; then
        print_error "Inventory file not found: $INVENTORY_FILE"
        exit 1
    fi

    # Check for SSH key
    if [[ ! -f "$HOME/.ssh/fluffy-system-key" ]]; then
        print_warning "SSH private key not found at ~/.ssh/fluffy-system-key"
        print_status "Please ensure your SSH key is properly configured"
    fi

    print_success "Prerequisites check completed"
}

# Function to update inventory with bastion IP
update_inventory() {
    if [[ -n "$BASTION_IP" ]]; then
        print_status "Updating inventory with bastion IP: $BASTION_IP"
        
        # Update bastion IP in inventory file
        if grep -q "YOUR_BASTION_IP\|YOUR_STAGING_BASTION_IP" "$INVENTORY_FILE"; then
            sed -i.bak "s/YOUR_BASTION_IP/$BASTION_IP/g; s/YOUR_STAGING_BASTION_IP/$BASTION_IP/g" "$INVENTORY_FILE"
            print_success "Inventory updated with bastion IP"
        else
            print_warning "Bastion IP placeholders not found in inventory"
        fi
    fi
}

# Function to verify connectivity
verify_connectivity() {
    if [[ "$SKIP_VERIFY" == "true" ]]; then
        print_warning "Skipping connectivity verification"
        return
    fi

    print_status "Verifying connectivity to all hosts..."

    local ansible_opts=""
    if [[ "$VERBOSE" == "true" ]]; then
        ansible_opts="-v"
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        ansible_opts="$ansible_opts --check"
    fi

    # Test connectivity to all hosts
    if ansible all -i "$INVENTORY_FILE" -m ping $ansible_opts; then
        print_success "All hosts are reachable"
    else
        print_error "Some hosts are not reachable"
        print_status "Please check your SSH configuration and bastion setup"
        exit 1
    fi
}

# Function to run playbook
run_playbook() {
    local playbook="$1"
    local description="$2"
    local extra_vars="${3:-}"

    print_status "$description"

    local ansible_opts="-i $INVENTORY_FILE"
    
    if [[ "$VERBOSE" == "true" ]]; then
        ansible_opts="$ansible_opts -v"
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        ansible_opts="$ansible_opts --check --diff"
    fi

    if [[ -n "$extra_vars" ]]; then
        ansible_opts="$ansible_opts -e $extra_vars"
    fi

    # Change to ansible directory to run playbook
    cd "$ANSIBLE_DIR"

    if ansible-playbook "playbooks/$playbook" $ansible_opts; then
        print_success "$description completed"
    else
        print_error "$description failed"
        exit 1
    fi
}

# Function to initialize Docker Swarm
initialize_swarm() {
    print_status "=== Phase 1: Docker Swarm Initialization ==="
    run_playbook "swarm_init.yml" "Initializing Docker Swarm cluster"
}

# Function to deploy infrastructure services
deploy_infrastructure() {
    print_status "=== Phase 2: Infrastructure Services Deployment ==="
    
    # Deploy Traefik (reverse proxy and load balancer)
    run_playbook "deploy_traefik.yml" "Deploying Traefik reverse proxy"
    
    # Deploy Database stack (PostgreSQL + Redis)
    run_playbook "deploy_database.yml" "Deploying database services"
    
    # Deploy Monitoring stack (Prometheus + Grafana)
    run_playbook "deploy_monitoring.yml" "Deploying monitoring services"
}

# Function to verify deployment
verify_deployment() {
    if [[ "$DRY_RUN" == "true" ]]; then
        print_warning "Skipping verification in dry-run mode"
        return
    fi

    print_status "=== Phase 3: Deployment Verification ==="

    cd "$ANSIBLE_DIR"

    # Verify swarm status
    print_status "Checking Docker Swarm status..."
    ansible managers[0] -i "$INVENTORY_FILE" -m shell -a "docker node ls"

    # Verify services
    print_status "Checking deployed services..."
    ansible managers[0] -i "$INVENTORY_FILE" -m shell -a "docker stack ls"

    # Check service health
    print_status "Checking service health..."
    ansible managers[0] -i "$INVENTORY_FILE" -m shell -a "docker service ls"

    print_success "Deployment verification completed"
}

# Function to show deployment summary
show_summary() {
    print_status "=== Deployment Summary ==="
    
    cat << EOF

${GREEN}Docker Swarm cluster has been successfully deployed!${NC}

${BLUE}Access URLs:${NC}
- Traefik Dashboard: https://traefik.example.com
- Grafana: https://grafana.example.com
- Prometheus: https://prometheus.example.com
- PgAdmin: https://pgadmin.example.com

${BLUE}Next Steps:${NC}
1. Update DNS records to point domains to your edge nodes
2. Review and customize application stacks in ansible/stacks/
3. Deploy your application stacks using:
   ansible-playbook playbooks/deploy_stack.yml -e target_stack=webapp

${BLUE}Useful Commands:${NC}
- Deploy a stack: ./scripts/deploy.sh stack_name
- Backup data: ansible-playbook playbooks/backup.yml
- Manage secrets: ansible-playbook playbooks/manage_secrets.yml -e operation=list
- Monitor cluster: ansible-playbook playbooks/cluster_status.yml

${BLUE}Important Files:${NC}
- Service credentials: /opt/docker/stacks/*/credentials.txt (on manager nodes)
- Backup location: /opt/docker/backups/ (on manager nodes)
- Stack configurations: ansible/stacks/

${YELLOW}Security Reminders:${NC}
- Change default passwords stored in credentials files
- Configure firewall rules for your specific environment  
- Set up SSL certificates for production domains
- Review and update Traefik authentication settings

EOF
}

# Main execution function
main() {
    print_status "Starting Docker Swarm Ansible Setup"
    print_status "Environment: $ENVIRONMENT"
    print_status "Inventory: $INVENTORY_FILE"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_warning "Running in DRY-RUN mode - no changes will be made"
    fi

    # Execute setup phases
    check_prerequisites
    update_inventory
    verify_connectivity
    initialize_swarm
    deploy_infrastructure
    verify_deployment
    
    if [[ "$DRY_RUN" != "true" ]]; then
        show_summary
    fi

    print_success "Docker Swarm setup completed successfully!"
}

# Parse arguments and run main function
parse_arguments "$@"
main