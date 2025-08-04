.PHONY: test \
fmt tidy gofmt gofumpt goimports lint local-lint staticcheck \
build clean

APPNAME := vault-plugin-harbor
HARBOR_VERSION = v2.13.0
TEST_HARBOR_URL = "http://localhost:30002"
TEST_HARBOR_USERNAME = admin
TEST_HARBOR_PASSWORD = Harbor12345

init:
	go install github.com/rakyll/gotest@latest
	go install mvdan.cc/gofumpt@latest
	go install golang.org/x/tools/cmd/goimports@latest
	go install github.com/goreleaser/goreleaser@latest
	go install honnef.co/go/tools/cmd/staticcheck@latest
	go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@latest

test:
	gotest -v ./...

integration-test:
	go clean -testcache &&\
	VAULT_ACC=1 TEST_HARBOR_URL=$(TEST_HARBOR_URL) TEST_HARBOR_USERNAME=$(TEST_HARBOR_USERNAME) TEST_HARBOR_PASSWORD=$(TEST_HARBOR_PASSWORD) gotest -v ./...

integration-test-coverage:
	go clean -testcache &&\
	VAULT_ACC=1 TEST_HARBOR_URL=$(TEST_HARBOR_URL) TEST_HARBOR_USERNAME=$(TEST_HARBOR_USERNAME) TEST_HARBOR_PASSWORD=$(TEST_HARBOR_PASSWORD) gotest -coverprofile=c.out -v ./...

integration-test-full: setup-harbor integration-test

# Exclude auto-generated code to be formatted by gofmt, gofumpt & goimports.
FIND=find . \( -path "./examples" -o -path "./scripts" \) -prune -false -o -name '*.go'

fmt: gofmt gofumpt goimports tidy

tidy:
	go mod tidy

gofmt:
	$(FIND) -exec gofmt -l -w {} \;

gofumpt:
	$(FIND) -exec gofumpt -w {} \;

goimports:
	$(FIND) -exec goimports -w {} \;

lint:
	golint ./...
	golangci-lint run

local-lint:
	docker run --rm -v $(shell pwd):/$(APPNAME) -w /$(APPNAME)/. \
	golangci/golangci-lint golangci-lint run --sort-results -v

staticcheck:
	staticcheck ./...

# Create a Harbor instance as a docker container via Kind.
setup-harbor:
	scripts/setup-harbor.sh $(HARBOR_VERSION) $(TEST_HARBOR_URL) $(TEST_HARBOR_USERNAME) $(TEST_HARBOR_PASSWORD)

uninstall-harbor:
	kind delete clusters "goharbor-integration-tests-$(HARBOR_VERSION)"

build:
	gorelease build --snapshot --rm-dist

clean:
	rm -rf dist/ build/
