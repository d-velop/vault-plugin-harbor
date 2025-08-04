#!/usr/bin/env bash
CLUSTER_NAME="goharbor-integration-tests-${1}"
HARBOR_VERSION="${1}"
HARBOR_URL="${2}"
HARBOR_USERNAME="${3}"
HARBOR_PASSWORD="${4}"
HARBOR_CHART_VERSION=""
REGISTRY_IMAGE_TAG="2.7.1"

echo "[PREPARE] Checking for existence of necessary tools..."

docker --version &>/dev/null
if [[ $? -ne "0" ]]; then
    >&2 echo "Docker not installed, aborting."
    exit 1
fi

kind version &>/dev/null
if [[ $? -ne "0" ]]; then
    >&2 echo "kind not installed, aborting."
    exit 1
fi

kubectl version --client &>/dev/null
if [[ $? -ne "0" ]]; then
    >&2 echo "kubectl not installed, aborting."
    exit 1
fi

helm_version="$(helm version --short)"
if ! [[ ${helm_version} =~ ^v3. ]]; then
    >&2 echo "Helm not installed or not v3, aborting."
    exit 1
fi

jq --version &>/dev/null
if [[ $? -ne "0" ]]; then
    >&2 echo "jq not installed, aborting."
    exit 1
fi

yq --version &>/dev/null
if [[ $? -ne "0" ]]; then
    >&2 echo "yq not installed, aborting."
    exit 1
fi

echo "[PREPARE] Checking needed program arguments..."
if [[ -z "${HARBOR_VERSION}" ]]; then
    >&2 echo "Harbor version as first argument not provided, aborting."
    exit 1
fi

# Map Goharbor versions to their corresponding helm chart version
while read CHART HARBOR; do
    if [[ "${HARBOR_VERSION#v}" == "${HARBOR}" ]]; then
        HARBOR_CHART_VERSION="${CHART}"
    fi
done <<< $(curl -s https://helm.goharbor.io/index.yaml | yq -e -r '.entries.harbor[] | .version + " " + .appVersion' -)

if [[ -z "${HARBOR_CHART_VERSION}" ]]; then
    >&2 echo "Unsupported Harbor version, aborting."
    exit 1
fi

echo "[PREPARE] Creating a new kind cluster to deploy Harbor into..."
kind create cluster --config testdata/kind-config.yml --name "${CLUSTER_NAME}"
if [[ "$?" -ne "0" ]]; then
    >&2 echo "Could not create kind cluster, aborting."
    exit 1
fi

echo "[PREPARE] Verifying cluster can be reached using kubectl..."
kubectl cluster-info
kubectl get nodes
if [[ "$?" -ne "0" ]]; then
    >&2 echo "Could not reach kind cluster using kubectl, aborting."
    exit 1
fi

echo "[PREPARE] Installing Harbor via Helm..."
helm repo add harbor https://helm.goharbor.io && helm repo update
helm install harbor harbor/harbor \
    --set expose.type=nodePort,expose.tls.enabled=false,externalURL=http://core.harbor.domain \
    --set persistence.enabled=false \
    --set trivy.enabled=false \
    --set notary.enabled=false \
    --namespace default \
    --kube-context kind-"${CLUSTER_NAME}" \
    --version="${HARBOR_CHART_VERSION}"
if [[ "$?" -ne "0" ]]; then
    >&2 echo "Could not install Harbor, aborting."
    exit 1
fi

echo "[PREPARE] Installing separate docker registry for integration tests..."
helm repo add stable https://charts.helm.sh/stable && helm repo update
helm install registry stable/docker-registry \
    --set service.port=5000,image.tag=${REGISTRY_IMAGE_TAG}
if [[ "$?" -ne "0" ]]; then
    >&2 echo "Could not install Registry, aborting."
    exit 1
fi

echo "[PREPARE] Waiting for Harbor to become ready..."

API_URL_PREFIX="${HARBOR_URL}/api"
if [[ "${HARBOR_VERSION}" =~ ^v2 ]]; then
    API_URL_PREFIX="${HARBOR_URL}/api/v2.0"
fi
echo "[PREPARE] Harbor API_URL_PREFIX: ${API_URL_PREFIX}"

until [[ $(curl -s --fail "${API_URL_PREFIX}"/health | jq '.status' 2>/dev/null) == "\"healthy\"" ]]; do
    printf '.'
    sleep 5
done; echo "[PREPARE] Harbor is ready ..."

echo "[PREPARE] Creating public project in Harbor..."
curl -u "${HARBOR_USERNAME}:${HARBOR_PASSWORD}" "${API_URL_PREFIX}/projects" -H "Content-Type: application/json" -X POST --data-raw '{"project_name":"public"}'

echo -e "[DONE] Harbor installation finished successfully. Visit at ${HARBOR_URL}"
