#!/bin/bash

# Docker Swarm Management Script
# This script provides common management operations for the Docker Swarm cluster

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
OPERATION=""
ENVIRONMENT="production"
VERBOSE=false

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
Docker Swarm Management Script

Usage: $0 [OPTIONS] <OPERATION>

OPERATIONS:
    status       - Show cluster status and service health
    logs         - View logs for all services or specific stack
    backup       - Create backup of databases and configurations
    restore      - Restore from backup
    secrets      - Manage Docker secrets
    cleanup      - Clean up unused resources
    scale        - Scale services up or down
    update       - Update services/stacks
    health       - Perform health checks on all services

OPTIONS:
    -i, --inventory FILE   Use specific inventory file (default: production.ini)
    -e, --environment ENV  Environment to manage (production|staging)
    -v, --verbose         Enable verbose output
    -h, --help            Show this help message

EXAMPLES:
    # Show cluster status
    $0 status

    # Create backup
    $0 backup

    # View logs for specific stack
    $0 logs --stack webapp

    # Manage secrets
    $0 secrets --operation list

    # Clean up unused resources
    $0 cleanup

    # Scale a service
    $0 scale --service webapp_webapp --replicas 5

    # Perform health checks
    $0 health

DETAILED OPERATION HELP:
    Use '$0 <OPERATION> --help' for operation-specific options

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
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                if [[ -n "$OPERATION" ]]; then
                    show_operation_help "$OPERATION"
                else
                    show_usage
                fi
                exit 0
                ;;
            -*)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                if [[ -z "$OPERATION" ]]; then
                    OPERATION="$1"
                    shift
                    # Parse operation-specific arguments
                    parse_operation_args "$OPERATION" "$@"
                    break
                else
                    print_error "Multiple operations provided"
                    show_usage
                    exit 1
                fi
                ;;
        esac
    done

    # Validate operation
    if [[ -z "$OPERATION" ]]; then
        print_error "Operation is required"
        show_usage
        exit 1
    fi
}

# Function to parse operation-specific arguments
parse_operation_args() {
    local op="$1"
    shift

    case "$op" in
        logs)
            LOGS_STACK=""
            LOGS_SERVICE=""
            LOGS_FOLLOW=false
            LOGS_TAIL=50
            
            while [[ $# -gt 0 ]]; do
                case $1 in
                    --stack)
                        LOGS_STACK="$2"
                        shift 2
                        ;;
                    --service)
                        LOGS_SERVICE="$2"
                        shift 2
                        ;;
                    --follow|-f)
                        LOGS_FOLLOW=true
                        shift
                        ;;
                    --tail)
                        LOGS_TAIL="$2"
                        shift 2
                        ;;
                    *)
                        print_error "Unknown logs option: $1"
                        exit 1
                        ;;
                esac
            done
            ;;
        secrets)
            SECRETS_OPERATION=""
            SECRET_NAME=""
            SECRET_VALUE=""
            SECRET_FILE=""
            
            while [[ $# -gt 0 ]]; do
                case $1 in
                    --operation)
                        SECRETS_OPERATION="$2"
                        shift 2
                        ;;
                    --name)
                        SECRET_NAME="$2"
                        shift 2
                        ;;
                    --value)
                        SECRET_VALUE="$2"
                        shift 2
                        ;;
                    --file)
                        SECRET_FILE="$2"
                        shift 2
                        ;;
                    *)
                        print_error "Unknown secrets option: $1"
                        exit 1
                        ;;
                esac
            done
            ;;
        scale)
            SCALE_SERVICE=""
            SCALE_REPLICAS=""
            
            while [[ $# -gt 0 ]]; do
                case $1 in
                    --service)
                        SCALE_SERVICE="$2"
                        shift 2
                        ;;
                    --replicas)
                        SCALE_REPLICAS="$2"
                        shift 2
                        ;;
                    *)
                        print_error "Unknown scale option: $1"
                        exit 1
                        ;;
                esac
            done
            ;;
        restore)
            RESTORE_TIMESTAMP=""
            
            while [[ $# -gt 0 ]]; do
                case $1 in
                    --timestamp)
                        RESTORE_TIMESTAMP="$2"
                        shift 2
                        ;;
                    *)
                        print_error "Unknown restore option: $1"
                        exit 1
                        ;;
                esac
            done
            ;;
    esac
}

