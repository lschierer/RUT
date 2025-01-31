#!/bin/bash

find log -depth -iname '*.mdwn' | sort | while read -r mdwn;
do
  if [ $mdwn == "log/index.mdwn" ]; then
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
    title=$(grep '\[\[\!meta' $mdwn | grep title | tr -s [:blank:] | cut -d ' ' -f 2- | \
      gsed -E -e 's|^(\s)*title="(.*)".*$|\2|' \
    );
    tags=$(grep '\[\[\!tag' $mdwn | \
      gsed -e 's/\[\[!tag \(.*\)\]\]/\1/; s/\(\S+\) /"\1, "/g; /uncategorized/d; s/^/  - /; '
      );

    if [[ -z "$title" ]]; then
      title=$(echo $base | tr '_' ' ')
    fi
    if [[ "$title" == "index" ]]; then
      title=$(echo $thisdir | rev | cut -d '/' -f 1 | rev)
    fi


    date=$(grep '\[\[\!meta' $mdwn | grep 'updated=' | tr -s '[:blank:]' | cut -d ' ' -f 2- |\
      gsed -E -e 's|^(\s)*updated="(.*)"\]\](\s)*$|\2|' \
    )

    if [[ -z "$date" ]]; then
      date=$(grep '\[\[\!meta' $mdwn | grep 'date=' | tr -s '[:blank:]' | cut -d ' ' -f 2- |
        gsed -E -e 's|^(\s)*date="(.*)"\]\](\s)*$|\2|' \
      )
    fi
    if [[ -z "$date" ]]; then
      date=$( git log --diff-filter=A --follow --format=%cd --date=iso8601 -- $mdwn | tail -1 )
    fi

    # Insert the new tags into the new .md files
    echo -e "---\n" > $thisdir/$md
    echo -e "title: \"$title\"" >> $thisdir/$md
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
        -e "/^\[\[!meta\s+updated.*$/d" \
        -e "/^\[\[!meta guid.*$/d" \
        -e "/^\[\[!meta\s+HTML_LANG_CODE.*$/d" \
        -e "/^\[\[!tag.*$/d" \
        -e s'/\[\[\!img\s+(\S*) .* alt=(".*")]]/![\2](\1)/g' \
        -e 's/^\[\[(.*)\|(.*)\]\]$/[\1](\2)/' \
        -e 's/(\s)+\[\[(.*)\|(.*)\]\]$/\1[\2](\3)/' \
        -e 's/(\s)+\[\[(.*)\|(.*)\]\](\s)+/\1[\2](\3)\4/' \
        $mdwn \
      >> $thisdir/$md
done
