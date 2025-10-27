# Hetzner Cloud Provider Configuration
provider "hcloud" {
  token = var.HCLOUD_TOKEN
}

# SSH Key for Secure Access
resource "hcloud_ssh_key" "default" {
  name       = "fluffy-system-key"
  public_key = var.ssh_public_key
}

# Private Network
resource "hcloud_network" "main" {
  name     = "fluffy-system-network"
  ip_range = "10.0.0.0/16"
  labels = {
    environment = var.environment
    system      = "fluffy-system"
  }
}

# Network Subnets (Hetzner Infrastructure Layer)
# Docker overlay networks (traefik-public, database, monitoring)
resource "hcloud_network_subnet" "management" {
  network_id   = hcloud_network.main.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.0.1.0/24"
  # Hosts: Bastion (10.0.1.5), Managers (10.0.1.10-12), Edge (10.0.1.20-22)
}

resource "hcloud_network_subnet" "application" {
  network_id   = hcloud_network.main.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.0.2.0/24"
  # Hosts: Workers (10.0.2.15+)
}

# Bastion Host Firewall
resource "hcloud_firewall" "bastion_ssh" {
  name = "fluffy-system-bastion-ssh-fw"
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "22"
    source_ips  = var.allowed_ssh_ips
    description = "SSH access from allowed admin IPs"
  }
  labels = {
    purpose     = "bastion-ssh"
    environment = var.environment
    system      = "fluffy-system"
  }
}

# Internal Servers Firewall (SSH from Bastion Only)
resource "hcloud_firewall" "internal_ssh" {
  name = "fluffy-system-internal-ssh-fw"
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "22"
    source_ips  = ["10.0.1.5/32"] # Bastion's private IP
    description = "SSH access from bastion host"
  }
  rule {
    direction   = "in"
    protocol    = "icmp"
    source_ips  = ["10.0.0.0/16"]
    description = "Internal ICMP"
  }
  labels = {
    purpose     = "internal-ssh"
    environment = var.environment
    system      = "fluffy-system"
  }
}

# HTTP/HTTPS Firewall for Edge Nodes
resource "hcloud_firewall" "web_traffic" {
  name = "fluffy-system-web-traffic-fw"
  
  # HTTP
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "80"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "HTTP traffic (redirects to HTTPS)"
  }
  
  # HTTPS
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "443"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "HTTPS traffic for Traefik"
  }
  
  labels = {
    purpose     = "web-traffic"
    environment = var.environment
    system      = "fluffy-system"
  }
}

# Docker Swarm Firewall
resource "hcloud_firewall" "docker_swarm" {
  name = "fluffy-system-swarm-fw"
  
  # Swarm management
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "2377"
    source_ips  = ["10.0.0.0/16"]
    description = "Docker Swarm manager API (internal only)"
  }
  
  # Docker API over TCP (for Traefik remote access)
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "2376"
    source_ips  = ["10.0.0.0/16"]
    description = "Docker API over TCP (internal only)"
  }

  # Container network discovery
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "7946"
    source_ips  = ["10.0.0.0/16"]
    description = "Container network discovery TCP"
  }
  rule {
    direction   = "in"
    protocol    = "udp"
    port        = "7946"
    source_ips  = ["10.0.0.0/16"]
    description = "Container network discovery UDP"
  }
  
  # Overlay network
  rule {
    direction   = "in"
    protocol    = "udp"
    port        = "4789"
    source_ips  = ["10.0.0.0/16"]
    description = "Overlay network VXLAN"
  }
  
  labels = {
    purpose     = "docker-swarm"
    environment = var.environment
    system      = "fluffy-system"
  }
}

# Bastion Host
resource "hcloud_server" "bastion" {
  name         = "fluffy-system-bastion"
  image        = var.vps_image
  server_type  = var.bastion_server_type
  location     = var.location
  ssh_keys     = [hcloud_ssh_key.default.id]
  firewall_ids = [hcloud_firewall.bastion_ssh.id]
  
  network {
    network_id = hcloud_network.main.id
    ip         = "10.0.1.5"
  }
  
  user_data = templatefile("${path.module}/../scripts/node_init.sh", {
    node_type        = "bastion"
    node_index       = 0
    manager_ip       = ""
    worker_count     = var.worker_count
    enable_hardening = var.enable_security_hardening
    fail2ban_config  = jsonencode(var.fail2ban_config)
  })
  
  labels = {
    role              = "bastion"
    system            = "fluffy-system"
    environment       = var.environment
    security_hardened = var.enable_security_hardening ? "true" : "false"
  }
  
  depends_on = [
    hcloud_network.main,
    hcloud_network_subnet.management,
    hcloud_firewall.bastion_ssh
  ]
}

