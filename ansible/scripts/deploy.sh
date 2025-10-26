#!/bin/bash

# Docker Stack Deployment Script
# This script deploys individual application stacks to the Docker Swarm cluster

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

# Configuration
INVENTORY_FILE="${ANSIBLE_DIR}/inventories/production.ini"
STACK_NAME=""
FORCE_UPDATE=false
VERBOSE=false
DRY_RUN=false
ENVIRONMENT="production"

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
Docker Stack Deployment Script

Usage: $0 [OPTIONS] <STACK_NAME>

ARGUMENTS:
    STACK_NAME             Name of the stack to deploy (webapp|api|worker|custom)

OPTIONS:
    -i, --inventory FILE   Use specific inventory file (default: production.ini)
    -e, --environment ENV  Environment to deploy to (production|staging)
    -f, --force           Force update (resolve images always)
    -v, --verbose         Enable verbose output
    -n, --dry-run         Run in dry-run mode (check only)
    -h, --help            Show this help message

EXAMPLES:
    # Deploy webapp stack
    $0 webapp

    # Deploy API stack with force update
    $0 --force api

    # Deploy custom stack from stacks/myapp/
    $0 myapp

    # Deploy to staging environment
    $0 --environment staging webapp

    # Dry run to check configuration
    $0 --dry-run worker

AVAILABLE STACKS:
    webapp    - Sample web application with Nginx
    api       - Node.js API with Redis workers
    worker    - Python workers with Celery
    custom    - Any custom stack in stacks/ directory

REQUIREMENTS:
    - Docker Swarm cluster must be initialized
    - Stack directory must exist in ansible/stacks/<STACK_NAME>/
    - docker-compose.yml file must exist in stack directory
    - Traefik network 'traefik-public' must exist

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
            -f|--force)
                FORCE_UPDATE=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            -*)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                if [[ -z "$STACK_NAME" ]]; then
                    STACK_NAME="$1"
                else
                    print_error "Multiple stack names provided"
                    show_usage
                    exit 1
                fi
                shift
                ;;
        esac
    done

    # Validate stack name
    if [[ -z "$STACK_NAME" ]]; then
        print_error "Stack name is required"
        show_usage
        exit 1
    fi
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
    if ! command -v ansible-playbook >/dev/null 2>&1; then
        print_error "ansible-playbook not found. Please install Ansible"
        exit 1
    fi

    # Check inventory file
    if [[ ! -f "$INVENTORY_FILE" ]]; then
        print_error "Inventory file not found: $INVENTORY_FILE"
        exit 1
    fi

    # Check stack directory
    local stack_dir="${ANSIBLE_DIR}/stacks/${STACK_NAME}"
    if [[ ! -d "$stack_dir" ]]; then
        print_error "Stack directory not found: $stack_dir"
        print_status "Available stacks:"
        ls -1 "${ANSIBLE_DIR}/stacks/" 2>/dev/null || print_status "No stacks directory found"
        exit 1
    fi

    # Check for docker-compose.yml
    if [[ ! -f "${stack_dir}/docker-compose.yml" ]]; then
        print_error "docker-compose.yml not found in stack directory: $stack_dir"
        exit 1
    fi

    print_success "Prerequisites check completed"
}

# Function to validate stack configuration
validate_stack() {
    print_status "Validating stack configuration..."

    local stack_dir="${ANSIBLE_DIR}/stacks/${STACK_NAME}"
    local compose_file="${stack_dir}/docker-compose.yml"

    # Basic YAML syntax check
    if command -v python3 >/dev/null 2>&1; then
        if ! python3 -c "import yaml; yaml.safe_load(open('$compose_file'))" 2>/dev/null; then
            print_error "Invalid YAML syntax in docker-compose.yml"
            exit 1
        fi
    fi

    # Check for required networks
    if grep -q "traefik-public" "$compose_file"; then
        print_status "Found Traefik integration"
    fi

    # Check for secrets
    if grep -q "secrets:" "$compose_file"; then
        print_status "Found secrets configuration"
    fi

    # Check environment file
    local env_file="${stack_dir}/.env"
    if [[ -f "$env_file" ]]; then
        print_status "Found environment file: .env"
    else
        print_warning "No .env file found - using defaults"
    fi

    print_success "Stack configuration validation completed"
}

# Function to check cluster status
check_cluster_status() {
    print_status "Checking Docker Swarm cluster status..."

    cd "$ANSIBLE_DIR"

    # Check if any managers are available
    if ! ansible managers -i "$INVENTORY_FILE" -m ping >/dev/null 2>&1; then
        print_error "Cannot reach any manager nodes"
        exit 1
    fi

    # Check swarm status
    local swarm_status
    swarm_status=$(ansible managers[0] -i "$INVENTORY_FILE" -m shell -a "docker info --format '{{.Swarm.LocalNodeState}}'" --one-line 2>/dev/null | tail -1)
    
    if [[ "$swarm_status" != "active" ]]; then
        print_error "Docker Swarm is not active on manager nodes"
        print_status "Please run the swarm initialization first: ./scripts/setup.sh"
        exit 1
    fi

    # Check for required networks
    local networks
    networks=$(ansible managers[0] -i "$INVENTORY_FILE" -m shell -a "docker network ls --filter driver=overlay --format '{{.Name}}'" --one-line 2>/dev/null)
    
    if ! echo "$networks" | grep -q "traefik-public"; then
        print_warning "traefik-public network not found"
        print_status "Stack may not be accessible externally"
    fi

    print_success "Cluster status check completed"
}

