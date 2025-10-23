.PHONY: help install lint fix format check type

.DEFAULT_GOAL := help

help: ## Show available commands
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'

install: ## Install dependencies
	poetry install

lint: ## Check code with ruff
	poetry run ruff check .

fix: ## Fix code issues with ruff
	poetry run ruff check . --fix

format: ## Format code with ruff
	poetry run ruff format .

type: ## Run mypy type checker
	poetry run mypy fluffy_system/

check: lint type ## Run lint + type check