# Docker Swarm Manager Nodes (PRIVATE - High Availability)
resource "hcloud_server" "manager" {
  count       = var.manager_count
  name        = "fluffy-system-manager-${count.index + 1}"
  image       = var.vps_image
  server_type = var.manager_server_type
  location    = var.location
  ssh_keys    = [hcloud_ssh_key.default.id]
  
  # Manager is INTERNAL only - no web_traffic firewall!
  firewall_ids = [
    hcloud_firewall.internal_ssh.id,
    hcloud_firewall.docker_swarm.id
  ]
  
  network {
    network_id = hcloud_network.main.id
    ip         = "10.0.1.${10 + count.index}"
  }
  
  user_data = templatefile("${path.module}/../scripts/node_init.sh", {
    node_type        = "manager"
    node_index       = count.index + 1
    manager_ip       = "10.0.1.10"  # Primary manager IP
    worker_count     = var.worker_count
    enable_hardening = var.enable_security_hardening
    fail2ban_config  = jsonencode(var.fail2ban_config)
  })
  
  labels = {
    role              = "manager"
    system            = "fluffy-system"
    environment       = var.environment
    security_hardened = var.enable_security_hardening ? "true" : "false"
    public_access     = "false"
    manager_id        = count.index + 1
  }
  
  depends_on = [
    hcloud_network.main,
    hcloud_network_subnet.management,
    hcloud_firewall.internal_ssh,
    hcloud_firewall.docker_swarm
  ]
}

# Edge/Load Balancer Nodes (Traefik - High Availability)
resource "hcloud_server" "edge" {
  count       = var.edge_count
  name        = "fluffy-system-edge-${count.index + 1}"
  image       = var.vps_image
  server_type = var.edge_server_type
  location    = var.location
  ssh_keys    = [hcloud_ssh_key.default.id]
  
  # Edge accepts public web traffic, internal SSH, and Swarm communication
  firewall_ids = [
    hcloud_firewall.internal_ssh.id,
    hcloud_firewall.web_traffic.id,
    hcloud_firewall.docker_swarm.id
  ]
  
  network {
    network_id = hcloud_network.main.id
    ip         = "10.0.1.${20 + count.index}"
  }
  
  user_data = templatefile("${path.module}/../scripts/node_init.sh", {
    node_type        = "edge"
    node_index       = count.index + 1
    manager_ip       = "10.0.1.10"
    worker_count     = var.worker_count
    enable_hardening = var.enable_security_hardening
    fail2ban_config  = jsonencode(var.fail2ban_config)
  })
  
  labels = {
    role              = "edge"
    system            = "fluffy-system"
    environment       = var.environment
    security_hardened = var.enable_security_hardening ? "true" : "false"
    runs_traefik      = "true"
    swarm_member      = "true"
    edge_id           = count.index + 1
  }
  
  depends_on = [
    hcloud_network.main,
    hcloud_network_subnet.management,
    hcloud_firewall.internal_ssh,
    hcloud_firewall.web_traffic,
    hcloud_firewall.docker_swarm,
    hcloud_server.manager
  ]
}

