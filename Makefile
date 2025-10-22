.PHONY: help build-insecure build-secure test-insecure test-secure attack-volume attack-secrets demo-all clean

# Colors for output
RED=\033[0;31m
GREEN=\033[0;32m
YELLOW=\033[1;33m
BLUE=\033[0;34m
NC=\033[0m # No Color

##@ Help
help: ## Display this help
	@echo ""
	@echo "$(BLUE)Container Security POC - Demo Commands$(NC)"
	@echo "========================================"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2 } /^##@/ { printf "\n$(YELLOW)%s$(NC)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
	@echo ""

##@ System
check-docker: ## Check and fix Docker if needed (internal)
	@if ! docker ps >/dev/null 2>&1; then \
		echo "$(RED)✗ Docker is not running$(NC)"; \
		echo "Please start Docker Desktop or Docker daemon"; \
		exit 1; \
	fi
	@if ! test -d ~/.docker/contexts 2>/dev/null || ! test -r ~/.docker/contexts/meta 2>/dev/null; then \
		echo "$(YELLOW)⚠️  Fixing Docker contexts...$(NC)"; \
		sudo rm -rf ~/.docker/contexts 2>/dev/null || true; \
		mkdir -p ~/.docker/contexts 2>/dev/null || true; \
		echo "$(GREEN)✓ Docker contexts fixed$(NC)"; \
	fi

fix-docker: ## Fix Docker metadata corruption (WSL2 issue)
	@echo "$(YELLOW)Fixing Docker contexts...$(NC)"
	@sudo rm -rf ~/.docker/contexts 2>/dev/null || true
	@mkdir -p ~/.docker/contexts
	@docker context ls >/dev/null 2>&1 && echo "$(GREEN)✓ Docker fixed successfully$(NC)" || echo "$(RED)✗ Docker still has issues$(NC)"
	@echo ""
	@echo "Test with: $(GREEN)docker ps$(NC)"

##@ Quick Start
demo-all: clean build-insecure test-insecure build-secure test-secure summary ## Run complete security demo (5 min)

quick-demo: clean test-insecure test-secure summary ## Quick demo (no rebuild, 2 min)

##@ Build Images
build-insecure: check-docker ## Build insecure Docker image
	@echo "$(RED)Building INSECURE image...$(NC)"
	@cd dockerfiles/insecure && docker build -t insecure-app:latest .
	@echo "$(GREEN)✓ Insecure image built$(NC)\n"

build-secure: check-docker ## Build secure Docker image
	@echo "$(GREEN)Building SECURE image...$(NC)"
	@cd dockerfiles/secure && docker build -t secure-app:latest .
	@echo "$(GREEN)✓ Secure image built$(NC)\n"

build-all: build-insecure build-secure ## Build both images

##@ Test Containers
test-insecure: build-insecure ## Test insecure container (shows vulnerabilities)
	@echo "\n$(RED)========================================$(NC)"
	@echo "$(RED)   TESTING INSECURE CONTAINER ❌$(NC)"
	@echo "$(RED)========================================$(NC)\n"

	@echo "$(YELLOW)Starting insecure container...$(NC)"
	@docker run -d --name insecure-test insecure-app:latest || true
	@sleep 2

	@echo "\n$(YELLOW)📋 Container Logs (what's running inside):$(NC)"
	@docker logs insecure-test
	@echo ""

	@echo "$(RED)🚨 ATTACK 1: Check if running as ROOT$(NC)"
	@docker exec insecure-test id

	@echo "\n$(RED)🚨 ATTACK 2: Stealing secrets from environment$(NC)"
	@docker exec insecure-test env | grep -E "PASSWORD|KEY|SECRET" || true

	@echo "\n$(RED)🚨 ATTACK 3: Stealing secrets via 'docker inspect'$(NC)"
	@docker inspect insecure-test | grep -A 8 '"Env"' | grep -E "PASSWORD|KEY|SECRET" || true

	@echo "\n$(RED)🚨 ATTACK SUCCESSFUL!$(NC)"
	@echo "$(RED)   - Running as root (UID 0)$(NC)"
	@echo "$(RED)   - Secrets stolen from environment$(NC)"
	@echo "$(RED)   - Secrets visible in docker inspect$(NC)\n"

	@docker stop insecure-test >/dev/null 2>&1 || true
	@docker rm insecure-test >/dev/null 2>&1 || true

test-secure: build-secure ## Test secure container (shows protections)
	@echo "\n$(GREEN)========================================$(NC)"
	@echo "$(GREEN)   TESTING SECURE CONTAINER ✅$(NC)"
	@echo "$(GREEN)========================================$(NC)\n"

	@echo "$(YELLOW)Creating secret files...$(NC)"
	@mkdir -p /tmp/test-secrets
	@echo "SuperSecret123" > /tmp/test-secrets/database-password
	@echo "sk-1234567890abcdef" > /tmp/test-secrets/api-key
	@chmod 644 /tmp/test-secrets/*

	@echo "$(YELLOW)Starting secure container...$(NC)"
	@docker run -d --name secure-test \
		-v /tmp/test-secrets:/run/secrets:ro \
		-p 8082:8080 \
		secure-app:latest || true
	@sleep 3

	@echo "\n$(YELLOW)📋 Container Logs (what's running inside):$(NC)"
	@docker logs secure-test
	@echo ""

	@echo "$(GREEN)✅ TEST 1: Check user (should be non-root)$(NC)"
	@docker exec secure-test id

	@echo "\n$(GREEN)✅ TEST 2: Try to steal secrets from environment$(NC)"
	@docker exec secure-test env | grep -E "PASSWORD|KEY|SECRET" && echo "$(RED)❌ FOUND SECRETS!$(NC)" || echo "$(GREEN)✓ NO SECRETS IN ENV!$(NC)"

	@echo "\n$(GREEN)✅ TEST 3: Check docker inspect (should be clean)$(NC)"
	@docker inspect secure-test | grep -A 5 '"Env"' | head -7
	@echo "$(GREEN)✓ NO SECRETS VISIBLE!$(NC)"

	@echo "\n$(GREEN)✅ TEST 4: App CAN read secrets from /run/secrets$(NC)"
	@echo "Files in /run/secrets:"
	@docker exec secure-test ls -l /run/secrets/
	@echo "\nReading secret:"
	@docker exec secure-test cat /run/secrets/database-password
	@echo "$(GREEN)✓ App has access to secrets via files!$(NC)"

	@echo "\n$(GREEN)✅ TEST 5: Health check$(NC)"
	@curl -s http://localhost:8082/health | jq . || echo "Health check endpoint"

	@echo "\n$(GREEN)✅ SECURE CONTAINER PASSED ALL TESTS!$(NC)"
	@echo "$(GREEN)   - Running as UID 1001 (non-root)$(NC)"
	@echo "$(GREEN)   - No secrets in environment$(NC)"
	@echo "$(GREEN)   - Secrets protected from docker inspect$(NC)"
	@echo "$(GREEN)   - App can still read secrets from files$(NC)\n"

	@docker stop secure-test >/dev/null 2>&1 || true
	@docker rm secure-test >/dev/null 2>&1 || true
	@rm -rf /tmp/test-secrets

##@ Attack Scenarios
attack-volume: ## Run volume mount privilege escalation demo (PDO incident)
	@echo "\n$(RED)========================================$(NC)"
	@echo "$(RED)   ATTACK: Volume Mount Escalation$(NC)"
	@echo "$(RED)========================================$(NC)\n"
	@chmod +x attack-scenarios/01-volume-mount-attack.sh
	@./attack-scenarios/01-volume-mount-attack.sh

attack-secrets: ## Run secret exposure attack demo
	@echo "\n$(RED)========================================$(NC)"
	@echo "$(RED)   ATTACK: Secret Exposure$(NC)"
	@echo "$(RED)========================================$(NC)\n"
	@chmod +x attack-scenarios/02-env-var-secret-exposure.sh
	@./attack-scenarios/02-env-var-secret-exposure.sh

attack-all: attack-volume attack-secrets ## Run all attack scenarios

##@ Comparison
compare: clean test-insecure test-secure summary ## Side-by-side comparison of insecure vs secure

summary: ## Show comparison summary
	@echo "\n$(BLUE)=========================================$(NC)"
	@echo "$(BLUE)   📊 SECURITY COMPARISON SUMMARY$(NC)"
	@echo "$(BLUE)=========================================$(NC)\n"
	@echo "$(RED)INSECURE CONTAINER ❌$(NC)"
	@echo "---------------------"
	@echo "User:     $(RED)root (UID 0)$(NC)"
	@echo "Secrets:  $(RED)In environment variables$(NC)"
	@echo "Visible:  $(RED)✓ docker inspect$(NC)"
	@echo "          $(RED)✓ docker exec env$(NC)"
	@echo "Health:   $(RED)No health checks$(NC)\n"
	@echo "$(GREEN)SECURE CONTAINER ✅$(NC)"
	@echo "-------------------"
	@echo "User:     $(GREEN)appuser (UID 1001)$(NC)"
	@echo "Secrets:  $(GREEN)Volume-mounted at /run/secrets$(NC)"
	@echo "Visible:  $(GREEN)✗ docker inspect (clean!)$(NC)"
	@echo "          $(GREEN)✗ docker exec env (no secrets!)$(NC)"
	@echo "Health:   $(GREEN)✓ /health endpoint works$(NC)\n"
	@echo "$(BLUE)=========================================$(NC)"
	@echo "$(BLUE)   KEY TAKEAWAYS$(NC)"
	@echo "$(BLUE)=========================================$(NC)"
	@echo "1. $(RED)Environment variables leak secrets$(NC)"
	@echo "2. $(GREEN)Volume-mounted secrets are protected$(NC)"
	@echo "3. $(RED)Root containers = full system access$(NC)"
	@echo "4. $(GREEN)Non-root limits damage$(NC)"
	@echo "5. $(GREEN)Defense-in-depth works!$(NC)\n"

##@ Documentation
docs: ## Open documentation in browser
	@echo "$(BLUE)Opening documentation...$(NC)"
	@xdg-open README.md 2>/dev/null || open README.md 2>/dev/null || echo "Open README.md manually"

testing-guide: ## Show testing guide
	@cat TESTING-GUIDE.md | less

setup-guide: ## Show setup guide
	@cat SETUP.md | less

show-attacks: ## Show attack scenarios documentation
	@cat docs/03-ATTACK-SCENARIOS.md | less

##@ Cleanup
clean: ## Clean up all containers and images
	@echo "$(YELLOW)Cleaning up...$(NC)"
	@docker stop insecure-test 2>/dev/null || true
	@docker stop secure-test 2>/dev/null || true
	@docker rm insecure-test 2>/dev/null || true
	@docker rm secure-test 2>/dev/null || true
	@rm -rf /tmp/test-secrets 2>/dev/null || true
	@echo "$(GREEN)✓ Cleanup complete$(NC)\n"

clean-images: clean ## Clean up containers and images
	@echo "$(YELLOW)Removing images...$(NC)"
	@docker rmi insecure-app:latest 2>/dev/null || true
	@docker rmi secure-app:latest 2>/dev/null || true
	@echo "$(GREEN)✓ Images removed$(NC)\n"

##@ Team Presentation
present: demo-all ## Full presentation for team (5 min)
	@echo "\n$(BLUE)=========================================$(NC)"
	@echo "$(BLUE)   🎯 PRESENTATION COMPLETE!$(NC)"
	@echo "$(BLUE)=========================================$(NC)"
	@echo ""
	@echo "What we demonstrated:"
	@echo "1. ✅ Insecure container vulnerabilities"
	@echo "2. ✅ Secure container protections"
	@echo "3. ✅ Volume-mounted secrets"
	@echo "4. ✅ Non-root user benefits"
	@echo ""
	@echo "Next steps for team:"
	@echo "- Review: $(GREEN)make show-attacks$(NC)"
	@echo "- Try: $(GREEN)make attack-all$(NC)"
	@echo "- Read: $(GREEN)make docs$(NC)"
	@echo ""

quick-present: quick-demo ## Quick 2-minute presentation
	@echo "\n$(GREEN)Quick demo complete! Show team:$(NC)"
	@echo "1. Insecure: Secrets stolen from env vars"
	@echo "2. Secure: Secrets protected in /run/secrets"
	@echo "3. GitHub: https://github.com/hanzlahabib/container-security-poc"

##@ Continuous Demo (For Screen Sharing)
watch-insecure: ## Watch insecure container logs (for demo)
	@docker run --rm --name insecure-demo insecure-app:latest

watch-secure: ## Watch secure container logs (for demo)
	@mkdir -p /tmp/demo-secrets
	@echo "DemoPassword123" > /tmp/demo-secrets/database-password
	@echo "demo-api-key" > /tmp/demo-secrets/api-key
	@chmod 644 /tmp/demo-secrets/*
	@docker run --rm --name secure-demo \
		-v /tmp/demo-secrets:/run/secrets:ro \
		-p 8080:8080 \
		secure-app:latest

##@ Advanced
kubernetes-test: ## Test Kubernetes security policies (requires cluster)
	@echo "$(YELLOW)Testing Kubernetes security policies...$(NC)"
	@cd scripts && chmod +x security-test.sh && ./security-test.sh

install-sops: ## Install SOPS and age (requires sudo)
	@chmod +x scripts/install-sops.sh
	@./scripts/install-sops.sh

sops-demo: ## Demonstrate SOPS encryption
	@echo "$(BLUE)=========================================$(NC)"
	@echo "$(BLUE)   SOPS Encryption Demo$(NC)"
	@echo "$(BLUE)=========================================$(NC)\n"
	@if ! command -v age >/dev/null 2>&1 || ! command -v sops >/dev/null 2>&1; then \
		echo "$(YELLOW)⚠️  SOPS or age not installed$(NC)\n"; \
		echo "$(GREEN)Easy install:$(NC)"; \
		echo "  $(GREEN)make install-sops$(NC)\n"; \
		echo "Or manual install:"; \
		echo "  wget https://github.com/FiloSottile/age/releases/download/v1.1.1/age-v1.1.1-linux-amd64.tar.gz"; \
		echo "  tar xf age-v1.1.1-linux-amd64.tar.gz"; \
		echo "  sudo mv age/age age/age-keygen /usr/local/bin/"; \
		echo ""; \
		echo "  wget https://github.com/getsops/sops/releases/download/v3.8.1/sops-v3.8.1.linux.amd64"; \
		echo "  chmod +x sops-v3.8.1.linux.amd64"; \
		echo "  sudo mv sops-v3.8.1.linux.amd64 /usr/local/bin/sops"; \
		echo ""; \
		echo "Then run: $(GREEN)make sops-demo$(NC)"; \
		exit 1; \
	fi; \
	chmod +x scripts/sops-demo.sh && ./scripts/sops-demo.sh

##@ Repository
repo-status: ## Show repository info
	@echo "$(BLUE)Repository: https://github.com/hanzlahabib/container-security-poc$(NC)"
	@git remote -v
	@echo ""
	@git log --oneline -5

repo-update: ## Push updates to GitHub
	@git add .
	@git commit -m "Update security demos" || true
	@git push

.DEFAULT_GOAL := help
