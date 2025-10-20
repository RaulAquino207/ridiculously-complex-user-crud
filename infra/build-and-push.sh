#!/usr/bin/env bash
###########################################################
# Simple Docker Hub build-and-push helper for this project.
#
# Usage:
#   DOCKERHUB_USERNAME=youruser DOCKERHUB_TOKEN=xxxxx \
#   ./infra/build-and-push.sh --name ridiculously-complex-user-crud --tag prod
#
# Flags:
#   -n, --name           Image name (repo name, sem namespace)
#   -t, --tag            Image tag (default: latest ou GIT SHA)
#   -c, --context        Docker build context (default: .)
#   -f, --file           Dockerfile path (default: Dockerfile)
#       --platform       Optional Docker buildx platform (e.g., linux/amd64)
#       --target         Optional Dockerfile target
#       --build-arg      Optional build-arg (repeatable): --build-arg KEY=VALUE
###########################################################
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

bold() { printf "\033[1m%s\033[0m\n" "$*"; }
note() { printf "[info] %s\n" "$*"; }
warn() { printf "\033[33m[warn]\033[0m %s\n" "$*"; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "[error] Missing required command: $1"; exit 1; }; }

usage() {
  cat <<'USAGE'
Build and push a Docker image to Docker Hub.

Required:
  --name     image/repo name (sem namespace; namespace vem de $DOCKERHUB_NAMESPACE ou $DOCKERHUB_USERNAME)

Optional:
  --tag <tag>                 Default: GIT_SHA (se disponível) ou 'latest'
  --context <path>            Default: .
  --file <Dockerfile>         Default: Dockerfile
  --platform <arch/os>        Exemplo: linux/amd64
  --target <stage>            Dockerfile target stage
  --build-arg KEY=VALUE       Repetível

Docker Hub env:
  DOCKERHUB_USERNAME (obrigatório)
  DOCKERHUB_TOKEN    (recomendado para login automático)
  DOCKERHUB_NAMESPACE (opcional; padrão = DOCKERHUB_USERNAME)

Exemplo:
  DOCKERHUB_USERNAME=meuuser DOCKERHUB_TOKEN=*** \
  ./infra/build-and-push.sh --name ridiculously-complex-user-crud --tag prod
USAGE
}

IMAGE_NAME=""
TAG=""
CONTEXT="."
DOCKERFILE="Dockerfile"
PLATFORM=""
TARGET_STAGE=""
BUILD_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--name)
      IMAGE_NAME="$2"; shift 2 ;;
    -t|--tag)
      TAG="$2"; shift 2 ;;
    -c|--context)
      CONTEXT="$2"; shift 2 ;;
    -f|--file)
      DOCKERFILE="$2"; shift 2 ;;
    --platform)
      PLATFORM="$2"; shift 2 ;;
    --target)
      TARGET_STAGE="$2"; shift 2 ;;
    --build-arg)
      BUILD_ARGS+=("--build-arg" "$2"); shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      err "Unknown argument: $1"; usage; exit 1 ;;
  esac
done

need_cmd docker

if [[ -z "${IMAGE_NAME}" ]]; then
  err "--name is required"
  usage
  exit 1
fi

# Default tag
if [[ -z "${TAG}" ]]; then
  if command -v git >/dev/null 2>&1 && git -C "$REPO_ROOT" rev-parse --short HEAD >/dev/null 2>&1; then
    TAG="$(git -C "$REPO_ROOT" rev-parse --short HEAD)"
  else
    TAG="latest"
  fi
fi

bold "Building image '${IMAGE_NAME}:${TAG}' (Docker Hub)"

# Compose docker build command
BUILD_CMD=(docker build -t "${IMAGE_NAME}:${TAG}" -f "$DOCKERFILE")
[[ -n "$PLATFORM" ]] && BUILD_CMD+=(--platform "$PLATFORM")
[[ -n "$TARGET_STAGE" ]] && BUILD_CMD+=(--target "$TARGET_STAGE")
if [[ ${#BUILD_ARGS[@]} -gt 0 ]]; then
  BUILD_CMD+=("${BUILD_ARGS[@]}")
fi
BUILD_CMD+=("$CONTEXT")

note "Running: ${BUILD_CMD[*]}"
"${BUILD_CMD[@]}"

# Docker Hub login
: "${DOCKERHUB_USERNAME:?Set DOCKERHUB_USERNAME for Docker Hub push}"
DOCKERHUB_NAMESPACE="${DOCKERHUB_NAMESPACE:-$DOCKERHUB_USERNAME}"

if ! docker system info 2>/dev/null | grep -q "Username: ${DOCKERHUB_USERNAME}"; then
  if [[ -n "${DOCKERHUB_TOKEN:-}" ]]; then
    echo "$DOCKERHUB_TOKEN" | docker login --username "$DOCKERHUB_USERNAME" --password-stdin
  else
    warn "DOCKERHUB_TOKEN not set. Falling back to interactive 'docker login'."
    docker login --username "$DOCKERHUB_USERNAME"
  fi
fi

if [[ "$IMAGE_NAME" == */* ]]; then
  REMOTE_IMAGE="$IMAGE_NAME:$TAG"
else
  REMOTE_IMAGE="${DOCKERHUB_NAMESPACE}/${IMAGE_NAME}:$TAG"
fi

note "Tagging ${IMAGE_NAME}:${TAG} -> ${REMOTE_IMAGE}"
docker tag "${IMAGE_NAME}:${TAG}" "$REMOTE_IMAGE"
note "Pushing ${REMOTE_IMAGE}"
docker push "$REMOTE_IMAGE"
bold "Pushed Docker Hub image: ${REMOTE_IMAGE}"