# Docker Swarm Worker Nodes
resource "hcloud_server" "worker" {
  count       = var.worker_count
  name        = "fluffy-system-worker-${count.index + 1}"
  image       = var.vps_image
  server_type = var.worker_server_type
  location    = var.location
  ssh_keys    = [hcloud_ssh_key.default.id]
  firewall_ids = [
    hcloud_firewall.internal_ssh.id,
    hcloud_firewall.docker_swarm.id
  ]
  
  network {
    network_id = hcloud_network.main.id
    ip         = "10.0.2.${15 + count.index}"
  }
  
  user_data = templatefile("${path.module}/../scripts/node_init.sh", {
    node_type        = "worker"
    node_index       = count.index + 1
    manager_ip       = "10.0.1.10"
    worker_count     = var.worker_count
    enable_hardening = var.enable_security_hardening
    fail2ban_config  = jsonencode(var.fail2ban_config)
  })
  
  labels = {
    role              = "worker"
    system            = "fluffy-system"
    environment       = var.environment
    security_hardened = var.enable_security_hardening ? "true" : "false"
    worker_id         = count.index + 1
  }
  
  depends_on = [
    hcloud_network.main,
    hcloud_network_subnet.application,
    hcloud_firewall.internal_ssh,
    hcloud_firewall.docker_swarm,
    hcloud_server.manager
  ]
}



resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/../ansible/inventory/inventory.tpl", {
    bastion_ip           = hcloud_server.bastion.ipv4_address
    bastion_private_ip   = "10.0.1.5"
    
    manager_ips          = [for m in hcloud_server.manager : m.ipv4_address]
    manager_private_ips  = [for i in range(var.manager_count) : "10.0.1.${10 + i}"]
    manager_names        = [for i in range(var.manager_count) : "fluffy-system-manager-${i + 1}"]
    
    edge_ips             = [for e in hcloud_server.edge : e.ipv4_address]
    edge_private_ips     = [for i in range(var.edge_count) : "10.0.1.${20 + i}"]
    edge_names           = [for i in range(var.edge_count) : "fluffy-system-edge-${i + 1}"]
    
    worker_ips           = [for w in hcloud_server.worker : w.ipv4_address]
    worker_private_ips   = [for i in range(var.worker_count) : "10.0.2.${15 + i}"]
    worker_names         = [for i in range(var.worker_count) : "fluffy-system-worker-${i + 1}"]
    
    ssh_user             = "root"
    ssh_key_path         = var.ssh_private_key_path
  })
  
  filename        = "${path.module}/../ansible/inventory/hosts.ini"
  file_permission = "0644"
  
  depends_on = [
    hcloud_server.bastion,
    hcloud_server.manager,
    hcloud_server.edge,
    hcloud_server.worker
  ]
}

# Generate Ansible group_vars
resource "local_file" "ansible_group_vars" {
  content = templatefile("${path.module}/../ansible/inventory/group_vars/all.yml.tpl", {
    bastion_ip          = hcloud_server.bastion.ipv4_address
    primary_manager_ip  = "10.0.1.10"
    manager_count       = var.manager_count
    edge_count          = var.edge_count
    worker_count        = var.worker_count
    environment         = var.environment
  })
  
  filename        = "${path.module}/../ansible/inventory/group_vars/all.yml"
  file_permission = "0644"
  
  depends_on = [local_file.ansible_inventory]
}

output "ansible_setup_commands" {
  value = <<-EOT
    
    ╔═══════════════════════════════════════════════════════════╗
    ║         Ansible Inventory Generated Successfully         ║
    ╚═══════════════════════════════════════════════════════════╝
    
    📋 Inventory Location:
    ${abspath(local_file.ansible_inventory.filename)}
    
    🚀 Next Steps:
    
    1. Test Ansible connectivity:
       cd ../ansible
       ansible all -m ping
    
    2. Initialize Docker Swarm:
       ansible-playbook playbooks/swarm_init.yml
    
    3. Deploy Traefik (load balancer):
       ansible-playbook playbooks/deploy_traefik.yml
    
    4. Deploy your application stacks:
       ansible-playbook playbooks/deploy_app.yml
    
    📊 Inventory Summary:
    • Bastion: ${hcloud_server.bastion.ipv4_address}
    • Managers: ${var.manager_count} nodes (10.0.1.10-${9 + var.manager_count})
    • Edge: ${var.edge_count} nodes (10.0.1.20-${19 + var.edge_count})
    • Workers: ${var.worker_count} nodes (10.0.2.15-${14 + var.worker_count})
    
  EOT
  description = "Commands to use Ansible with the generated inventory"
}

# Outputs
output "bastion_public_ip" {
  value       = hcloud_server.bastion.ipv4_address
  description = "Public IP of the bastion host"
}

output "manager_public_ips" {
  value       = [for m in hcloud_server.manager : m.ipv4_address]
  description = "Public IPs of manager nodes (for reference only - managers are PRIVATE)"
}

