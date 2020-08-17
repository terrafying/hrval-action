kustomize build manifests/int/deployables/ | kfilt -i kind=HelmRelease > tmp.yaml
mkdir ktmp
csplit --suffix-format='%02d.yaml' --digits=2  --quiet --prefix=ktmp/outfile --suppress-matched --elide-empty-files tmp.yaml "/---/+0" "{*}"
hrval ktmp
