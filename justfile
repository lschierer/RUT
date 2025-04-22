export PATH := "./node_modules/.bin:" + env_var('PATH')

install:
  pnpm install
  ./packages/luke/bin/perldeps.sh

[working-directory: 'packages/luke']
copy-luke-content: install
  ./bin/process.pl

content-setup: install copy-luke-content
  find packages -type d -maxdepth 1 -mindepth 1 | grep -v greenwood | cut -d '/' -f 2 | gsed -E 's/(.*)/"\1",/' | gsed -E '1iconst users = [' | gsed -E '$a];' > packages/greenwood/src/lib/users.ts
  echo "export default users;" >> packages/greenwood/src/lib/users.ts


# Start the development container in the background with a consistent name
dev-start:
  @echo "Starting development container..."
  @CONTAINER_ENGINE=$$(command -v podman || command -v docker)
  @IMAGE_ID=$$($${CONTAINER_ENGINE} build -q -f packages/infrastructure/Dockerfile .)
  @$${CONTAINER_ENGINE} run --rm -d --name schierer-dev -p 3000:3000 \
    -v "$$PWD/packages/frontend:/opt/schierer.org:Z" \
    $${IMAGE_ID} | tee .dev-container-id
  @echo "Development server running at http://localhost:3000"
  @echo "Container ID saved to .dev-container-id"

# Stop the development container
dev-stop:
  @echo "Stopping development container..."
  @CONTAINER_ENGINE=$$(command -v podman || command -v docker)
  @if [ -f .dev-container-id ]; then \
    $${CONTAINER_ENGINE} stop $$(cat .dev-container-id) 2>/dev/null || true; \
    rm -f .dev-container-id; \
    echo "Development container stopped"; \
  else \
    echo "No container ID found. Trying to stop by name..."; \
    $${CONTAINER_ENGINE} stop schierer-dev 2>/dev/null || true; \
    echo "Container stopped if it existed"; \
  fi

# Restart the development container
dev-restart: dev-stop dev-start
  @echo "Development container restarted"

# Show logs from the development container
dev-logs:
  @CONTAINER_ENGINE=$$(command -v podman || command -v docker)
  @if [ -f .dev-container-id ]; then \
    $${CONTAINER_ENGINE} logs -f $$(cat .dev-container-id); \
  else \
    $${CONTAINER_ENGINE} logs -f schierer-dev 2>/dev/null || \
    echo "No running container found"; \
  fi

dev: dev-stop dev-start

clean:
  rm -rf packages/greenwood/src/pages
  git restore packages/greenwood/src/pages
  rm -rf packages/greenwood/src/assets/log
  git restore packages/greenwood/src/assets

linkcheck:
  pnpm exec blc -e -f -r http://localhost:3000

check:
  #!/usr/bin/env -S parallel --shebang --ungroup --jobs 2
  just dev && echo dev task done
  sleep 10 && just linkcheck && echo "success"

[working-directory: 'packages/greenwood']
build-greenwood: install content-setup
  pnpm build

build: build-greenwood

[working-directory: 'packages/infrastructure']
deploy:
  pulumi up
