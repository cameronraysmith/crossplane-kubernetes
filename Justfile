timeout := "300s"

# List tasks.
default:
  just --list

# Generates package files.
package-generate:
  kcl run kcl/crossplane.k > package/crossplane.yaml
  kcl run kcl/definition.k > package/definition.yaml
  kcl run kcl/compositions.k > package/compositions.yaml
  kcl run kcl/backstage-template.k > backstage/crossplane-kubernetes.yaml

# Applies Compositions and Composite Resource Definition.
package-apply:
  kubectl apply --filename package/definition.yaml && sleep 1
  kubectl apply --filename package/compositions.yaml

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
  watchexec -w kcl -w tests "just test-once"

# Creates a kind cluster, installs Crossplane, providers, and packages, waits until they are healthy, and runs tests.
cluster-create: package-generate _cluster-create-kind
  just package-apply
  sleep 60
  kubectl wait --for=condition=healthy provider.pkg.crossplane.io --all --timeout={{timeout}}
  kubectl wait --for=condition=healthy function.pkg.crossplane.io --all --timeout={{timeout}}

# Executes `cluster-create` and sets it up to use Google Cloud.
cluster-create-google: cluster-create
  rm .env
  gcloud auth login
  export USE_GKE_GCLOUD_AUTH_PLUGIN=True
  echo "export USE_GKE_GCLOUD_AUTH_PLUGIN=True" >> .env
  export PROJECT_ID=dot-$(date +%Y%m%d%H%M%S)
  echo "export PROJECT_ID=$PROJECT_ID" >> .env
  gcloud projects create $PROJECT_ID
  echo "## Open https://console.cloud.google.com/marketplace/product/google/container.googleapis.com?project=$PROJECT_ID in a browser and *ENABLE* the API." | gum format
  gum input --placeholder "Press the enter key to continue."
  SA_NAME=devops-toolkit
  SA="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
  gcloud iam service-accounts create $SA_NAME --project $PROJECT_ID
  gcloud projects add-iam-policy-binding --role roles/admin $PROJECT_ID --member serviceAccount:$SA
  gcloud iam service-accounts keys create gcp-creds.json --project $PROJECT_ID --iam-account $SA
  kubectl --namespace crossplane-system create secret generic gcp-creds --from-file creds=./gcp-creds.json
  yq --inplace ".spec.projectID = \"$PROJECT_ID\"" providers/provider-config-google.yaml
  kubectl apply --filename providers/provider-config-google.yaml
  echo "## Execute `source .env` to set up the environment variables."

# Destroys the cluster
cluster-destroy:
  kind delete cluster --name crossplane-kubernetes

# Removes Google Cloud project and executes `cluster-destroy`.
cluster-destroy-google:
  gcloud projects delete --quiet
  just cluster-destroy

# Creates a kind cluster
_cluster-create-kind:
  -kind create cluster --config kind.yaml
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
