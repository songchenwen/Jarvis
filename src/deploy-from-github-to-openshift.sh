#!/bin/bash

rm -rf $UPDATE_DIR
mkdir -p $UPDATE_DIR
git clone -b $OPENSHIFT_DEPLOYMENT_BRANCH $UPDATE_URL $UPDATE_DIR
cd $UPDATE_DIR
git remote add to $GIT_REPO_PATH
git push to $OPENSHIFT_DEPLOYMENT_BRANCH
code=$?
rm -rf $UPDATE_DIR
exit $code
