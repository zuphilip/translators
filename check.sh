#!/bin/bash
#
# LICENSE: Public Domain

exitcode=0

echo -e "\nCHECK that all translator have a translatorID..."
HAVEID=$(grep -c '"translatorID"' *.js | awk -F: '$2!="1" {print $1,"found",$2,"translatorID"}')
if [[ -n "$HAVEID" ]];then
  echo "Error: no translatorID or multiple translatorIDs"
  echo "$HAVEID"
  exitcode=1
fi
echo "...DONE"


echo -e "\nCHECK that all translatorIDs are unique..."
USEDID=$(grep '"translatorID"' *.js | cut -d: -f3)
DELETEDID=$(tail -n +3 deleted.txt | cut -d# -f1)
NODUPLICATE=$(echo -e "${USEDID}\n${DELETEDID}" | sed 's/[", ]//g' | sort | uniq -d)
if [[ -n "$NODUPLICATE" ]];then
  echo "Error: duplicate translatorID found"
  echo "$NODUPLICATE"
  exitcode=1
fi
echo "...DONE"


echo -e "\nCHECK on all translators (files not executable, file ending, deprecated JS for each)..."
for file in *.js; do
  executable=$(stat -c "%A" "$file" | grep x )
  if [[ -n "$executable"  ]];then
    echo "Error: $file is executable, but should not"
    exitcode=1
  fi
  dosfilending=$(dos2unix < "$file" | cmp -s - "$file")
  if [[ -n "$dosfilending" ]];then
    echo "Error: wrong file ending in $file"
    exitcode=1
  fi
  foreach=$(grep -E 'for each *\(' *.js)
  if [[ -n "$foreach" ]];then
    echo "Error: Deprecated JavaScript for each is used in $file"
    exitcode=1
  fi
done
echo "...DONE"


# The Internal Field Separator (IFS) is used for word splitting.
# Change default value <space><tab><newline> to newline only.
IFS=$'\n' 
echo -e "\nCHECK added/modified files (AGPL license, JS parsable, JSON parsable)..."
#list all added, copied or modified files compared to $TRAVIS_COMMIT_RANGE.
STAGED=$(git diff --name-only --diff-filter=ACM "$TRAVIS_COMMIT_RANGE" -- '*.js*')
for f in $(echo -e "$STAGED"); do
  echo "   checking $f now..."
  #check for AGPL license text
  noagpl=$(grep -L "GNU Affero General Public License" "$f")
  if [[ -n "$noagpl" ]];then
    echo "Warning: AGPL license text not found"
    #This is only a warning and not an error currently.
  fi
  # check that JSON part is parsable
  # e.g. https://github.com/zotero/translators/commit/a150383352caebb892720098175dbc958149be43
  jsonpart=$(sed -ne  '1,/^}/p' "$f")
  jsonerror=$(echo "$jsonpart" | jsonlint)
  #Check the exit code of the last command, which is saved in the variable $?
  if [[ "$?" -gt 0  ]];then
    echo "ERROR: Parse error in JSON part of $f"
    echo "$jsonerror"
    exitcode=1
  fi
  # check that JavaScript part is parsable
  # cf. https://github.com/UB-Mannheim/zotkat/blob/master/jshint.sh
  sed '1,/^}/ s/.*//' "$f" \
  | sed 's,/\*\* BEGIN TEST,\n\0,' \
  | sed '/BEGIN TEST/,$ d' \
  | jshint --filename="$f" - 
done;
echo "...DONE"


# echo -e "\nCHECK deleted files..."
# #list all commits where files are deleted
# DELCOMMITS=$(git --no-pager log --diff-filter=D --pretty="%H")

# DELETEDFILES=$(git diff --name-only --diff-filter=D "$TRAVIS_COMMIT_RANGE" -- '*.js*')
# DIFF=$(git diff "$TRAVIS_COMMIT_RANGE" -- 'deleted.txt')

# #$TRAVIS_COMMIT_RANGE = The range of commits that were included in the push or pull request
# #####################
# first=true
# for c in "$TRAVIS_COMMIT_RANGE"; do
  # echo "$c"
  # #check that a JavaScript file (i.e. a translator) is deleted
  # jsdeleted=$(git show --name-status $c | grep ^D.*\.js | sed 's/^D\s*//')
  # if [[ -n "$jsdeleted" ]];then
    # if [ "$first" = true ];then
      # before=$(git log -n 2 $c --pretty=format:"%H" | tail -1)
      # # number increased
      # oldrevision=$(git show "$before":deleted.txt | awk 'NR<2 { print $1 }')
      # newrevision=$(awk 'NR<2 { print $1 }' deleted.txt)
      # if [ $newrevision -ne $(($oldrevision + 1)) ];then
        # echo "Error: translators are deleted but the number in deleted.txt is not increased by 1 (compared to commit $before)."
        # echo "$newrevision (newrevision) =/= $oldrevision (oldrevision) + 1"
        # exitcode=1
      # fi
      # first=false
    # fi
    
    # # all deleted translator ids must be listed in deleted.txt
    # #echo $jsdeleted
    # #git show "$c" --diff-filter=D | grep '"translatorID"'
    # delids=$(git show "$c" --diff-filter=D | grep '"translatorID"' | awk -F: '{print $2}' | sed 's/[", ]//g')
    # listed=$(echo $delids | xargs -i grep -c {} deleted.txt | awk '$1!="1" {print "Error"}')
    # rename=$(cat *.js | grep -c $delids | awk '$1!="1" {print "Error"}')
    # if [[ (-n "$listed") && (-n "$rename") ]];then
      # echo "Error: translators are deleted but not listed in deleted.txt."
      # echo "Commit: $c"
      # echo "Deleted translator: $jsdeleted ; with id $delids"
      # echo $delids | xargs -i grep -c {} *.js
      # exitcode=1
    # fi
    
  # fi
# done
# echo "...DONE"

if [[ "$exitcode" -eq 0 ]];then
  echo -e "\nOKAY, all tests passed!"
fi
exit "$exitcode"
