# Default target
.DEFAULT_GOAL := help

# Help target
help:
	@echo "Available targets:"
	@echo "  init     - Initialize Terraform with exported credentials"
	@echo "  plan     - Run terraform plan with exported credentials"
	@echo "  apply    - Run terraform apply with exported credentials"
	@echo "  destroy  - Run terraform destroy with exported credentials"
	@echo "  validate - Validate Terraform configuration"
	@echo "  fmt      - Format Terraform files"
	@echo "  clean    - Clean Terraform state and modules"

# Initialize Terraform
init:
	@eval $$(grep -v '^#' terraform.tfvars | grep -v '^$$' | sed 's/^/export /') && terraform init

# Plan Terraform
plan:
	@eval $$(grep -v '^#' terraform.tfvars | grep -v '^$$' | sed 's/^/export /') && terraform plan

# Apply Terraform
apply:
	@eval $$(grep -v '^#' terraform.tfvars | grep -v '^$$' | sed 's/^/export /') && terraform apply -auto-approve

# Destroy Terraform
destroy:
	@eval $$(grep -v '^#' terraform.tfvars | grep -v '^$$' | sed 's/^/export /') && terraform destroy

# Validate Terraform configuration
validate:
	terraform validate

# Format Terraform files
fmt:
	terraform fmt -recursive

# Clean Terraform state and modules
clean:
	rm -rf .terraform
	rm -f .terraform.lock.hcl
	rm -f terraform.tfstate*

.PHONY: help init plan apply destroy validate fmt clean