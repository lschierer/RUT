#!/bin/bash
set -e

# Build Perl module
perl Build.PL
./Build installdeps --cpan_client 'cpanm -nq --with-recommends'
./Build manifest
./Build

# Install Node dependencies
pnpm install
