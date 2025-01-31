#!/bin/bash -x

OUTFILE='../greenwood/src/lib/tags.ts'

echo "const tagNames = [" > $OUTFILE

find log  -iname '*.md' -exec grep -A 3 tags {} \;| \
  grep -- ' - ' | cut -d '-' -f 2 | tr -d [:blank:] | \
  sort | uniq -c | gsed -E -e 's|^\s*([[:digit:]]+)\s+(\w+)\s*$|{"\2": \1 },|' >> $OUTFILE

echo "];" >> $OUTFILE

echo "export default tagNames;" >> $OUTFILE
