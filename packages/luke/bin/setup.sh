#!/bin/bash

if test -d "$PWD/frontend/share/home/luke/"; then
  rm -rf "$PWD/frontend/share/home/luke/";
fi

./bin/process.pl || exit 2

./bin/tsSetup.sh || exit 1
