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
