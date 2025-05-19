export PATH := "./node_modules/.bin:" + env_var('PATH')
set dotenv-load
set dotenv-filename	:= ".env.deploy"

install:
  pnpm install -r
  ./packages/luke/bin/perldeps.sh
  cd ./packages/frontend && ./Build installdeps

[working-directory: 'packages/luke']
copy-luke-content: install
  ./bin/setup.sh

content-setup: install copy-luke-content
  cd ./packages/archives && ./bin/exploder.sh


# Start the development container in the background with a consistent name
serve-start:
  #!/usr/bin/env bash
  echo "Starting development container..."
  CONTAINER_ENGINE=$(command -v podman || command -v docker)
  IMAGE_ID=$(${CONTAINER_ENGINE} build -q -f packages/infrastructure/Dockerfile .)
  ${CONTAINER_ENGINE} run --rm -d --name schierer-dev -p 3000:3000 \
    -v "$PWD/packages/frontend:/opt/schierer.org:Z" \
    ${IMAGE_ID} | tee .serve-container-id
  echo "Development server running at http://localhost:3000"
  echo "Container ID saved to .serve-container-id"

# Stop the development container
serve-stop:
  #!/usr/bin/env bash
  echo "Stopping development container..."
  CONTAINER_ENGINE=$(command -v podman || command -v docker)
  if [ -f .serve-container-id ]; then \
    ${CONTAINER_ENGINE} stop $(cat .serve-container-id) 2>/dev/null || true; \
    rm -f .serve-container-id; \
    echo "Development container stopped"; \
  else \
    echo "No container ID found. Trying to stop by name..."; \
    $${CONTAINER_ENGINE} stop schierer-dev 2>/dev/null || true; \
    echo "Container stopped if it existed"; \
  fi

# Restart the development container
serve-restart: serve-stop serve-start
  @echo "Development container restarted"

# Show logs from the development container
serve-logs:
  #!/usr/bin/env bash
  CONTAINER_ENGINE=$(command -v podman || command -v docker)
  if [ -f .serve-container-id ]; then \
    ${CONTAINER_ENGINE} logs -f $(cat .serve-container-id); \
  else \
    ${CONTAINER_ENGINE} logs -f schierer-dev 2>/dev/null || \
    echo "No running container found"; \
  fi

[working-directory: 'packages/frontend']
dev: install content-setup
  morbo -m development -v -w lib/ -w schierer.org.pl -w schierer-base.yml -w share/ -w templates/ ./schierer.org.pl

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

sync-frontend:
  ./packages/infrastructure/bin/s3-sync-with-s3ignore.sh ./packages/frontend s3://$SOURCE_BUCKET

frontend-image: install build-frontend
  #!/usr/bin/env bash
  CONTAINER_ENGINE=$(command -v podman || command -v docker)
  IMAGE_ID=$(${CONTAINER_ENGINE} build -q -f packages/infrastructure/Dockerfile .)
  echo ${IMAGE_ID}

[working-directory: 'packages/frontend']
build-frontend: install content-setup
  cpanm --notest Module::Build
  cpanm --notest utf8::all
  cpanm --notest --installdeps .
  perl Build.PL
  ./Build


build:  content-setup frontend-image

[working-directory: 'packages/infrastructure']
deploy: install content-setup build-frontend
  pulumi up

[working-directory: 'packages/frontend']
find-perl-deps:
  find . \( -name '*.pm' -o -name '*.pl' \)  -exec grep use {} \; | tr -s '[:blank:]' ' ' | awk '{$1=$1};1' | sort -u
