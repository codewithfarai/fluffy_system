# Docker Swarm Infrastructure with Ansible

This directory contains a complete Ansible setup for deploying and managing a production-ready Docker Swarm cluster on Hetzner Cloud with HA configuration.

## Architecture

- **3 Manager Nodes**: Provide cluster management and consensus
- **5 Worker Nodes**: Run application workloads
- **2 Edge Nodes**: Handle ingress traffic and load balancing
- **Bastion Host**: Secure access point for cluster management

## Quick Start

### 1. Prerequisites

```bash
# Install Ansible
pip install ansible

# Ensure SSH key is configured
ls ~/.ssh/fluffy-system-key

# Update inventory with your server IPs
vi inventories/production.ini
```

### 2. Deploy Complete Infrastructure

```bash
# Deploy everything with one command
./scripts/setup.sh --bastion YOUR_BASTION_IP

# Or step by step
ansible-playbook playbooks/swarm_init.yml
ansible-playbook playbooks/deploy_traefik.yml
ansible-playbook playbooks/deploy_database.yml
ansible-playbook playbooks/deploy_monitoring.yml
```

### 3. Deploy Application Stacks

```bash
# Deploy sample web application
./scripts/deploy.sh webapp

# Deploy API services
./scripts/deploy.sh api

# Deploy background workers
./scripts/deploy.sh worker
```

## Directory Structure

```
ansible/
├── ansible.cfg                 # Ansible configuration
├── inventories/               # Host inventories
│   ├── production.ini         # Production servers
│   └── staging.ini           # Staging servers
├── roles/
│   └── docker/               # Docker installation and swarm setup
├── playbooks/                # Ansible playbooks
│   ├── swarm_init.yml        # Initialize Docker Swarm
│   ├── deploy_traefik.yml    # Deploy reverse proxy
│   ├── deploy_database.yml   # Deploy PostgreSQL & Redis
│   ├── deploy_monitoring.yml # Deploy Prometheus & Grafana
│   ├── deploy_stack.yml      # Generic stack deployment
│   ├── backup.yml            # Backup databases and configs
│   ├── restore.yml           # Restore from backup
│   └── manage_secrets.yml    # Manage Docker secrets
├── stacks/                   # Application stack definitions
│   ├── webapp/               # Sample web application
│   ├── api/                  # Sample API service
│   └── worker/               # Background workers
├── group_vars/               # Group-specific variables
├── scripts/                  # Management scripts
│   ├── setup.sh              # Complete infrastructure setup
│   ├── deploy.sh             # Deploy application stacks
│   └── manage.sh             # Cluster management operations
└── README.md                 # This file
```

## Available Services

After deployment, the following services will be available:

### Infrastructure Services
- **Traefik Dashboard**: `https://traefik.example.com`
- **Grafana**: `https://grafana.example.com`
- **Prometheus**: `https://prometheus.example.com`
- **PgAdmin**: `https://pgadmin.example.com`

### Sample Applications
- **Web App**: `https://app.example.com`
- **API**: `https://api.example.com`
- **Flower (Celery Monitor)**: `https://flower.example.com`

## Management Commands

### Cluster Operations

```bash
# Check cluster status
./scripts/manage.sh status

# View service logs
./scripts/manage.sh logs --stack webapp
./scripts/manage.sh logs --service webapp_webapp --follow

# Scale services
./scripts/manage.sh scale --service webapp_webapp --replicas 5

# Create backup
./scripts/manage.sh backup

# Restore from backup
./scripts/manage.sh restore --timestamp 1234567890

# Manage secrets
./scripts/manage.sh secrets --operation list
./scripts/manage.sh secrets --operation create --name api_key --value secret123

# Clean up unused resources
./scripts/manage.sh cleanup

# Health check all services
./scripts/manage.sh health
```

### Stack Management

```bash
# Deploy new stack
./scripts/deploy.sh myapp

# Force update stack (pull latest images)
./scripts/deploy.sh --force webapp

# Deploy to staging
./scripts/deploy.sh --environment staging webapp

# Dry run (check configuration)
./scripts/deploy.sh --dry-run worker
```

### Direct Ansible Commands

```bash
# Initialize swarm cluster
ansible-playbook playbooks/swarm_init.yml

# Deploy security features (headers + rate limiting)
ansible-playbook playbooks/deploy_security.yml

# Deploy specific stack
ansible-playbook playbooks/deploy_stack.yml -e target_stack=webapp

# Backup with custom retention
ansible-playbook playbooks/backup.yml -e backup_retention_days=60

# Create secret
ansible-playbook playbooks/manage_secrets.yml -e operation=create -e secret_name_var=db_pass -e secret_value_var=secretpass

# Check connectivity
ansible all -m ping

# Run command on all nodes
ansible all -m shell -a "docker node ls"
```

## Configuration

### Environment-Specific Settings

Edit `group_vars/all.yml` for global settings:
- Domain configuration
- Resource limits
- Backup settings
- Monitoring thresholds

