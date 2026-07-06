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

release: ## Tag and push a release; suggests next patch (override: make release TAG=v1.2.0)
	@set -e; \
	test -z "$$(git status --porcelain)" || { echo "Working tree not clean; commit first."; exit 1; }; \
	git fetch --tags --quiet 2>/dev/null || true; \
	if [ -z "$(TAG)" ]; then \
		LATEST=$$(git tag --sort=-version:refname 2>/dev/null | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$$' | head -1); \
		if [ -z "$$LATEST" ]; then \
			SUGGESTED="v0.1.0"; \
		else \
			MAJOR=$$(echo $$LATEST | sed 's/v\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)/\1/'); \
			MINOR=$$(echo $$LATEST | sed 's/v\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)/\2/'); \
			PATCH=$$(echo $$LATEST | sed 's/v\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)/\3/'); \
			PATCH=$$((PATCH + 1)); \
			SUGGESTED="v$$MAJOR.$$MINOR.$$PATCH"; \
		fi; \
		echo "Latest tag: $${LATEST:-none}"; \
		printf "Enter tag [$$SUGGESTED]: "; \
		read INPUT_TAG; \
		TAG=$${INPUT_TAG:-$$SUGGESTED}; \
	else \
		TAG="$(TAG)"; \
	fi; \
	echo "Creating release $$TAG..."; \
	git tag -a "$$TAG" -m "Release $$TAG"; \
	git push origin "$$TAG"; \
	echo "Release $$TAG pushed; CI + Release workflows will run."
