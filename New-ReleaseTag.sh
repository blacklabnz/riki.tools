#!/bin/bash

while (( "$#" )); do
  case "$1" in
    -a|--authtoken)
      AUTHTOKEN=$2
      ;;
    -n|--modulename)
      MODULENAME=$2
      ;;
    --) # end argument parsing
      break
      ;;
    -*|--*=) # unsupported flags
      echo "Error: Unsupported flag $1" >&2
      exit 1
      ;;
  esac
  shift
done

if [ -z $AUTHTOKEN ]
then
  echo "Argument -a|--authtoken is required"
  exit 1
elif [ -z $MODULENAME ]
then
  echo "Argument -n|--modulename is required"
  exit 1
fi

CURRENT_DIR="$PWD"

MODULE=$(ls $CURRENT_DIR | grep $MODULENAME)

NUSPEC=$(ls $MODULE | grep nuspec)

# Readlink needs to be executed in the same folder of the find being queried
cd $MODULENAME

NUSPECPATH=$(readlink -f $NUSPEC)

PACKAGEVERSION=$(awk -F'[<>]' '/<version>/ { print $3}' $NUSPECPATH)

echo "Package version: $PACKAGEVERSION detected"

GITAUTHURL=$(printf "https://%s@Riki.visualstudio.com/DevOps/_git/Riki.Tools" $AUTHTOKEN)

echo "Setting git remote"

git remote set-url origin "$GITAUTHURL"

echo "Tag branch with release version $PACKAGEVERSION"

git tag "$PACKAGEVERSION"

echo "Push tag: $PACKAGEVERSION to origin"

git push origin "$PACKAGEVERSION"

echo "Script executed"