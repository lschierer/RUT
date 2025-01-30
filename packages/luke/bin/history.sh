#!/bin/bash

FINAL='../greenwood/src/lib/commitHistory.ts'

OUTPATH=`mktemp`

echo -n "const commits = " > $FINAL
echo "[" > $OUTPATH

git log --oneline --full-history  --color=never  --decorate=short  --grep "^build: " --grep "calendar update" --invert-grep  -- ../.. ':!packages/greenwood' ':**/*.md(wn)?' | \
egrep -v '(00521e38|62e2825d|d642ed21|abdb7103|695cb529|77e74db5|eeb8a0d2|e22afbdc|c0ca2c99|b5290af8|d4b572c5|6dfadc75|0c5b42c4|8c987f5f|eb1d753e)' |\
head -n 20 | cut -d ' ' -f 1 |\
while read -r log; do
  echo "{" >> $OUTPATH
  echo -n '"id":' >> $OUTPATH
  git log --format=%H -n 1 $log | gsed -E -e 's/(.*)/"\1",/' >> $OUTPATH
  #git show --oneline --color=never --stat $log >
  echo "\"message\": [" >>$OUTPATH
  git log --format=%B -n 1 $log | gsed -E -e 's/(.*)/"\1",/' >> $OUTPATH
  echo "]," >> $OUTPATH
  echo -n "\"date\": " >> $OUTPATH
  git log --format=%at -n 1 $log  | gsed -E -e 's/(.*)/"\1",/' >> $OUTPATH
  echo "\"files\": [" >> $OUTPATH
  git show  --pretty=reference --color=never --stat=1000  $log | tail -n +3 | ghead -n -1 | cut -d '|' -f 1 | cut -d ' ' -f 2 | gsed -E -e 's/^(.*)$/"\1",/' >> $OUTPATH
  echo "]," >> $OUTPATH
  echo "}," >> $OUTPATH
done
echo "]" >> $OUTPATH

pnpm exec json5 $OUTPATH | jq "." >> $FINAL || echo $OUTPATH

echo "" >> $FINAL
echo "export default commits;" >> $FINAL
