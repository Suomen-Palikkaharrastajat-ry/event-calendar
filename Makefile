LOCAL_PB_URL = http://127.0.0.1:8090

.PHONY: help
help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

# ── Vendor / submodules ──────────────────────────────────────────────────────

.PHONY: vendor
vendor: ## Init and update all git submodules to their pinned commits
	@# In CI environments (GitHub Actions, Netlify) SSH access is unavailable;
	@# rewrite git@github.com: to https://github.com/ so submodules clone via HTTPS.
	@[ -z "$$CI" ] || git config --global url."https://github.com/".insteadOf "git@github.com:"
	git submodule update --init

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
	cd elm-app && vite

.PHONY: elm-dev-local
elm-dev-local: ## Start Elm + Vite dev server against local PocketBase
	cd elm-app && VITE_POCKETBASE_URL=$(LOCAL_PB_URL) vite

build/.elm-stamp: $(shell find elm-app/src -name '*.elm') elm-app/elm.json
	cd elm-app && vite build
	touch $@

.PHONY: elm-build
elm-build: build/.elm-stamp ## Production build of Elm SPA → build/

.PHONY: elm-build-local
elm-build-local: ## Production build of Elm SPA targeting local PocketBase
	cd elm-app && VITE_POCKETBASE_URL=$(LOCAL_PB_URL) vite build

.PHONY: elm-tailwind-gen
elm-tailwind-gen: ## Generate typed Tailwind Elm modules into elm-app/.elm-tailwind/
	cd elm-app && elm-tailwind-classes gen

.PHONY: elm-test
elm-test: elm-tailwind-gen ## Run Elm unit tests
	cd elm-app && elm-test

.PHONY: elm-check
elm-check: ## Check Elm formatting (no changes)
	cd elm-app && elm-format --validate src/

.PHONY: elm-format
elm-format: ## Auto-format Elm source files
	cd elm-app && elm-format --yes src/

# ── Haskell static generator ──────────────────────────────────────────────────

HS_SOURCES := $(shell find statics/src statics/app -name '*.hs') statics/statics.cabal $(wildcard cabal.project*)

statics/statics: $(HS_SOURCES)
	cabal build statics
	cp $$(cabal list-bin statics) $@

.PHONY: statics-build
statics-build: statics/statics ## Build Haskell static generator

build/.statics-stamp: statics/statics
	mkdir -p build
	./statics/statics
	touch $@

.PHONY: statics
statics: build/.statics-stamp ## Generate static files (ics, rss, atom, html, geojson, images)

.PHONY: statics-local
statics-local: ## Generate static files against local PocketBase
	POCKETBASE_URL=$(LOCAL_PB_URL) ./statics/statics

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
dist: build/.elm-stamp build/.statics-stamp ## Full production build: Elm SPA + static files
	cp -r static/. build/

build/.statics-stamp-nix:
	mkdir -p build
	statics
	touch build/.statics-stamp

.PHONY: dist-ci
dist-ci: build/.elm-stamp build/.statics-stamp-nix ## CI build: Elm SPA + statics via nix-provided binary
	cp -r static/. build/

.PHONY: dist-local
dist-local: elm-build-local statics-local ## Full local build: Elm SPA + static files against local PocketBase
	cp -r static/. build/

# ── Test & quality ────────────────────────────────────────────────────────────

.PHONY: test
test: elm-test statics-test ## Run all tests (Elm + Haskell)

.PHONY: check
check: elm-check statics-check ## Run all linting/formatting checks

.PHONY: format
format: elm-format statics-format ## Auto-format all code
	treefmt

# ── Cleanup ───────────────────────────────────────────────────────────────────

.PHONY: clean
clean: ## Remove build output
	$(RM) -r build elm-app/.elm-tailwind
