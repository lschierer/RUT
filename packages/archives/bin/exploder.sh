#!/usr/bin/env bash

export TARGET="$PWD/../frontend/share/home/";

find "$PWD" -name '*.tar.gz' | while read -r archive; do
  export ARCHIVEBASE=`basename "$archive" .tar.gz`;

  if ! [ -d "$PWD/../$ARCHIVEBASE" ]; then
    if  [ -d "$TARGET/$ARCHIVEBASE" ]; then
      rm -rf "$TARGET/$ARCHIVEBASE"
    fi
    tar -zxf "$archive" -C "$TARGET/";
  fi
done
