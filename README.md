## Generate manifests

```bash
direnv allow

just package-generate

exit
```

## Run Tests

```bash
direnv allow

just cluster-create

just test-watch

# Stop the watcher with `ctrl+c`

just cluster-destroy

exit
```

## Publish To Upbound

```bash
direnv allow

# Replace `[...]` with the Upbound Cloud account
export UP_ACCOUNT=[...]

# Replace `[...]` with the Upbound Cloud token
export UP_TOKEN=[...]

# Replace `[...]` with the version of the package (e.g., `v0.5.0`)
export VERSION=[...]

just package-publish

exit
```
