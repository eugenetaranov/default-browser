APP := DefaultBrowserRouter

.PHONY: build test bundle install clean release

build: ## Build the package (debug)
	swift build

test: ## Run the routing/config test suite
	swift run RouterTests

bundle: ## Assemble an ad-hoc codesigned .app in build/
	./scripts/bundle.sh

install: bundle ## Build and install the app into /Applications
	rm -rf "/Applications/$(APP).app"
	cp -R "build/$(APP).app" /Applications/
	open -a "$(APP)"

clean: ## Remove build artifacts
	rm -rf .build build

release: ## Tag and push a release; auto-bumps patch (override: make release VERSION=1.2.0)
	@set -e; \
	git fetch --tags --quiet 2>/dev/null || true; \
	if [ -n "$(VERSION)" ]; then \
	  v="$(VERSION)"; \
	else \
	  last=$$(git tag -l 'v*' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$$' | sort -V | tail -1); \
	  if [ -z "$$last" ]; then \
	    v="0.0.1"; \
	  else \
	    b=$${last#v}; major=$${b%%.*}; rest=$${b#*.}; minor=$${rest%%.*}; patch=$${rest##*.}; \
	    v="$$major.$$minor.$$((patch + 1))"; \
	  fi; \
	  echo "Latest tag: $${last:-none} -> next: v$$v"; \
	fi; \
	test -z "$$(git status --porcelain)" || { echo "Working tree not clean; commit first."; exit 1; }; \
	git tag "v$$v"; \
	git push origin "v$$v"; \
	echo "Pushed tag v$$v; CI + Release workflows will run."
