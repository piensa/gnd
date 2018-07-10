PWD := $(shell pwd)
GOPATH := $(shell go env GOPATH)
LDFLAGS := $(shell go run buildscripts/gen-ldflags.go)

BUILD_LDFLAGS := '$(LDFLAGS)'

all: build

checks:
	@echo "Checking dependencies"
	@(env bash $(PWD)/buildscripts/checkdeps.sh)
	@echo "Checking for project in GOPATH"
	@(env bash $(PWD)/buildscripts/checkgopath.sh)

getdeps:
	@echo "Installing golint" && go get -u github.com/golang/lint/golint
	@echo "Installing gocyclo" && go get -u github.com/fzipp/gocyclo
	@echo "Installing deadcode" && go get -u github.com/remyoudompheng/go-misc/deadcode
	@echo "Installing misspell" && go get -u github.com/client9/misspell/cmd/misspell
	@echo "Installing ineffassign" && go get -u github.com/gordonklaus/ineffassign

verifiers: getdeps vet fmt lint cyclo deadcode spelling

vet:
	@echo "Running $@"
	@go tool vet -atomic -bool -copylocks -nilfunc -printf -shadow -rangeloops -unreachable -unsafeptr -unusedresult cmd
	@go tool vet -atomic -bool -copylocks -nilfunc -printf -shadow -rangeloops -unreachable -unsafeptr -unusedresult pkg

fmt:
	@echo "Running $@"
	@gofmt -d cmd
	@gofmt -d pkg

lint:
	@echo "Running $@"
	@${GOPATH}/bin/golint -set_exit_status github.com/piensa/geo/cmd...
	@${GOPATH}/bin/golint -set_exit_status github.com/piensa/geo/pkg...

ineffassign:
	@echo "Running $@"
	@${GOPATH}/bin/ineffassign .

cyclo:
	@echo "Running $@"
	@${GOPATH}/bin/gocyclo -over 100 cmd
	@${GOPATH}/bin/gocyclo -over 100 pkg

deadcode:
	@echo "Running $@"
	@${GOPATH}/bin/deadcode -test $(shell go list ./...)

spelling:
	@${GOPATH}/bin/misspell -error `find cmd/`
	@${GOPATH}/bin/misspell -error `find pkg/`
	@${GOPATH}/bin/misspell -error `find docs/`

# Builds geo, runs the verifiers then runs the tests.
check: test
test: verifiers build
	@echo "Running unit tests"
	@go test $(GOFLAGS) -tags kqueue ./...
	@echo "Running functional tests"
	@(env bash $(PWD)/functional-tests.sh)

coverage: build
	@echo "Running all coverage for geo"
	@(env bash $(PWD)/buildscripts/go-coverage.sh)

# Builds geo locally.
build: checks
	@echo "Building geo binary to './geo'"
	@CGO_ENABLED=0 go build -tags kqueue --ldflags $(BUILD_LDFLAGS) -o $(PWD)/geo

pkg-add:
	@echo "Adding new package $(PKG)"
	@${GOPATH}/bin/govendor add $(PKG)

pkg-update:
	@echo "Updating new package $(PKG)"
	@${GOPATH}/bin/govendor update $(PKG)

pkg-remove:
	@echo "Remove new package $(PKG)"
	@${GOPATH}/bin/govendor remove $(PKG)

pkg-list:
	@$(GOPATH)/bin/govendor list

# Builds geo and installs it to $GOPATH/bin.
install: build
	@echo "Installing geo binary to '$(GOPATH)/bin/geo'"
	@mkdir -p $(GOPATH)/bin && cp $(PWD)/geo $(GOPATH)/bin/geo
	@echo "Installation successful. To learn more, try \"geo --help\"."

clean:
	@echo "Cleaning up all the generated files"
	@find . -name '*.test' | xargs rm -fv
	@rm -rvf geo
	@rm -rvf build
	@rm -rvf release
