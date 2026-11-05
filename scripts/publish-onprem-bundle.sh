#!/usr/bin/env bash
# Upload an on-prem bundle to S3. Refuses to overwrite an existing object.
#
#   OL_GENE_RELEASES_BUCKET=... OL_GENE_RELEASES_URL_BASE=https://downloads.example.com \
#     ./scripts/publish-onprem-bundle.sh 5.5.1
#
# Reads ol-gene-<tag>-linux-amd64.tar.gz and the matching .sha256 from the
# current directory. Prints the HTTPS URL. When GITHUB_OUTPUT is set, also
# writes bundle_url for the calling workflow step.

set -euo pipefail

tag="${1:-}"
bucket="${OL_GENE_RELEASES_BUCKET:-}"
url_base="${OL_GENE_RELEASES_URL_BASE:-}"

if [[ -z "$tag" ]]; then
  echo "Usage: ./scripts/publish-onprem-bundle.sh <tag>" >&2
  exit 1
fi
if [[ ! "$tag" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Tag must be a version like 5.5.1 (got: ${tag})" >&2
  exit 1
fi
if [[ -z "$bucket" ]]; then
  echo "OL_GENE_RELEASES_BUCKET is not set" >&2
  exit 1
fi
if [[ -z "$url_base" ]]; then
  echo "OL_GENE_RELEASES_URL_BASE is not set" >&2
  exit 1
fi

archive="ol-gene-${tag}-linux-amd64.tar.gz"
checksum="${archive}.sha256"
if [[ ! -f "$archive" || ! -f "$checksum" ]]; then
  echo "Missing ${archive} or ${checksum} in $(pwd)" >&2
  exit 1
fi

prefix="ol-gene/${tag}"
archive_key="${prefix}/${archive}"
checksum_key="${prefix}/${checksum}"

object_exists() {
  aws s3api head-object --bucket "$bucket" --key "$1" >/dev/null 2>&1
}

if object_exists "$archive_key" || object_exists "$checksum_key"; then
  echo "Refusing to overwrite s3://${bucket}/${archive_key}" >&2
  echo "Delete that key by hand, or cut a new patch version." >&2
  exit 1
fi

aws s3 cp "$archive" "s3://${bucket}/${archive_key}"
aws s3 cp "$checksum" "s3://${bucket}/${checksum_key}"

url_base="${url_base%/}"
url="${url_base}/${archive_key}"
echo "$url"
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "bundle_url=${url}" >> "$GITHUB_OUTPUT"
fi
