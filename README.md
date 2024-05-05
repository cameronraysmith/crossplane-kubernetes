## Setup development environment

Install [nix](https://nixos.org/download/), with flakes enabled via
[Determinate Systems](https://zero-to-nix.com/concepts/nix-installer), and
[direnv](https://direnv.net/)

```bash
# This make target may help, but see the contents
# of the dependencies before executing on your machine:

make setup-dev

# instructions to configure direnv to work with your shell
# will be printed, or inspect the link in the Makefile before
# executing
direnv allow
```

You should only need to run `direnv allow` once.
If either your nix flake or direnv configuration change, you may need to run
it again before any of the commands in the sections below.

## Generate manifests

```bash
just package-generate

exit
```

## Run Tests

```bash
just cluster-create

just test-watch

# Stop the watcher with `ctrl+c`

just cluster-destroy

exit
```

## Publish To Upbound

```bash
# Replace `[...]` with the Upbound Cloud account
export UP_ACCOUNT=[...]

# Replace `[...]` with the Upbound Cloud token
export UP_TOKEN=[...]

# Replace `[...]` with the version of the package (e.g., `v0.5.0`)
export VERSION=[...]

just package-publish

exit
```
