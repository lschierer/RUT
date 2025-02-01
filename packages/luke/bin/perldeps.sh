#!/bin/bash -x

deps=$(cat <<-EOF
Array::Merge::Unique
Git::Wrapper
List::AllUtils
Object::Pad
Path::Tiny
Try::Tiny
Unicode::UTF8
HTML::FormatMarkdown
EOF
)

echo "$deps" | while read -r line  ; do

  cpanm -n "$line"

done
