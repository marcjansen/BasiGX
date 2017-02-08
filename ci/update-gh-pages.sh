#!/usr/bin/env bash
set -e

# ------------------------------------------------------------------------------
# This script is supposed to be called from Travis continuous integration server
#
# It will update the gh.pages branch of BasiGX with various artifacts created
# in the previous step
# ------------------------------------------------------------------------------

# Load variables and the 'running-on-travis'-check
. $TRAVIS_BUILD_DIR/ci/shared.sh

if [ $TRAVIS_PULL_REQUEST != "false" ]; then
    # Dont build anything for PR requests, only for merges
    return 0;
fi

if [ $TRAVIS_BRANCH != "master" ]; then
    # only update when the target branch is master
    return 0;
fi

# default is master…
SUB_FOLDER_NAME=$TRAVIS_BRANCH;
DOC_SUFFIX="-dev"

if [ "$TRAVIS_TAG" != "" ]; then
    # … but if we are building for a tag, let's use this as folder name
    SUB_FOLDER_NAME=$TRAVIS_TAG
    DOC_SUFFIX=""
fi

DOCS_DIR=$SUB_FOLDER_NAME/docs
DOCS_W_EXT_DIR=$SUB_FOLDER_NAME/docs-w-ext

RAW_CP_DIRS="examples resources src"

ORIGINAL_AUTHOR_NAME=$(git show -s --format="%aN" $TRAVIS_COMMIT)
ORIGINAL_AUTHOR_EMAIL=$(git show -s --format="%ae" $TRAVIS_COMMIT)

GH_PAGES_BRANCH=gh-pages
GH_PAGES_REPO_FROM_SLUG="github.com/$TRAVIS_REPO_SLUG.git"
GH_PAGES_REPO="https://$GH_PAGES_REPO_FROM_SLUG"
GH_PAGES_REPO_AUTHENTICATED="https://$GH_TOKEN@$GH_PAGES_REPO_FROM_SLUG"
GH_PAGES_DIR=/tmp/basigx-gh-pages
GH_PAGES_COMMIT_MSG=$(cat <<EOF
Update resources on gh-pages branch

This commit was autogenerated by the 'update-gh-pages.sh' script
and it reflects the state of the master branch at revision
$TRAVIS_COMMIT (by $ORIGINAL_AUTHOR_NAME).
EOF
)
git config --global user.name "$ORIGINAL_AUTHOR_NAME"
git config --global user.email "$ORIGINAL_AUTHOR_EMAIL"


git clone --branch $GH_PAGES_BRANCH $GH_PAGES_REPO $GH_PAGES_DIR

cd $GH_PAGES_DIR


# 1. Update BasiGX package
mkdir -p cmd/pkgs/$BASIGX_PACKAGE_NAME
rm -Rf cmd/pkgs/$BASIGX_PACKAGE_NAME/$BASIGX_PACKAGE_VERSION
cp -r $INSTALL_DIR/../repo/pkgs/$BASIGX_PACKAGE_NAME/$BASIGX_PACKAGE_VERSION cmd/pkgs/$BASIGX_PACKAGE_NAME
# TODO the files catalog.json should better be updated, instead of overwritten…
cp $INSTALL_DIR/../repo/pkgs/catalog.json cmd/pkgs/
cp $INSTALL_DIR/../repo/pkgs/$BASIGX_PACKAGE_NAME/catalog.json cmd/pkgs/$BASIGX_PACKAGE_NAME

# Since the catalog.json also references the GeoExt package, we also republish
# it here
#
# TODO how can we avoid this republishing or optionally at least have the
#      versions and names be auto-configured?
#      * One idea would be to simply copy over the complete `repo/pkgs`-folder
#      * Alternatively, we should probably only advertize the BasiGX package in
#        the catalog json, but I am unsure, if that fits with the sencha
#        philosophy. It may be that dependent packages have to provided along
#        with the main package, to ensure the dependencies can be resolved at
#        time sencha builds concrete apps / other packages.
GEOEXT_PACKAGE_NAME=GeoExt
GEOEXT_PACKAGE_VERSION=3.0.0
mkdir -p cmd/pkgs/$GEOEXT_PACKAGE_NAME
rm -Rf cmd/pkgs/$GEOEXT_PACKAGE_NAME/$GEOEXT_PACKAGE_VERSION
cp -r $INSTALL_DIR/../repo/pkgs/$GEOEXT_PACKAGE_NAME/$GEOEXT_PACKAGE_VERSION cmd/pkgs/$GEOEXT_PACKAGE_NAME

# 2. examples, resources & src copied from repo
for RAW_CP_DIR in $RAW_CP_DIRS
do
    mkdir -p $SUB_FOLDER_NAME/$RAW_CP_DIR
    rm -Rf $SUB_FOLDER_NAME/$RAW_CP_DIR/*
    cp -r $TRAVIS_BUILD_DIR/$RAW_CP_DIR/* $SUB_FOLDER_NAME/$RAW_CP_DIR
done


# 3. Update the API docs
# 3.1 … without ExtJS
mkdir -p $DOCS_DIR # for the API-docs without ExtJS classes
rm -Rf $DOCS_DIR/* # remove any content from previous runs
jsduck \
    --config="$TRAVIS_BUILD_DIR/jsduck.json" \
    --output="$DOCS_DIR/" \
    --title="$BASIGX_PACKAGE_NAME $BASIGX_PACKAGE_VERSION$DOC_SUFFIX Documentation" \
     --warnings="-inheritdoc"


# TODO include GeoExt sources
# 3.2 … with ExtJS
mkdir -p $DOCS_W_EXT_DIR # for the API-docs without ExtJS classes
rm -Rf $DOCS_W_EXT_DIR/* # remove any content from previous runs
jsduck \
    --config="$TRAVIS_BUILD_DIR/jsduck.json" \
    --output="$DOCS_W_EXT_DIR/" \
    --title="$BASIGX_PACKAGE_NAME $BASIGX_PACKAGE_VERSION$DOC_SUFFIX Documentation (incl. ExtJS classes)" \
     --warnings="-all:$DOWN_DIR/ext-$SENCHA_EXTJS_VERSION" \
    "$DOWN_DIR/ext-$SENCHA_EXTJS_VERSION/packages/core/src" \
    "$DOWN_DIR/ext-$SENCHA_EXTJS_VERSION/classic/classic/src"


# 4. done.

# Next: add, commit and push
git add --all
git commit -m "$GH_PAGES_COMMIT_MSG"
git push --quiet $GH_PAGES_REPO_AUTHENTICATED $GH_PAGES_BRANCH

# Cleanup
rm -Rf $GH_PAGES_DIR
