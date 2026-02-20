#!/bin/bash
set -e

# Build Perl module
perl Build.PL
./Build installdeps --cpan_client 'cpanm -nq --with-recommends'
./Build manifest
./Build

# Install Node dependencies
pnpm install

# Extract archived user directories
mkdir -p packages/archives/extracted
cd packages/archives
for tarball in *.tar.gz; do
  username="${tarball%.tar.gz}"
  mkdir -p "extracted/${username}"
  tar -xzf "${tarball}" -C "extracted/${username}" --strip-components=1
done
# Ensure www-data can read the extracted files
chmod -R a+rX extracted/
cd ../..
