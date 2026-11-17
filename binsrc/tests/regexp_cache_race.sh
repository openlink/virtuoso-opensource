#!/bin/sh
# Extract the cache implementation and run deterministic regressions with ASan/UBSan.
set -eu
test_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source_file=${1:-"$test_dir/../../libsrc/Wi/bif_regexp.c"}
test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT HUP INT TERM
sed -n '/^typedef struct regexp_key_s/,/^#define SET_INVALID_ARG/{ /^#define SET_INVALID_ARG/!p; }' \
  "$source_file" > "$test_tmp/regexp_cache.inc"
"${CC:-cc}" -std=gnu11 -g -O1 -fsanitize=address,undefined -fno-omit-frame-pointer \
  -DREGEXP_CACHE_SOURCE="\"$test_tmp/regexp_cache.inc\"" \
  "$test_dir/regexp_cache_race.c" -o "$test_tmp/regexp_cache_race"
test_status=0
for mode in hit double-compile; do
  if "$test_tmp/regexp_cache_race" "$mode"; then
    :
  else
    test_status=1
  fi
done
exit "$test_status"
