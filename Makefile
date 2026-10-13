
#################################################################################
# GLOBALS
#################################################################################

PROJECT_NAME := lstm-log-analysis
PYTHON_INTERPRETER ?= python3
VENV_DIR := .venv
VENV_PYTHON := $(VENV_DIR)/bin/python
VENV_PIP := $(VENV_DIR)/bin/pip

DOCKER_USERNAME ?=
DOCKER_IMAGE := $(if $(DOCKER_USERNAME),$(DOCKER_USERNAME)/,)lstm-log-analysis
DOCKER_TAG ?= latest

#################################################################################
# COMMANDS
#################################################################################

.PHONY: help setup_environment requirements data features train predict \
        evaluate test lint clean all ci docker-build docker-run docker-push \
        docker-login docker-clean check-docker

help: ## Show all available commands
	@echo "Available commands in $(PROJECT_NAME):"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		sort | awk 'BEGIN {FS = ":.*?## "}; \
		{printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

#################################################################################
# PYTHON ENVIRONMENT
#################################################################################

setup_environment: ## Create Python virtual environment
	$(PYTHON_INTERPRETER) -m venv $(VENV_DIR)
	$(VENV_PYTHON) -m pip install --upgrade pip setuptools wheel
	@echo ">>> Virtual environment created."

requirements: ## Install project dependencies
	$(VENV_PYTHON) -m pip install -r requirements.txt
	@echo ">>> Dependencies installed."

#################################################################################
# MACHINE LEARNING PIPELINE
#################################################################################

data: ## Download or generate and parse raw log data
	$(VENV_PYTHON) src/dataset.py --download-or-generate
	@echo ">>> Data preparation complete."

features: ## Extract features and create train/validation/test splits
	$(VENV_PYTHON) src/features.py
	@echo ">>> Feature engineering complete."

train: ## Train the DeepLog LSTM model
	$(VENV_PYTHON) src/modeling/train.py
	@echo ">>> Model training complete."

predict: ## Run anomaly detection with top-k evaluation
	$(VENV_PYTHON) src/modeling/predict.py --top-k 9
	@echo ">>> Prediction and evaluation complete."

evaluate: predict ## Alias for prediction and evaluation

all: data features train predict ## Run the complete ML pipeline
	@echo ">>> ML pipeline completed successfully."

#################################################################################
# TESTING AND CODE QUALITY
#################################################################################

test: ## Run unit and integration tests
	$(VENV_PYTHON) -m pytest tests/ src/test_scripts/ -v

lint: ## Run Flake8 critical-error checks
	$(VENV_PYTHON) -m flake8 src/ tests/ \
		--count --select=E9,F63,F7,F82 \
		--show-source --statistics

ci: lint test ## Run local CI checks (lint and tests)
	@echo ">>> CI checks completed successfully."

#################################################################################
# DOCKER
#################################################################################

check-docker: ## Verify Docker is installed and running
	docker info

docker-build: ## Build Docker image
	docker build -t $(DOCKER_IMAGE):$(DOCKER_TAG) .

docker-run: ## Run the Docker image
	docker run --rm $(DOCKER_IMAGE):$(DOCKER_TAG)

docker-login: ## Log in to Docker Hub interactively
	docker login --username "$(DOCKER_USERNAME)"

docker-push: ## Push image to Docker Hub
	@test -n "$(DOCKER_USERNAME)" || \
		(echo "ERROR: Set DOCKER_USERNAME first."; exit 1)
	docker push $(DOCKER_USERNAME)/lstm-log-analysis:$(DOCKER_TAG)

docker-clean: ## Remove the locally built Docker image
	docker image rm $(DOCKER_IMAGE):$(DOCKER_TAG)

#################################################################################
# CLEANUP
#################################################################################

clean: ## Remove Python caches and pytest cache
	find . -type f -name "*.py[co]" -delete
	find . -type d -name "__pycache__" -prune -exec rm -rf {} +
	find . -type d -name ".pytest_cache" -prune -exec rm -rf {} +
	find . -type d -name "*.egg-info" -prune -exec rm -rf {} +
	@echo ">>> Temporary files cleaned."
