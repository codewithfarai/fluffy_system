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


variable "ssh_public_key" {
  type        = string
  description = "Public SSH key for server access"

}

variable "allowed_ssh_ips" {
  type        = list(string)
  description = "List of IPs allowed to SSH into the bastion host"
  default     = ["86.28.208.241/32"]
}

variable "environment" {
  type        = string
  default     = "prod"
  description = "Environment name (e.g., production, staging)"
}

variable "worker_count" {
  type        = number
  default     = 2
  description = "Number of Docker Swarm worker nodes"
  validation {
    condition     = var.worker_count >= 0
    error_message = "Worker count must be non-negative."
  }
}

variable "server_type" {
  type        = string
  default     = "cx23"
  description = "Hetzner server type for nodes"
}

variable "location" {
  type        = string
  default     = "fsn1"
  description = "Hetzner data center location"
}

variable "enable_security_hardening" {
  type        = bool
  default     = true
  description = "Enable security hardening (e.g., Fail2Ban)"
}

variable "fail2ban_config" {
  type = object({
    bantime      = number
    findtime     = number
    maxretry     = number
    ssh_maxretry = number
  })
  default = {
    bantime      = 600
    findtime     = 600
    maxretry     = 5
    ssh_maxretry = 3
  }
  description = "Fail2Ban configuration"
}