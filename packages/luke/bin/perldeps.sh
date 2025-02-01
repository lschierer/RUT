#!/bin/bash -x

deps=$(cat <<-EOF
Git::Repository
Object::Pad
Path::Tiny
EOF
)

echo "$deps" | while read -r line  ; do

  cpanm -n "$line"

done
