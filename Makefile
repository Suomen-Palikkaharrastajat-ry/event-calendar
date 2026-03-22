.PHONY: help clean watch format check statics dist \
        elm-dev elm-build elm-test elm-check elm-format \
        elm-dev-local elm-build-local \
        statics-build statics-test statics-check statics-format statics-local \
        dist-local build test

LOCAL_PB_URL = http://127.0.0.1:8090

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

# ── Development environment ──────────────────────────────────────────────────

.PHONY: shell
shell: ## Enter devenv shell
	devenv shell

.PHONY: develop
develop: devenv.local.nix devenv.local.yaml ## Bootstrap opinionated development environment
	devenv shell --profile=devcontainer -- code .

devenv.local.nix:
	cp devenv.local.nix.example devenv.local.nix

devenv.local.yaml:
	cp devenv.local.yaml.example devenv.local.yaml

# ── Elm frontend ─────────────────────────────────────────────────────────────

elm-dev: ## Start Elm + Vite dev server (hot reload)
	cd elm-app && pnpm dev

elm-dev-local: ## Start Elm + Vite dev server against local PocketBase
	cd elm-app && VITE_POCKETBASE_URL=$(LOCAL_PB_URL) pnpm dev

elm-build: ## Production build of Elm SPA → build/
	cd elm-app && pnpm build

elm-build-local: ## Production build of Elm SPA targeting local PocketBase
	cd elm-app && VITE_POCKETBASE_URL=$(LOCAL_PB_URL) pnpm build

elm-test: ## Run Elm unit tests
	# pnpm wraps the elm binary through node (breaks on ELF); use system elm directly
	@ELM_BIN=$$(which elm) && \
		mkdir -p elm-app/node_modules/.bin && \
		printf '#!/bin/sh\nexec "%s" "$$@"\n' "$$ELM_BIN" \
		> elm-app/node_modules/.bin/elm && chmod +x elm-app/node_modules/.bin/elm
	cd elm-app && pnpm test

elm-check: ## Check Elm formatting (no changes)
	cd elm-app && elm-format --validate src/

elm-format: ## Auto-format Elm source files
	cd elm-app && elm-format --yes src/

# ── Haskell static generator ─────────────────────────────────────────────────

statics-build: ## Build Haskell static generator
	cabal build statics

statics: ## Generate static files (ics, rss, atom, html, geojson, images)
	cabal run statics

statics-local: ## Generate static files against local PocketBase
	POCKETBASE_URL=$(LOCAL_PB_URL) cabal run statics

statics-test: ## Run Haskell tests
	cabal test statics-test

statics-check: ## Lint Haskell source (hlint)
	hlint statics/src/ statics/app/

statics-format: ## Auto-format Haskell source (fourmolu)
	find statics/src statics/app -name '*.hs' | xargs fourmolu --mode inplace

# ── Combined targets ─────────────────────────────────────────────────────────

watch: elm-dev ## Start development server

build: elm-build ## Production build of Elm SPA

dist: elm-build statics ## Full production build: Elm SPA + static files
	cp -r static/. build/

dist-local: elm-build-local statics-local ## Full local build: Elm SPA + static files against local PocketBase
	cp -r static/. build/

test: elm-test statics-test ## Run all tests (Elm + Haskell)

check: elm-check statics-check ## Run all linting/formatting checks

format: elm-format statics-format ## Auto-format all code

clean: ## Remove build output
	$(RM) -r build