# Function to prepare stack deployment
prepare_deployment() {
    print_status "Preparing stack deployment..."

    local stack_dir="${ANSIBLE_DIR}/stacks/${STACK_NAME}"
    
    # Create stack directories on manager nodes
    cd "$ANSIBLE_DIR"
    ansible managers[0] -i "$INVENTORY_FILE" -m file -a "path=/opt/docker/stacks/${STACK_NAME} state=directory mode=0755" >/dev/null

    # Copy stack files to manager
    print_status "Copying stack files to manager node..."
    ansible managers[0] -i "$INVENTORY_FILE" -m copy -a "src=${stack_dir}/ dest=/opt/docker/stacks/${STACK_NAME}/ backup=yes" >/dev/null

    print_success "Stack preparation completed"
}

# Function to deploy stack
deploy_stack() {
    print_status "Deploying stack: $STACK_NAME"

    cd "$ANSIBLE_DIR"

    local ansible_opts="-i $INVENTORY_FILE -e target_stack=$STACK_NAME"
    
    if [[ "$VERBOSE" == "true" ]]; then
        ansible_opts="$ansible_opts -v"
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        ansible_opts="$ansible_opts --check --diff"
    fi

    if [[ "$FORCE_UPDATE" == "true" ]]; then
        ansible_opts="$ansible_opts -e force_stack_update=true"
    fi

    # Run deployment playbook
    if ansible-playbook playbooks/deploy_stack.yml $ansible_opts; then
        print_success "Stack deployment completed"
    else
        print_error "Stack deployment failed"
        exit 1
    fi
}

# Function to verify deployment
verify_deployment() {
    if [[ "$DRY_RUN" == "true" ]]; then
        print_warning "Skipping verification in dry-run mode"
        return
    fi

    print_status "Verifying stack deployment..."

    cd "$ANSIBLE_DIR"

    # Check stack status
    print_status "Checking stack services..."
    local services
    services=$(ansible managers[0] -i "$INVENTORY_FILE" -m shell -a "docker stack services $STACK_NAME --format 'table {{.Name}}\t{{.Mode}}\t{{.Replicas}}\t{{.Image}}'" --one-line 2>/dev/null | tail -n +2)
    
    if [[ -n "$services" ]]; then
        echo "$services"
    else
        print_warning "No services found for stack $STACK_NAME"
    fi

    # Check for any failed services
    local failed_services
    failed_services=$(ansible managers[0] -i "$INVENTORY_FILE" -m shell -a "docker stack services $STACK_NAME --format '{{.Name}} {{.Replicas}}' | grep '0/'" --one-line 2>/dev/null | tail -1 || true)
    
    if [[ -n "$failed_services" ]]; then
        print_warning "Some services may not be running properly:"
        echo "$failed_services"
    fi

    print_success "Deployment verification completed"
}

# Function to show deployment summary
show_summary() {
    print_status "=== Deployment Summary ==="
    
    cat << EOF

${GREEN}Stack '$STACK_NAME' has been deployed successfully!${NC}

${BLUE}Stack Information:${NC}
- Stack Name: $STACK_NAME
- Environment: $ENVIRONMENT
- Force Update: $FORCE_UPDATE

${BLUE}Useful Commands:${NC}
- Check stack status: docker stack services $STACK_NAME
- View stack logs: docker service logs \${SERVICE_NAME}
- Scale services: docker service scale \${SERVICE_NAME}=\${REPLICAS}
- Update stack: $0 --force $STACK_NAME
- Remove stack: docker stack rm $STACK_NAME

${BLUE}Monitoring:${NC}
- View in Traefik dashboard: https://traefik.example.com
- Monitor in Grafana: https://grafana.example.com

${BLUE}Files Location (on manager nodes):${NC}
- Stack files: /opt/docker/stacks/$STACK_NAME/
- Deployment logs: /opt/docker/stacks/$STACK_NAME/deployment_log_*.txt
- Deployment status: /opt/docker/stacks/$STACK_NAME/deployment_status.json

EOF

    # Show access URLs if they exist in the stack
    local stack_dir="${ANSIBLE_DIR}/stacks/${STACK_NAME}"
    if grep -q "traefik.http.routers" "${stack_dir}/docker-compose.yml"; then
        print_status "Extracting access URLs from stack configuration..."
        grep -o "Host(\`[^)]*\`)" "${stack_dir}/docker-compose.yml" | sed 's/Host(`//g; s/`)//g' | sort -u | while read -r domain; do
            echo "- https://$domain"
        done
    fi
}

# Main execution function
main() {
    print_status "Starting stack deployment: $STACK_NAME"
    print_status "Environment: $ENVIRONMENT"
    print_status "Inventory: $INVENTORY_FILE"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_warning "Running in DRY-RUN mode - no changes will be made"
    fi

    if [[ "$FORCE_UPDATE" == "true" ]]; then
        print_status "Force update enabled - images will be re-pulled"
    fi

    # Execute deployment phases
    check_prerequisites
    validate_stack
    check_cluster_status
    prepare_deployment
    deploy_stack
    verify_deployment
    
    if [[ "$DRY_RUN" != "true" ]]; then
        show_summary
    fi

    print_success "Stack deployment completed successfully!"
}

# Parse arguments and run main function
parse_arguments "$@"
main