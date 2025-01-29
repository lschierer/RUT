content-setup:
  find packages -type d -maxdepth 1 -mindepth 1 | grep -v greenwood | cut -d '/' -f 2 | gsed -E 's/(.*)/"\1",/' | gsed -E '1iconst users = [' | gsed -E '$a];' > packages/greenwood/src/lib/users.ts
  echo "export default users;" >> packages/greenwood/src/lib/users.ts
