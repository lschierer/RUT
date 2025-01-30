install:
  pnpm install

[working-directory: 'packages/luke']
copy-luke-content: install
  rsync -a ./ --exclude=*.mdwn  --exclude=*.json --exclude=convert.sh --exclude=.gitignore  --exclude=bin ../greenwood/src/pages/luke/

content-setup: install copy-luke-content  history
  find packages -type d -maxdepth 1 -mindepth 1 | grep -v greenwood | cut -d '/' -f 2 | gsed -E 's/(.*)/"\1",/' | gsed -E '1iconst users = [' | gsed -E '$a];' > packages/greenwood/src/lib/users.ts
  echo "export default users;" >> packages/greenwood/src/lib/users.ts

[working-directory: 'packages/greenwood']
dev: content-setup
  pnpm dev

clean:
  rm -rf packages/greenwood/src/pages
  git restore packages/greenwood/src/pages

[working-directory: 'packages/luke']
history:
  ./bin/history.sh
