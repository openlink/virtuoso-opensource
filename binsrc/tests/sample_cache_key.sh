#!/bin/sh
# Extract the sample key implementation and check distinct layouts with ASan/UBSan.
set -eu
test_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source_file=${1:-"$test_dir/../../libsrc/Wi/sqlcost.c"}
test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT HUP INT TERM
sed -n '/^itc_sample_cache_key (/,/^#define SMPL_QUEUED/{ /^#define SMPL_QUEUED/!p; }' \
  "$source_file" > "$test_tmp/sample_cache.inc"
"${CC:-cc}" -std=gnu11 -g -O1 -fsanitize=address,undefined -fno-omit-frame-pointer \
  -DSAMPLE_CACHE_SOURCE="\"$test_tmp/sample_cache.inc\"" \
  "$test_dir/sample_cache_key.c" -o "$test_tmp/sample_cache_key"
"$test_tmp/sample_cache_key"
