#!/bin/bash -xe

if test -z "$ENV"; then
  ENV=$1
fi

TMP_DIR=$(mktemp -d)

kustomize build manifests/$ENV/deployables/ | sed 's/__BRIVOENV__/'$ENV'/g' | kfilt -i kind=HelmRelease -x name=sitespeed -x name=snapshot-functions > $TMP_DIR/tmp.yaml

OUTFILE_DIR=$(mktemp -d)

csplit --suffix-format='%02d.yaml' --digits=2  --quiet --prefix=$OUTFILE_DIR/outfile --suppress-matched --elide-empty-files $TMP_DIR/tmp.yaml "/---/+0" "{*}"

hrval $OUTFILE_DIR
