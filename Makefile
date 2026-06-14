.PHONY: help install build test lint format run-app run-app-dev run-worker run-worker-dev

help:
	@echo "AI Studio Local Makefile"
	@echo "Usage:"
	@echo "  make install      Install dependencies for app and worker"
	@echo "  make build        Build the macOS application"
	@echo "  make test         Run all tests"
	@echo "  make lint         Run linting"
	@echo "  make format       Run formatting"
	@echo "  make run-app      Run the SwiftUI macOS app (Production mode)"
	@echo "  make run-app-dev  Run the SwiftUI macOS app (Development mode)"
	@echo "  make run-worker   Run the Python worker (Production mode)"
	@echo "  make run-worker-dev Run the Python worker (Development mode)"
	@echo "  make test-worker  Run Python worker tests"

install:
	./scripts/install-worker.sh

test:
	./scripts/test.sh

test-worker:
	./scripts/test.sh

lint:
	./scripts/lint.sh

format:
	./scripts/format.sh

run-app:
	./scripts/run-app.sh

run-app-dev:
	./scripts/run-app.sh --dev

run-worker:
	./scripts/run-worker.sh

run-worker-dev:
	./scripts/run-worker.sh --dev
