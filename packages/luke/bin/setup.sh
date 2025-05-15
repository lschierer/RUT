#!/usr/bin/env bash


./bin/process.pl || exit 2

./bin/tsSetup.sh || exit 1
