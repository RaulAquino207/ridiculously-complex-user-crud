# Infra scripts

This folder contains scripts to build and push the Docker image of this project to Docker Hub.

## build-and-push.sh

Builds a Docker image and pushes to Docker Hub.

Prerequisites:
- Docker installed
- Optional: git (to auto-tag with the current commit SHA)

Usage examples:

```sh
DOCKERHUB_USERNAME=youruser DOCKERHUB_TOKEN=*** \
./infra/build-and-push.sh \
  --name ridiculously-complex-user-crud \
  --tag prod
```
It will push to: docker.io/youruser/ridiculously-complex-user-crud:prod

### Options
- `--context` (default `.`) build context
- `--file` (default `Dockerfile`) Dockerfile path
- `--platform` (e.g. `linux/amd64`)
- `--target` Dockerfile target stage
- `--build-arg KEY=VALUE` (repeatable)

### Tips
- Use different tags for environments (e.g., `prod`, `test`, or a Git SHA).
- For CI, export credentials as environment secrets and call this script in a pipeline.