output "manager_internal_ips" {
  value       = [for i in range(var.manager_count) : "10.0.1.${10 + i}"]
  description = "Internal IPs of Swarm manager nodes (PRIVATE - not exposed to internet)"
}

output "edge_public_ips" {
  value       = [for e in hcloud_server.edge : e.ipv4_address]
  description = "Public IPs of edge nodes - Point your DNS here (use load balancer or all IPs)"
}

output "edge_internal_ips" {
  value       = [for i in range(var.edge_count) : "10.0.1.${20 + i}"]
  description = "Internal IPs of edge nodes"
}

output "worker_internal_ips" {
  value       = [for i in range(var.worker_count) : "10.0.2.${15 + i}"]
  description = "Internal IPs of Swarm worker nodes"
}

output "network_summary" {
  value = <<-EOT
    
    ╔═══════════════════════════════════════════════════════════╗
    ║          Network IP Allocation Summary                    ║
    ╚═══════════════════════════════════════════════════════════╝
    
    Bastion:   10.0.1.5
    Managers:  10.0.1.10 - 10.0.1.${9 + var.manager_count}
    Edge:      10.0.1.20 - 10.0.1.${19 + var.edge_count}
    Workers:   10.0.2.15 - 10.0.2.${14 + var.worker_count}
    
  EOT
  description = "Network IP allocation summary"
}

output "deployment_summary" {
  value = <<-EOT
    
    ╔═══════════════════════════════════════════════════════════╗
    ║  Fluffy System - High Availability Architecture Deployed  ║
    ╚═══════════════════════════════════════════════════════════╝
    
    📍 Infrastructure:
    ┌────────────────────────────────────────────────────────┐
    │ Bastion (SSH):      ${hcloud_server.bastion.ipv4_address}                    │
    │ Managers (${var.manager_count}):        10.0.1.10-${9 + var.manager_count} - PRIVATE            │
    │ Edge Nodes (${var.edge_count}):      ${join(", ", [for e in hcloud_server.edge : e.ipv4_address])} │
    │ Workers (${var.worker_count}):         10.0.2.15-${14 + var.worker_count} - PRIVATE            │
    └────────────────────────────────────────────────────────┘
    
    🔐 High Availability Setup:
    ┌────────────────────────────────────────────────────────┐
    │ Manager Quorum:  ${var.manager_count} node${var.manager_count > 1 ? "s" : ""} (tolerates ${floor(var.manager_count / 2)} failure${floor(var.manager_count / 2) != 1 ? "s" : ""})      │
    │ Edge Load Bal:   ${var.edge_count} node${var.edge_count > 1 ? "s" : ""} (active-active)           │
    │ Worker Pool:     ${var.worker_count} node${var.worker_count > 1 ? "s" : ""}                             │
    └────────────────────────────────────────────────────────┘
    
    🌐 DNS Configuration:
    %{if var.edge_count == 1}Point DNS to: ${hcloud_server.edge[0].ipv4_address}
    %{else}Option 1: Round-robin DNS (all IPs)
    %{for e in hcloud_server.edge}  A record: ${e.ipv4_address}
    %{endfor}
    Option 2: Use external load balancer
    Option 3: Hetzner Load Balancer
    %{endif}
    
    ✅ Security Features:
    • ${var.manager_count} Manager node${var.manager_count > 1 ? "s" : ""} completely isolated (NO public IP)
    • ${var.edge_count} Edge node${var.edge_count > 1 ? "s" : ""} accept${var.edge_count == 1 ? "s" : ""} public traffic (80/443)
    • Swarm API (2377) internal only
    • SSH via bastion only
    • Automatic SSL via Let's Encrypt
    
    🎯 Next Steps:
    1. Configure DNS for edge node${var.edge_count > 1 ? "s" : ""}
    2. Initialize Swarm (see ha_setup_commands output)
    3. Deploy Traefik globally on edge nodes
    4. Deploy your services
    
    💰 Monthly Cost: ~€${(var.manager_count + var.edge_count + var.worker_count + 1) * 5}/month
    
    ═══════════════════════════════════════════════════════════
  EOT
  description = "High Availability deployment summary"
}