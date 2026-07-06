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

release: ## Tag and push a release (make release VERSION=1.0)
	@test -n "$(VERSION)" || { echo "Usage: make release VERSION=1.0"; exit 1; }
	@test -z "$$(git status --porcelain)" || { echo "Working tree not clean; commit first."; exit 1; }
	git tag "v$(VERSION)"
	git push origin "v$(VERSION)"
	@echo "Pushed tag v$(VERSION); CI + Release workflows will run."