# Function to show operation-specific help
show_operation_help() {
    local op="$1"
    
    case "$op" in
        logs)
            cat << EOF
Logs Operation Help

Usage: $0 logs [OPTIONS]

OPTIONS:
    --stack STACK_NAME     Show logs for all services in a stack
    --service SERVICE_NAME Show logs for a specific service
    --follow, -f          Follow log output
    --tail N              Number of lines to show (default: 50)

EXAMPLES:
    $0 logs --stack webapp
    $0 logs --service webapp_webapp --follow
    $0 logs --tail 100

EOF
            ;;
        secrets)
            cat << EOF
Secrets Operation Help

Usage: $0 secrets [OPTIONS]

OPTIONS:
    --operation OP        Operation: list, create, update, remove
    --name NAME          Secret name (required for create/update/remove)
    --value VALUE        Secret value (for create/update)
    --file FILE          File containing secret (for create/update)

EXAMPLES:
    $0 secrets --operation list
    $0 secrets --operation create --name db_password --value secretpass
    $0 secrets --operation create --name ssl_cert --file /path/to/cert.pem
    $0 secrets --operation remove --name old_secret

EOF
            ;;
        scale)
            cat << EOF
Scale Operation Help

Usage: $0 scale [OPTIONS]

OPTIONS:
    --service SERVICE     Service name to scale
    --replicas N         Number of replicas

EXAMPLES:
    $0 scale --service webapp_webapp --replicas 5
    $0 scale --service api_api --replicas 3

EOF
            ;;
        restore)
            cat << EOF
Restore Operation Help

Usage: $0 restore [OPTIONS]

OPTIONS:
    --timestamp TIMESTAMP Backup timestamp to restore (default: latest)

EXAMPLES:
    $0 restore
    $0 restore --timestamp 1634567890

EOF
            ;;
        *)
            print_error "No specific help available for operation: $op"
            ;;
    esac
}

# Function to check prerequisites
check_prerequisites() {
    # Check if running in correct directory
    if [[ ! -f "${ANSIBLE_DIR}/ansible.cfg" ]]; then
        print_error "Please run this script from the ansible directory or its subdirectories"
        exit 1
    fi

    # Check for required tools
    if ! command -v ansible >/dev/null 2>&1; then
        print_error "ansible not found. Please install Ansible"
        exit 1
    fi

    # Check inventory file
    if [[ ! -f "$INVENTORY_FILE" ]]; then
        print_error "Inventory file not found: $INVENTORY_FILE"
        exit 1
    fi
}

# Function to show cluster status
show_status() {
    print_status "=== Docker Swarm Cluster Status ==="

    cd "$ANSIBLE_DIR"

    # Show cluster nodes
    print_status "Cluster Nodes:"
    ansible managers[0] -i "$INVENTORY_FILE" -m shell -a "docker node ls" --one-line | tail -n +2

    # Show all stacks
    print_status "Deployed Stacks:"
    ansible managers[0] -i "$INVENTORY_FILE" -m shell -a "docker stack ls" --one-line | tail -n +2

    # Show all services
    print_status "Services Status:"
    ansible managers[0] -i "$INVENTORY_FILE" -m shell -a "docker service ls" --one-line | tail -n +2

    # Show resource usage
    print_status "Resource Usage:"
    ansible all -i "$INVENTORY_FILE" -m shell -a "docker system df" --one-line | tail -n +2
}

