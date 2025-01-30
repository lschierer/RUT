#!/bin/bash
git filter-repo --analyze;
git filter-repo --path-glob "**/*.md" --path-glob "**/*.mdwn"
git filter-repo --path packages/greenwood --invert-paths
git log --oneline --exclude="00521e38*" --full-history  --color=never  --decorate=short  --grep "^build: " --invert-grep  -- ../.. ':!packages/greenwood' ':**/*.md(wn)?' | \
while read -r log; do

  echo "$log"

done
