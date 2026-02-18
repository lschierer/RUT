export PATH := "./node_modules/.bin:" + env_var('PATH')
set dotenv-load
set dotenv-filename	:= ".env.deploy"

[working-directory: 'packages/frontend']
find-perl-deps:
  find . \( -name '*.pm' -o -name '*.pl' \)  -exec grep use {} \; | tr -s '[:blank:]' ' ' | awk '{$1=$1};1' | sort -u

install:
  pnpm install -r
  perl Build.PL
  ./Build installdeps

[working-directory: 'packages/luke']
build-luke-content: install
  #!/usr/bin/env bash
  set -euo pipefail
  # Convert ikiwiki markdown and build manifests
  ./bin/build_luke.pl
  # Build TypeScript/CSS assets
  pnpm build:prod

content-setup: install build-luke-content
  mkdir -p public/css
  mkdir -p public/js
  cd ./packages/archives 
  # todo: do something with the archived stuff


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


deploy: install content-setup 
  # cdk stuff goes here

quickdev:
    watchexec -w bin -w lib -w ../PAGI-WebServer/lib -w templates -w public/css -w public/js -w packages/luke/dist -r ./bin/server.pl