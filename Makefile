LOCAL_PB_URL = http://127.0.0.1:8090

.PHONY: help
help: ## Show available targets
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

# ── Elm frontend ──────────────────────────────────────────────────────────────

.PHONY: elm-dev
elm-dev: ## Start Elm + Vite dev server (hot reload)
	cd elm-app && pnpm dev

.PHONY: elm-dev-local
elm-dev-local: ## Start Elm + Vite dev server against local PocketBase
	cd elm-app && VITE_POCKETBASE_URL=$(LOCAL_PB_URL) pnpm dev

.PHONY: elm-build
elm-build: ## Production build of Elm SPA → build/
	cd elm-app && pnpm build

.PHONY: elm-build-local
elm-build-local: ## Production build of Elm SPA targeting local PocketBase
	cd elm-app && VITE_POCKETBASE_URL=$(LOCAL_PB_URL) pnpm build

.PHONY: elm-test
elm-test: ## Run Elm unit tests
	# pnpm wraps the elm binary through node (breaks on ELF); use system elm directly
	@ELM_BIN=$$(which elm) && \
		mkdir -p elm-app/node_modules/.bin && \
		printf '#!/bin/sh\nexec "%s" "$$@"\n' "$$ELM_BIN" \
		> elm-app/node_modules/.bin/elm && chmod +x elm-app/node_modules/.bin/elm
	cd elm-app && pnpm test

.PHONY: elm-check
elm-check: ## Check Elm formatting (no changes)
	cd elm-app && elm-format --validate src/

.PHONY: elm-format
elm-format: ## Auto-format Elm source files
	cd elm-app && elm-format --yes src/

# ── Haskell static generator ──────────────────────────────────────────────────

.PHONY: statics-build
statics-build: ## Build Haskell static generator
	cabal build statics

.PHONY: statics
statics: ## Generate static files (ics, rss, atom, html, geojson, images)
	cabal run statics

.PHONY: statics-local
statics-local: ## Generate static files against local PocketBase
	POCKETBASE_URL=$(LOCAL_PB_URL) cabal run statics

.PHONY: statics-test
statics-test: ## Run Haskell tests
	cabal test statics-test

.PHONY: statics-check
statics-check: ## Lint Haskell source (hlint)
	hlint statics/src/ statics/app/

.PHONY: statics-format
statics-format: ## Auto-format Haskell source (fourmolu)
	find statics/src statics/app -name '*.hs' | xargs fourmolu --mode inplace

.PHONY: repl
repl: ## Start the Haskell REPL
	cabal repl statics

.PHONY: cabal-check
cabal-check: ## Check the package for common errors
	cabal check

# ── Combined targets ──────────────────────────────────────────────────────────

.PHONY: watch
watch: elm-dev ## Start development server

.PHONY: build
build: elm-build ## Production build of Elm SPA

.PHONY: dist
dist: elm-build statics ## Full production build: Elm SPA + static files
	cp -r static/. build/

.PHONY: dist-local
dist-local: elm-build-local statics-local ## Full local build: Elm SPA + static files against local PocketBase
	cp -r static/. build/

.PHONY: test
test: elm-test statics-test ## Run all tests (Elm + Haskell)

.PHONY: check
check: elm-check statics-check ## Run all linting/formatting checks

.PHONY: format
format: elm-format statics-format ## Auto-format all code

.PHONY: clean
clean: ## Remove build output
	$(RM) -r build
