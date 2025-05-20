#!/bin/bash

eval "$(mise activate bash)"

mise install perl@5.40
mise install node@lts
mise install pnpm@10
mise install just@latest
mise use perl@5.40
mise use node@lts
mise use pnpm@10
mise use just@latest

./bin/process.pl || exit 2

./bin/tsSetup.sh || exit 1
