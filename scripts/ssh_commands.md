# Fluffy System SSH Helper Commands

## Setup

First, make the scripts executable:

```bash
chmod +x ssh_helper.sh
chmod +x verify_hardening.sh
chmod +x hetzner_security_audit
```

## Available Commands

### List Hosts
Display all available hosts in your infrastructure:

```bash
./ssh_helper.sh list
```

### Connect to a Host
SSH into any host in the system:

```bash
./ssh_helper.sh connect <host>
```

### Verify Host Security
Run security verification on a specific host:

```bash
./ssh_helper.sh verify <host>
```

### Verify All Nodes
Run security verification on all 11 nodes:

```bash
./ssh_helper.sh verify-all
```

### Copy Verification Script
Copy the verification script to the bastion host:

```bash
./ssh_helper.sh copy-verify
```

## Connection Examples

### Bastion (Public Access)
```bash
./ssh_helper.sh connect bastion
```

### Managers (3 nodes)
```bash
./ssh_helper.sh connect manager1  # Primary manager - 10.0.1.10
./ssh_helper.sh connect manager2  # 10.0.1.11
./ssh_helper.sh connect manager3  # 10.0.1.12
```

### Edge Nodes (2 nodes)
```bash
./ssh_helper.sh connect edge1  # 10.0.1.20 (Public: 91.107.227.16)
./ssh_helper.sh connect edge2  # 10.0.1.21 (Public: 162.55.186.121)
```

### Workers (5 nodes)
```bash
./ssh_helper.sh connect worker1  # 10.0.2.15
./ssh_helper.sh connect worker2  # 10.0.2.16
./ssh_helper.sh connect worker3  # 10.0.2.17
./ssh_helper.sh connect worker4  # 10.0.2.18
./ssh_helper.sh connect worker5  # 10.0.2.19
```

## Verification Examples

### Single Host Verification
```bash
./ssh_helper.sh verify bastion
./ssh_helper.sh verify manager1
./ssh_helper.sh verify edge1
./ssh_helper.sh verify worker1
```

### All Nodes Verification
Verify all 11 nodes in one command:

```bash
./ssh_helper.sh verify-all
```

### Security Audit

```bash
./hetzner_security_audit
```

This will check:
- 1 bastion host
- 3 manager nodes
- 2 edge nodes
- 5 worker nodes

## Environment Variables

Override default configuration if needed:

```bash
# Set bastion IP
export BASTION_IP="91.98.121.0"

# Set SSH key path
export SSH_KEY="~/.ssh/fluffy-system-key"

# Set SSH username
export SSH_USER="root"

# Set HETZNER_API_TOKEN
export HETZNER_API_TOKEN='your-token'
```
cd ../ansible
  ansible all -m ping
  ansible-playbook -i inventory/hosts.ini playbooks/swarm_init.yml
## Infrastructure Overview

**Total Nodes:** 11

| Type | Count | Hosts | Internal IPs |
|------|-------|-------|--------------|
| Bastion | 1 | bastion | 157.90.126.147 (public) |
| Managers | 3 | manager1-3 | 10.0.1.10-12 |
| Edge | 2 | edge1-2 | 10.0.1.20-21 |
| Workers | 5 | worker1-5 | 10.0.2.15-19 |

## How It Works

- **Bastion Host**: Direct SSH connection via public IP
- **Internal Nodes**: Automatic ProxyJump through bastion host
- **Security**: Uses StrictHostKeyChecking=no for convenience
- **High Availability**: 3 managers for Docker Swarm quorum
- **Load Balancing**: 2 edge nodes for traffic distribution

## Quick Reference

```bash
# List all hosts
./ssh_helper.sh list

# Connect to primary manager
./ssh_helper.sh connect manager1

# Check security on bastion
./ssh_helper.sh verify bastion

# Verify entire infrastructure
./ssh_helper.sh verify-all

# Get help
./ssh_helper.sh
```

## Notes

- All internal nodes are accessed through the bastion host automatically
- The script handles ProxyJump configuration for you
- Make sure your SSH key is properly configured
- Verification requires `verify_hardening.sh` script in the same directory