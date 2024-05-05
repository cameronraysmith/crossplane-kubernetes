timeout := "300s"

# List tasks.
default:
  just --list

# Generates package files.
package-generate:
  timoni build dot-kubernetes timoni > package/all.yaml
  head -n -1 package/all.yaml > package/all.yaml.tmp
  mv package/all.yaml.tmp package/all.yaml

# Applies Compositions and Composite Resource Definition.
package-apply:
  kubectl apply --filename package/definition.yaml && sleep 1
  kubectl apply --filename package/all.yaml

# Builds and pushes the package.
package-publish: package-generate
  up login --token $UP_TOKEN
  up xpkg build --package-root package --name kubernetes.xpkg
  up xpkg push --package package/kubernetes.xpkg xpkg.upbound.io/$UP_ACCOUNT/dot-kubernetes:$VERSION
  rm package/kubernetes.xpkg
  yq --inplace ".spec.package = \"xpkg.upbound.io/devops-toolkit/dot-kubernetes:$VERSION\"" config.yaml

# Combines `package-generate` and `package-apply`.
package-generate-apply: package-generate package-apply

# Create a cluster, runs tests, and destroys the cluster.
test: cluster-create package-generate-apply
  chainsaw test
  just cluster-destroy

# Runs tests once assuming that the cluster is already created and everything is installed.
test-once: package-generate-apply
  chainsaw test

# Runs tests in the watch mode assuming that the cluster is already created and everything is installed.
test-watch:
  watchexec -w timoni -w tests "just test-once"

# Creates a kind cluster, installs Crossplane, providers, and packages, waits until they are healthy, and runs tests.
cluster-create: package-generate _cluster-create-kind
  just package-apply
  sleep 60
  kubectl wait --for=condition=healthy provider.pkg.crossplane.io --all --timeout={{timeout}}
  kubectl wait --for=condition=healthy function.pkg.crossplane.io --all --timeout={{timeout}}

# Destroys the cluster
cluster-destroy:
  kind delete cluster

# Creates a kind cluster
_cluster-create-kind:
  -kind create cluster
  -helm repo add crossplane-stable https://charts.crossplane.io/stable
  -helm repo update
  helm upgrade --install crossplane crossplane-stable/crossplane --namespace crossplane-system --create-namespace --wait
  for provider in `ls -1 providers | grep -v config`; do kubectl apply --filename providers/$provider; done

# Docker command to run sethvargo/ratchet to pin GitHub Actions workflows version tags to commit hashes
ratchet_base := "docker run -it --rm -v \"${PWD}:${PWD}\" -w \"${PWD}\" ghcr.io/sethvargo/ratchet:0.9.2"

# List of GitHub Actions workflows
gha_workflows := ".github/workflows/build14.yaml .github/workflows/build12.yaml"

# Pin all workflow versions to hash values (requires Docker)
ratchet-pin:
  @for workflow in {{gha_workflows}}; do \
    eval "{{ratchet_base}} pin $workflow"; \
  done

# Unpin hashed workflow versions to semantic values (requires Docker)
ratchet-unpin:
  @for workflow in {{gha_workflows}}; do \
    eval "{{ratchet_base}} unpin $workflow"; \
  done

# Update GitHub Actions workflows to the latest version (requires Docker)
ratchet-update:
  @for workflow in {{gha_workflows}}; do \
    eval "{{ratchet_base}} update $workflow"; \
  done
