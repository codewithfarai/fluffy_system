## v1.5.0 (2025-10-27)

### feat

- Enhance Traefik password management with file checks and secure storage
- Add support for encrypted and internal Docker networks in configuration
- Update Traefik configuration and add socket proxy support
- Update Traefik configuration and add deployment for a simple website
- Update bastion IP address and add Docker TLS configuration
- Update Docker TLS configuration and validation across infrastructure
- Add Docker Swarm setup script and infrastructure stacks
- add Ansible inventory and group_vars generation to Terraform configuration
- update .gitignore to include Ansible files, temporary files, secrets, and cache
- add execution permission for hetzner_security_audit script and document security audit command
- enhance Terraform configuration for Hetzner Cloud with improved server types, counts, and validation rules
- add Hetzner Security Audit script for firewall and server security assessment
- add comprehensive SSH helper commands and security hardening verification scripts for high availability deployment
- add initial Terraform configuration for Hetzner Cloud including networking and firewall rules
- add variables for SSH access and security hardening configuration in Terraform
- add node initialization and security hardening scripts for SSH and kernel protection
- addition of  terraform configuration files for managing infrastructure. I have also configured s3 bucket for storing the tf.state file

### fix

- Update Traefik password hashing command and remove unnecessary extraction step
- Correct shell command syntax for extracting Traefik password hash
- update default bastion IP address in SSH helper script
- ensure system packages are fully upgraded during node initialization

### chore

- Remove obsolete TLS configuration summary document
- update .gitignore to include Terraform and IDE files

## v1.4.15 (2025-10-23)

### chore

- add CI workflow for code quality checks with Python and Poetry

## v1.4.14 (2025-10-23)

### chore

- update permissions for GitHub Actions workflow
- add GitHub Actions workflow for version bump and release creation
- add poetry configuration and project metadata for fluffy_system
