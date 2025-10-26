variable "HCLOUD_TOKEN" {
  description = "Hetzner Cloud API Token"
  type        = string
  sensitive   = true
}


variable "AWS_ACCESS_KEY_ID" {
  description = "AWS Access Key ID"
  type        = string
  sensitive   = true
}

variable "AWS_SECRET_ACCESS_KEY" {
  description = "AWS Secret Access Key"
  type        = string
  sensitive   = true
}

variable "ssh_private_key_path" {
  type        = string
  description = "Path to SSH private key for Ansible"
  default     = "~/.ssh/fluffy-system-key"
  sensitive = true
}

variable "ssh_public_key" {
  type        = string
  description = "Public SSH key for server access"

}

variable "allowed_ssh_ips" {
  type        = list(string)
  description = "List of IPs allowed to SSH into the bastion host"
  default     = ["86.28.208.241/32"]
}

# Server Configuration
variable "bastion_server_type" {
  description = "Hetzner server type for bastion node"
  type        = string
  default     = "cx23"  
}

variable "manager_server_type" {
  description = "Hetzner server type for manager nodes"
  type        = string
  default     = "cx23"  

}

variable "manager_count" {
  description = "Number of Docker Swarm manager nodes (1, 3, or 5 recommended for HA)"
  type        = number
  default     = 3
  
  validation {
    condition     = var.manager_count >= 1 && var.manager_count <= 7 && var.manager_count % 2 == 1
    error_message = "Manager count must be an odd number between 1 and 7 (1, 3, 5, or 7) for proper quorum"
  }
}

variable "edge_server_type" {
  description = "Hetzner server type for edge nodes (Traefik load balancer)"
  type        = string
  default     = "cx23"  
}

variable "edge_count" {
  description = "Number of edge/load balancer nodes (1+ for high availability)"
  type        = number
  default     = 2
  
  validation {
    condition     = var.edge_count >= 1 && var.edge_count <= 5
    error_message = "Edge count must be between 1 and 5"
  }
}

variable "worker_server_type" {
  description = "Hetzner server type for worker nodes"
  type        = string
  default     = "cx23"  
}

variable "worker_count" {
  description = "Number of Docker Swarm worker nodes"
  type        = number
  default     = 5
  
  validation {
    condition     = var.worker_count >= 1 && var.worker_count <= 20
    error_message = "Worker count must be between 1 and 20"
  }
}

variable "location" {
  description = "Hetzner datacenter location"
  type        = string
  default     = "nbg1"  # Nuremberg, Germany
}


# Environment
variable "environment" {
  description = "Environment name (production, staging, development)"
  type        = string
  default     = "production"
  
  validation {
    condition     = contains(["production", "staging", "development"], var.environment)
    error_message = "Environment must be production, staging, or development"
  }
}


# Security Configuration
variable "enable_security_hardening" {
  description = "Enable security hardening (SSH hardening, fail2ban, kernel parameters)"
  type        = bool
  default     = true
}


variable "fail2ban_config" {
  description = "Fail2ban configuration for SSH protection"
  type = object({
    bantime       = number
    findtime      = number
    maxretry      = number
    ssh_maxretry  = number
  })
  default = {
    bantime      = 3600      # 1 hour ban
    findtime     = 600       # 10 minutes window
    maxretry     = 5         # Max retry attempts
    ssh_maxretry = 3         # Max SSH retry attempts
  }
}

variable "vps_image" {
  description = "Hetzner VPS image to use for all servers"
  type        = string
  default     = "ubuntu-22.04"
}