#!/bin/bash

TARGETDIR='../frontend/share/home/luke/';

rsync -vkmgoprt --delete --partial ./node_modules "$TARGETDIR/";

rm -rf build-output;
pnpm build:prod

find build-output -type d -mindepth 1 -maxdepth 1 | while read -r line; do
  rsync -vkmgoprt --delete --partial "$line" "$TARGETDIR/";
done