# Function to view logs
view_logs() {
    cd "$ANSIBLE_DIR"

    local log_cmd="docker service logs"
    
    if [[ "$LOGS_FOLLOW" == "true" ]]; then
        log_cmd="$log_cmd --follow"
    fi
    
    log_cmd="$log_cmd --tail $LOGS_TAIL"

    if [[ -n "$LOGS_SERVICE" ]]; then
        print_status "Viewing logs for service: $LOGS_SERVICE"
        ansible managers[0] -i "$INVENTORY_FILE" -m shell -a "$log_cmd $LOGS_SERVICE"
    elif [[ -n "$LOGS_STACK" ]]; then
        print_status "Viewing logs for stack: $LOGS_STACK"
        local services
        services=$(ansible managers[0] -i "$INVENTORY_FILE" -m shell -a "docker stack services $LOGS_STACK --format '{{.Name}}'" --one-line | tail -n +2)
        
        for service in $services; do
            print_status "=== Logs for $service ==="
            ansible managers[0] -i "$INVENTORY_FILE" -m shell -a "$log_cmd $service"
        done
    else
        print_status "Viewing logs for all services"
        local all_services
        all_services=$(ansible managers[0] -i "$INVENTORY_FILE" -m shell -a "docker service ls --format '{{.Name}}'" --one-line | tail -n +2)
        
        for service in $all_services; do
            print_status "=== Recent logs for $service ==="
            ansible managers[0] -i "$INVENTORY_FILE" -m shell -a "docker service logs --tail 10 $service"
        done
    fi
}

# Function to run backup
run_backup() {
    print_status "Creating backup of cluster data..."
    
    cd "$ANSIBLE_DIR"
    
    local ansible_opts="-i $INVENTORY_FILE"
    if [[ "$VERBOSE" == "true" ]]; then
        ansible_opts="$ansible_opts -v"
    fi

    if ansible-playbook playbooks/backup.yml $ansible_opts; then
        print_success "Backup completed successfully"
    else
        print_error "Backup failed"
        exit 1
    fi
}

# Function to run restore
run_restore() {
    print_status "Restoring cluster data from backup..."
    
    cd "$ANSIBLE_DIR"
    
    local ansible_opts="-i $INVENTORY_FILE"
    if [[ "$VERBOSE" == "true" ]]; then
        ansible_opts="$ansible_opts -v"
    fi
    
    if [[ -n "$RESTORE_TIMESTAMP" ]]; then
        ansible_opts="$ansible_opts -e restore_backup_timestamp=$RESTORE_TIMESTAMP"
    fi

    if ansible-playbook playbooks/restore.yml $ansible_opts; then
        print_success "Restore completed successfully"
    else
        print_error "Restore failed"
        exit 1
    fi
}

# Function to manage secrets
manage_secrets() {
    if [[ -z "$SECRETS_OPERATION" ]]; then
        print_error "Secrets operation is required. Use --operation list|create|update|remove"
        exit 1
    fi

    print_status "Managing Docker secrets..."
    
    cd "$ANSIBLE_DIR"
    
    local ansible_opts="-i $INVENTORY_FILE -e operation=$SECRETS_OPERATION"
    
    if [[ -n "$SECRET_NAME" ]]; then
        ansible_opts="$ansible_opts -e secret_name_var=$SECRET_NAME"
    fi
    
    if [[ -n "$SECRET_VALUE" ]]; then
        ansible_opts="$ansible_opts -e secret_value_var='$SECRET_VALUE'"
    fi
    
    if [[ -n "$SECRET_FILE" ]]; then
        ansible_opts="$ansible_opts -e secret_file_var=$SECRET_FILE"
    fi
    
    if [[ "$VERBOSE" == "true" ]]; then
        ansible_opts="$ansible_opts -v"
    fi

    if ansible-playbook playbooks/manage_secrets.yml $ansible_opts; then
        print_success "Secrets management completed"
    else
        print_error "Secrets management failed"
        exit 1
    fi
}

