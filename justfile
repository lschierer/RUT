export PATH := "./node_modules/.bin:" + env_var('PATH')
set dotenv-load
set dotenv-filename	:= ".env.deploy"

[working-directory: 'packages/frontend']
find-perl-deps:
  find . \( -name '*.pm' -o -name '*.pl' \)  -exec grep use {} \; | tr -s '[:blank:]' ' ' | awk '{$1=$1};1' | sort -u

install:
  pnpm install -r
  ./packages/luke/bin/perldeps.sh
  cd ./packages/frontend && perl Build.PL && ./Build installdeps

[working-directory: 'packages/luke']
copy-luke-content: install
  ./bin/setup.sh

content-setup: install copy-luke-content
  cd ./packages/archives && ./bin/exploder.sh


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
  cd ../frontend perl Build.PL && ./Build manifest
  pulumi up

[working-directory: 'packages/infrastructure']
sync-frontend: install copy-luke-content
  ./local-sync.sh

quickdev:
    watchexec -w bin -w lib -w ../PAGI-WebServer/lib -w templates -w public/css -w public/js -w share/pages -r ./bin/server.pl