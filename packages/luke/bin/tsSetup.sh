#!/bin/bash

TARGETDIR='../frontend/share/home/luke/';

rsync -vkmgoprt --delete --partial ./node_modules "$TARGETDIR/";

rm -rf dist;
pnpm build:prod

find dist -type d -mindepth 1 -maxdepth 1 | while read -r line; do
  rsync -vkmgoprt --delete --partial "$line" "$TARGETDIR/";
done
