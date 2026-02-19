#!/bin/bash
set -e

# Build Perl module
perl Build.PL
./Build installdeps --cpan_client 'cpanm -nq --with-recommends'
./Build manifest
./Build

# Install Node dependencies and build CSS/TypeScript
pnpm install
pnpm build

# Build luke content (ikiwiki conversion, manifests, archives, calendar, recent changes)
cd packages/luke
./bin/build_luke.pl
cd ../..

# Build luke CSS assets
cd packages/luke
pnpm build:prod
cd ../..

# Extract archived user directories
mkdir -p packages/archives/extracted
cd packages/archives
for tarball in *.tar.gz; do
  username="${tarball%.tar.gz}"
  mkdir -p "extracted/${username}"
  tar -xzf "${tarball}" -C "extracted/${username}"
done
cd ../..