### Host Groups

- `managers`: Swarm manager nodes
- `workers`: Application worker nodes  
- `edge`: Edge nodes for ingress traffic
- `bastion`: Bastion host for secure access

### Inventory Variables

Update inventory files with your server IPs:

```ini
[managers]
manager-1 ansible_host=10.0.1.10
manager-2 ansible_host=10.0.1.11
manager-3 ansible_host=10.0.1.12

[workers]
worker-1 ansible_host=10.0.1.20
# ... more workers

[edge]
edge-1 ansible_host=10.0.1.30
edge-2 ansible_host=10.0.1.31
```

## Security

### Default Security Features

- UFW firewall with minimal open ports
- Docker daemon TLS encryption
- Swarm encrypted overlay networks
- Secrets management for sensitive data
- Traefik with Let's Encrypt SSL certificates
- Basic authentication on admin interfaces
- Security headers (HSTS, X-Frame-Options, CSP-ready)
- Rate limiting (DDoS protection)

### Security Enhancements

The infrastructure includes comprehensive security protections:

#### Deploy Security Features
```bash
# Deploy security headers and rate limiting
ansible-playbook playbooks/deploy_security.yml
```

#### Security Features
- **Security Headers**
  - HSTS (HTTP Strict Transport Security)
  - X-Frame-Options (Clickjacking protection)
  - X-Content-Type-Options (MIME sniffing protection)
  - X-XSS-Protection (XSS filter)
  - Server/X-Powered-By headers removed
- **Rate Limiting** (100 req/min, burst: 50)
- **TLS Configuration** (TLS 1.2/1.3 with secure cipher suites)

#### Documentation
- Deployment Guide: `playbooks/deploy_security.yml`

### Post-Deployment Security

1. **Change Default Passwords**: Update credentials in `/opt/docker/stacks/*/credentials.txt`
2. **Configure SSL Domains**: Update domain names in playbooks
3. **Review Firewall Rules**: Adjust UFW rules in group_vars
4. **Set Up Monitoring Alerts**: Configure Alertmanager notifications
5. **Deploy Security Features**: Run `ansible-playbook playbooks/deploy_security.yml`
6. **Regular Updates**: Keep Docker and system packages updated

## Backup & Recovery

### Automated Backups

- PostgreSQL database dumps
- Redis data snapshots
- Docker stack configurations
- Swarm cluster metadata

### Backup Locations

- Local: `/opt/docker/backups/` on manager nodes
- Optional: S3 bucket (configure in group_vars)

### Restore Procedure

```bash
# List available backups
./scripts/manage.sh backup

# Restore latest backup
./scripts/manage.sh restore

# Restore specific backup
./scripts/manage.sh restore --timestamp 1634567890
```

## Monitoring & Alerting

### Metrics Collection

- Node metrics via Node Exporter
- Container metrics via cAdvisor  
- Application metrics via Prometheus
- Docker daemon metrics
- Traefik request metrics

### Grafana Dashboards

- Docker Swarm cluster overview
- Node resource utilization
- Service health and performance
- Traffic and response time metrics

### Alert Rules

- Service down alerts
- High resource usage warnings
- Disk space low alerts
- Container failure notifications

## Troubleshooting

### Common Issues

1. **Services not accessible externally**
   - Check Traefik configuration
   - Verify DNS records point to edge nodes
   - Ensure SSL certificates are valid

2. **Stack deployment fails**
   - Check Docker Swarm status: `docker node ls`
   - Verify all required secrets exist: `docker secret ls`
   - Check service logs: `docker service logs <service_name>`

3. **High resource usage**
   - Scale services: `./scripts/manage.sh scale --service <name> --replicas <count>`
   - Check Grafana dashboards for resource metrics
   - Review container resource limits

### Log Locations

- Service logs: `docker service logs <service_name>`
- Deployment logs: `/opt/docker/stacks/*/deployment_log_*.txt`
- Ansible logs: `/var/log/ansible.log`
- System logs: `journalctl -u docker`

### Debug Commands

```bash
# Check swarm status
docker node ls
docker service ls
docker stack ls

# Inspect service
docker service inspect <service_name>
docker service ps <service_name>

# Network troubleshooting
docker network ls
docker network inspect <network_name>

# Resource usage
docker system df
docker stats
```

## Customization

### Adding Custom Stacks

1. Create directory: `stacks/myapp/`
2. Add `docker-compose.yml` and `.env` files
3. Deploy: `./scripts/deploy.sh myapp`

### Modifying Existing Services

1. Edit stack files in `stacks/*/`
2. Redeploy: `./scripts/deploy.sh --force <stack_name>`

### Adding New Playbooks

1. Create playbook in `playbooks/`
2. Use existing patterns for consistency
3. Test with `--check` flag first

## Support

For issues and questions:

1. Check logs and service status
2. Review Grafana dashboards for insights
3. Use `--verbose` flag for detailed output
4. Consult Docker Swarm documentation

## License

This configuration is provided as-is for educational and production use.