# Function to cleanup unused resources
cleanup_resources() {
    print_status "Cleaning up unused Docker resources..."
    
    cd "$ANSIBLE_DIR"

    # Clean up on all nodes
    print_status "Removing unused containers, networks, and images..."
    ansible all -i "$INVENTORY_FILE" -m shell -a "docker system prune -f"

    # Clean up volumes (more cautious)
    print_status "Showing unused volumes (manual cleanup recommended):"
    ansible all -i "$INVENTORY_FILE" -m shell -a "docker volume ls -f dangling=true"

    print_success "Cleanup completed"
    print_warning "Review unused volumes manually before removing them"
}

# Function to scale services
scale_service() {
    if [[ -z "$SCALE_SERVICE" ]] || [[ -z "$SCALE_REPLICAS" ]]; then
        print_error "Both --service and --replicas are required for scaling"
        exit 1
    fi

    print_status "Scaling service $SCALE_SERVICE to $SCALE_REPLICAS replicas..."
    
    cd "$ANSIBLE_DIR"

    # Scale the service
    if ansible managers[0] -i "$INVENTORY_FILE" -m shell -a "docker service scale $SCALE_SERVICE=$SCALE_REPLICAS"; then
        print_success "Service scaled successfully"
        
        # Show updated status
        print_status "Updated service status:"
        ansible managers[0] -i "$INVENTORY_FILE" -m shell -a "docker service ls --filter name=$SCALE_SERVICE"
    else
        print_error "Service scaling failed"
        exit 1
    fi
}

# Function to update services
update_services() {
    print_status "Updating all services with latest images..."
    
    cd "$ANSIBLE_DIR"

    # Get all services
    local services
    services=$(ansible managers[0] -i "$INVENTORY_FILE" -m shell -a "docker service ls --format '{{.Name}}'" --one-line | tail -n +2)

    for service in $services; do
        print_status "Updating service: $service"
        ansible managers[0] -i "$INVENTORY_FILE" -m shell -a "docker service update --image \$(docker service inspect $service --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}') $service"
    done

    print_success "All services updated"
}

# Function to perform health checks
health_check() {
    print_status "=== Performing Health Checks ==="
    
    cd "$ANSIBLE_DIR"

    # Check node health
    print_status "Node Health:"
    ansible all -i "$INVENTORY_FILE" -m shell -a "docker info --format 'Node: {{.Name}} - Swarm: {{.Swarm.LocalNodeState}}'"

    # Check service health
    print_status "Service Health:"
    ansible managers[0] -i "$INVENTORY_FILE" -m shell -a "docker service ls"

    # Check for failed tasks
    print_status "Failed Tasks:"
    ansible managers[0] -i "$INVENTORY_FILE" -m shell -a "docker service ps \$(docker service ls -q) --filter 'desired-state=running' --filter 'current-state=failed' --format 'table {{.Name}}\t{{.Image}}\t{{.Node}}\t{{.DesiredState}}\t{{.CurrentState}}\t{{.Error}}'"

    # Check resource usage
    print_status "Resource Usage:"
    ansible all -i "$INVENTORY_FILE" -m shell -a "df -h /var/lib/docker"

    print_success "Health check completed"
}

# Main execution function
main() {
    print_status "Docker Swarm Management - Operation: $OPERATION"
    print_status "Environment: $ENVIRONMENT"

    check_prerequisites

    case "$OPERATION" in
        status)
            show_status
            ;;
        logs)
            view_logs
            ;;
        backup)
            run_backup
            ;;
        restore)
            run_restore
            ;;
        secrets)
            manage_secrets
            ;;
        cleanup)
            cleanup_resources
            ;;
        scale)
            scale_service
            ;;
        update)
            update_services
            ;;
        health)
            health_check
            ;;
        *)
            print_error "Unknown operation: $OPERATION"
            print_status "Available operations: status, logs, backup, restore, secrets, cleanup, scale, update, health"
            exit 1
            ;;
    esac

    print_success "Operation completed successfully!"
}

# Parse arguments and run main function
parse_arguments "$@"
main