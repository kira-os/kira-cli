.PHONY: build test clean install lint

# Build the kira binary
build:
	go build -o kira cmd/kira/main.go

# Run tests
test:
	go test ./...

# Run tests with coverage
test-coverage:
	go test -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html

# Clean build artifacts
clean:
	rm -f kira coverage.out coverage.html

# Install kira to /usr/local/bin
install: build
	sudo mv kira /usr/local/bin/

# Run linter
lint:
	golangci-lint run

# Run all checks
check: lint test

# Build for multiple platforms
build-all:
	GOOS=linux GOARCH=amd64 go build -o kira-linux-amd64 cmd/kira/main.go
	GOOS=darwin GOARCH=amd64 go build -o kira-darwin-amd64 cmd/kira/main.go
	GOOS=windows GOARCH=amd64 go build -o kira-windows-amd64.exe cmd/kira/main.go

# Development setup
dev-setup:
	go mod download
	go mod tidy

# Run kira with help
help:
	./kira --help

# Demo initialization
demo:
	./kira init demo-workspace
	cd demo-workspace && ../kira new prd "Demo Feature" todo "This is a demo feature"
	cd demo-workspace && ../kira move 001 doing
	cd demo-workspace && ../kira save "Initial demo setup"

