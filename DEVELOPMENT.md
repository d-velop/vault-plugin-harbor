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

## Creating a release

Once features / fixes / upgrades have been tested and merged into the `main` branch, a new release can be created by pushing a tag.

```bash
git checkout main
git pull
git tag -s v0.x.x
git push origin --tags
```

Afterwards a GitHub actions pipeline will generate the required binaries and publish a GitHub release.
