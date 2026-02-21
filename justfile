export PATH := "./node_modules/.bin:" + env_var('PATH')
set dotenv-load
set dotenv-filename	:= ".env.deploy"

tidy:
  find packages/luke/bin -name '*.pl' -exec perltidy -b -pro=.perltidyrc {} \;
  find packages/luke/lib -name '*.pm' -exec perltidy -b -pro=.perltidyrc {} \;
  find lib -name '*.pm' -exec perltidy -b -pro=.perltidyrc {} \;
  #find t -name '*.t' -exec perltidy -b -pro=.perltidyrc {} \;
  perltidy -b -pro=.perltidyrc Build.PL
  perltidy -b -pro=.perltidyrc bin/server.pl
  find . -name '*.bak' -delete

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

build: install build-luke-content
  mkdir -p public/css
  mkdir -p public/js
  cd ./packages/archives 
  # todo: do something with the archived stuff


clean:
  # todo

linkcheck:
  pnpm exec blc -e -f -r http://localhost:3000

check:
  #!/usr/bin/env -S parallel --shebang --ungroup --jobs 2
  just dev && echo dev task done
  sleep 10 && just linkcheck && echo "success"


deploy-dev: build-luke-content
    pnpm cdk --profile personal acknowledge 34892 
    MODE='dev' pnpm cdk --profile personal deploy

deploy-test: build-luke-content
    pnpm cdk --profile personal acknowledge 34892 
    MODE='test' pnpm cdk --profile personal deploy

deploy-prod: build-luke-content
    pnpm cdk --profile personal acknowledge 34892 
    MODE='prod' pnpm cdk --profile personal deploy


quickdev:
    watchexec -w bin -w lib -w ../PAGI-WebServer/lib -w templates -w public/css -w public/js -w packages/luke/build-output -r ./bin/server.pl