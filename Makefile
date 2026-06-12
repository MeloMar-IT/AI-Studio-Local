.PHONY: help install build test lint format run-app run-worker

help:
	@echo "AI Studio Local Makefile"
	@echo "Usage:"
	@echo "  make install      Install dependencies for app and worker"
	@echo "  make build        Build the macOS application"
	@echo "  make test         Run all tests"
	@echo "  make lint         Run linting"
	@echo "  make format       Run formatting"
	@echo "  make run-app      Run the SwiftUI macOS app"
	@echo "  make run-worker   Run the Python worker"

install:
	./scripts/install-worker.sh

test:
	./scripts/test.sh

lint:
	./scripts/lint.sh

format:
	./scripts/format.sh

run-app:
	./scripts/run-app.sh

run-worker:
	./scripts/run-worker.sh
