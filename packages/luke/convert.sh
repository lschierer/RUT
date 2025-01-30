#!/bin/bash

find . -d -iname '*.mdwn' -print0 | while IFS= read -r -d '' mdwn;
do
  if [ $mdwn == "./index.mdwn" ]; then
    continue;
  fi
    # initialize variables to empty strings to ensure no carry over from previous runs.
    thisdir=""
    base=""
    md=""
    title=""
    date=""
    tags=""

    echo "Converting $mdwn"
    thisdir=$(dirname $mdwn)
    base=$(basename $mdwn .mdwn)
    md=$base.md

    # Get the title, date, and tags in the new formats
    title=$(grep '\[\[\!meta' $mdwn | grep title | tr -s '[:blank:]' | cut -d ' ' -f 2- | gsed -e 's/title="\(.*\)"\]\]/\1/;');
    tags=$(grep '\[\[\!tag' $mdwn | gsed -e 's/\[\[!tag \(.*\)\]\]/\1/; s/\(\S+\) /"\1, "/g; /uncategorized/d; s/^/  - /; ')

    if [[ -z "$title" ]]; then
      title=$(echo $base | tr '_' ' ')
    fi

    date=$(grep '\[\[\!meta' $mdwn | grep update | tr -s '[:blank:]' | cut -d ' ' -f 2- | gsed -e 's/date="\(.*\)"\]\]/\1/;')

    if [[ -z "$date" ]]; then
      date=$(grep '\[\[\!meta' $mdwn | grep date | tr -s '[:blank:]' | cut -d ' ' -f 2- | gsed -e 's/date="\(.*\)"\]\]/\1/;')
    else
      date=$( git log --diff-filter=A --follow --format=%cd -- $mdwn | tail -1 )
    fi

    # Insert the new tags into the new .md files
    echo -e "---\n" > $thisdir/$md
    echo -e "title: $title" >> $thisdir/$md
    echo -e "date: $date" >> $thisdir/$md

    if [[ ! -z $tags ]]; then
      echo -e "tags:" >> $thisdir/$md
      echo -e "$tags" >> $thisdir/$md
    fi
    echo -e "layout: rut" >> $thisdir/$md
    echo -e "---\n" >> $thisdir/$md

    # Strip the old tags from the mdwn sources, adding the result to the md files
    # Also rewrite images while we're at it.
    gsed -E -e "/^\[\[!meta\s+title.*$/d" \
        -e "/^\[\[!meta\s+date.*$/d" \
        -e "/^\[\[!meta guid.*$/d" \
        -e "/^\[\[!meta\s+HTML_LANG_CODE.*$/d" \
        -e "/^\[\[!tag.*$/d" \
        -e s'/\[\[\!img\s+(\S*) .* alt=(".*")]]/![\2](\1)/g' \
        $mdwn \
      >> $thisdir/$md
done
