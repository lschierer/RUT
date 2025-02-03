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

[working-directory: 'packages/greenwood']
dev: content-setup
  pnpm dev

clean:
  rm -rf packages/greenwood/src/pages
  git restore packages/greenwood/src/pages
  rm -rf packages/greenwood/src/assets/log
  git restore packages/greenwood/src/assets

linkcheck:
  pnpm exec blc -e -f -r http://localhost:1984

check:
  #!/usr/bin/env -S parallel --shebang --ungroup --jobs 2
  just dev && echo dev task done
  sleep 10 && just linkcheck && echo "success"

[working-directory: 'packages/greenwood']
build-greenwood: install content-setup
  pnpm build

build: build-greenwood
