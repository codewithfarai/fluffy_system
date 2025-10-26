
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

# Network Subnets
resource "hcloud_network_subnet" "management" {
  network_id   = hcloud_network.main.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.0.1.0/24"
}

resource "hcloud_network_subnet" "application" {
  network_id   = hcloud_network.main.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.0.2.0/24"
}

resource "hcloud_network_subnet" "database" {
  network_id   = hcloud_network.main.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.0.3.0/24"
}

resource "hcloud_network_subnet" "monitoring" {
  network_id   = hcloud_network.main.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.0.4.0/24"
}

# Firewalls
resource "hcloud_firewall" "bastion_ssh" {
  name = "fluffy-system-bastion-ssh"
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

resource "hcloud_firewall" "internal_ssh" {
  name = "fluffy-system-internal-ssh"
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "22"
    source_ips  = ["10.0.1.5/32"]
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

resource "hcloud_firewall" "web_traffic" {
  name = "fluffy-system-web-traffic"
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "80"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "HTTP traffic"
  }
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "443"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "HTTPS traffic"
  }
  labels = {
    purpose     = "web-traffic"
    environment = var.environment
    system      = "fluffy-system"
  }
}

resource "hcloud_firewall" "internal_services" {
  name = "fluffy-system-internal-services"
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "2377"
    source_ips  = ["10.0.0.0/16"]
    description = "Docker Swarm manager API"
  }
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
  rule {
    direction   = "in"
    protocol    = "udp"
    port        = "4789"
    source_ips  = ["10.0.0.0/16"]
    description = "Overlay network VXLAN"
  }
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "5432"
    source_ips  = ["10.0.2.0/24", "10.0.4.0/24"]
    description = "PostgreSQL from app and monitoring"
  }
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "3306"
    source_ips  = ["10.0.2.0/24", "10.0.4.0/24"]
    description = "MySQL from app and monitoring"
  }
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "6379"
    source_ips  = ["10.0.2.0/24", "10.0.4.0/24"]
    description = "Redis from app and monitoring"
  }
  labels = {
    purpose     = "internal-services"
    environment = var.environment
    system      = "fluffy-system"
  }
}