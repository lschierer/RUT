[working-directory: 'packages/luke']
copy-luke-content:
  rsync -a ./ --exclude=*.mdwn  --exclude=*.json --exclude=convert.sh --exclude=.gitignore ../greenwood/src/pages/luke/

content-setup: copy-luke-content
  find packages -type d -maxdepth 1 -mindepth 1 | grep -v greenwood | cut -d '/' -f 2 | gsed -E 's/(.*)/"\1",/' | gsed -E '1iconst users = [' | gsed -E '$a];' > packages/greenwood/src/lib/users.ts
  echo "export default users;" >> packages/greenwood/src/lib/users.ts


[working-directory: 'packages/greenwood']
dev: content-setup
  pnpm dev

clean:
  rm -rf packages/greenwood/src/pages
  git restore packages/greenwood/src/pages
