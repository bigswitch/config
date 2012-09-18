#!/bin/bash -xe

PROJECT=$1
COMMIT_MSG="Imported Translations from Transifex"

git config user.name "OpenStack Jenkins"
git config user.email "jenkins@openstack.org"
git config gitreview.username "jenkins"

git review -s

# See if there is an open change in the transifex/translations topic
# If so, get the change id for the existing change for use in the commit msg.
change_info=`ssh -p 29418 review.openstack.org gerrit query --current-patch-set status:open project:openstack/$PROJECT topic:transifex/translations owner:jenkins`
previous=`echo "$change_info" | grep "^  number:" | awk '{print $2}'`
if [ "x${previous}" != "x" ] ; then
    change_id=`echo "$change_info" | grep "^change" | awk '{print $2}'`
    read -d '' COMMIT_MSG <<EOF
Imported Translations from Transifex

Change-Id: $change_id
EOF
fi

# initialize transifex client
tx init --host=https://www.transifex.com
tx set --auto-local -r ${PROJECT}.${PROJECT}-translations "${PROJECT}/locale/<lang>/LC_MESSAGES/${PROJECT}.po" --source-lang en --source-file ${PROJECT}/locale/${PROJECT}.pot --execute

# Pull all upstream translations
tx pull -a
# Update the .pot file
python setup.py extract_messages
# Use updated .pot file to update translations
python setup.py update_catalog
# Add all changed files to git
git add $PROJECT/locale/*

if [ ! `git diff-index --quiet HEAD --` ]
then
    # Commit and review
    git commit -F- <<EOF
$COMMIT_MSG
EOF
    git review -t transifex/translations

    # Push changes to transifex
    tx --debug --traceback push -st
fi
