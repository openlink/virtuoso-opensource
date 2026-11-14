#!/bin/sh
# Resolve relative database paths from the configuration file's directory.
set -eu
if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "Usage: start.sh /path/to/virtuoso.ini" >&2
  exit 2
fi
package_root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
config_dir=$(CDPATH= cd -- "$(dirname -- "$1")" && pwd)
config_name=$(basename -- "$1")
cd "$config_dir"
exec "$package_root/bin/virtuoso-t" -f -c "$config_name"
