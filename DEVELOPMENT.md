# Development workflow

## Upgrading dependencies

To upgrade the Go dependencies:

```bash
go get -u ./...
go mod tidy
```

This will bump both direct and indirect dependencies to the latest allowed versions.

## Upgrading Go version

Upgrading the Go version must be done across a few different config files:

- `go.mod` must reference the new version
- `devcontainer.json` must point to an image with the new version
- `.golangci.yml` must reference the new version for the checks
- `.github/workflows/*` must install the new versions during builds / tests / ...

## Verify upgrades

After upgrading dependencies or making code changes, run `make full` to execute a wide range of checks to confirm that everything still works as expected.
