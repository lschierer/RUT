#!/bin/bash

find . -iname '*.mdwn' -print0 | while IFS= read -r -d '' mdwn;
do
    thisdir=$(dirname $mdwn)
    echo "Converting $mdwn"
    base=$(basename $mdwn .mdwn)
    md=$base.md

    # Get the title, date, and tags in the new formats
    title=$(grep '\[\[\!meta' science/Trust.mdwn | grep title | tr -s '[:blank:]' | cut -d ' ' -f 2- | gsed -e 's/title="\(.*\)"\]\]/\1/;');
    date=$(grep '\[\[\!meta' $mdwn | grep date | tr -s '[:blank:]' | cut -d ' ' -f 2- | gsed -e 's/date=\(.*\)\]\]/\1/;')
    tags=$(grep '\[\[\!tag' $mdwn | gsed -e 's/\[\[!tag \(.*\)\]\]/\1/; s/ /", "/g; s/^/  - /; ')

    # If tags are blank, mark them as "untagged".
    if [[ -z "$tags" ]]; then
        tags='untagged'
    fi

    # Insert the new tags into the new .md files
    echo -e "---\ntitle: $title\ndate: $date\ntags:\n$tags\n---" > $thisdir/$md

    # Strip the old tags from the mdwn sources, adding the result to the md files
    # Also rewrite images while we're at it.
    gsed -E -e "/^\[\[!meta\s+title.*$/d" \
        -e "/^\[\[!meta\s+date.*$/d" \
        -e "/^\[\[!meta guid.*$/d" \
        -e "/^\[\[!tag.*$/d" \
        -e s'/\[\[\!img\s+(\S*) .* alt=(".*")]]/![\2](\1)/g' \
        $mdwn \
      >> $thisdir/$md
done
