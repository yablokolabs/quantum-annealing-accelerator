# ==============================================================================
# Quantum-Inspired Optimization Accelerator
# ==============================================================================
# Root Makefile — orchestrates RTL, backend, and frontend builds
# ==============================================================================

.PHONY: all rtl-lint rtl-sim backend-install backend-test frontend-install frontend-build docker-up clean help

help:
	@echo "╔══════════════════════════════════════════════════════════════╗"
	@echo "║  Quantum-Inspired Optimization Accelerator — Build System  ║"
	@echo "╠══════════════════════════════════════════════════════════════╣"
	@echo "║  RTL                                                       ║"
	@echo "║    rtl-lint        Verilator lint on all RTL modules        ║"
	@echo "║    rtl-sim         Run all RTL testbenches                  ║"
	@echo "║                                                            ║"
	@echo "║  Backend                                                   ║"
	@echo "║    backend-install Install Python dependencies              ║"
	@echo "║    backend-test    Run pytest suite                         ║"
	@echo "║    backend-run     Start FastAPI server                     ║"
	@echo "║                                                            ║"
	@echo "║  Frontend                                                  ║"
	@echo "║    frontend-install Install npm dependencies                ║"
	@echo "║    frontend-build  Production build                        ║"
	@echo "║    frontend-dev    Development server                      ║"
	@echo "║                                                            ║"
	@echo "║  Infrastructure                                            ║"
	@echo "║    docker-up       Launch full stack via Docker Compose     ║"
	@echo "║    docker-down     Stop Docker Compose                     ║"
	@echo "║    clean           Remove all build artifacts               ║"
	@echo "╚══════════════════════════════════════════════════════════════╝"

all: rtl-lint backend-test frontend-build

# RTL
rtl-lint:
	$(MAKE) -C sim lint

rtl-sim:
	$(MAKE) -C sim sim

# Backend
backend-install:
	cd backend && pip install -r requirements.txt

backend-test:
	cd backend && python -m pytest tests/ -v

backend-run:
	cd backend && uvicorn main:app --reload --host 0.0.0.0 --port 8000

# Frontend
frontend-install:
	cd frontend && npm install

frontend-build:
	cd frontend && npm run build

frontend-dev:
	cd frontend && npm run dev

# Docker
docker-up:
	docker compose up --build -d

docker-down:
	docker compose down

# Clean
clean:
	$(MAKE) -C sim clean
	rm -rf backend/__pycache__ backend/**/__pycache__
	rm -rf frontend/node_modules frontend/dist
