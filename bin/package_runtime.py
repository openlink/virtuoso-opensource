#!/usr/bin/env python3
"""Bundle the loader and shared libraries for an installed Linux x86-64 build."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess


def main() -> None:
    """Copy an installation and add relocatable launchers and dependency manifests."""
    parser = argparse.ArgumentParser(description="Package an installed Virtuoso runtime")
    parser.add_argument("installation", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    source = args.installation.resolve()
    destination = args.destination.resolve()
    if destination.exists():
        parser.error("Destination already exists")
    if not (source / "bin/virtuoso-t").is_file():
        parser.error("Installation does not contain bin/virtuoso-t")

    # Collect shared libraries and the loader required by the installed executables.
    dependencies = {}
    executables = []
    for executable in sorted((source / "bin").iterdir()):
        if not executable.is_file():
            continue
        with executable.open("rb") as stream:
            if stream.read(4) != b"\x7fELF":
                continue
        executables.append(executable.name)
        result = subprocess.run(["ldd", str(executable)], check=True, capture_output=True, text=True)
        if "not found" in result.stdout:
            raise RuntimeError(f"Unresolved dependencies: {executable.name}")
        for line in result.stdout.splitlines():
            match = re.search(r"(?:=>\s+|^\s*)(/\S+)", line)
            if match:
                library = Path(match[1])
                dependencies[library.name] = library.resolve()
    if "ld-linux-x86-64.so.2" not in dependencies:
        raise RuntimeError("Only dynamically linked Linux x86-64 installations are supported")

    # Keep original executables separate from launchers without modifying the source.
    shutil.copytree(source, destination, symlinks=True)
    runtime = destination / "lib/runtime"
    runtime.mkdir(parents=True)
    (destination / "libexec").mkdir()
    for name, library in dependencies.items():
        shutil.copy2(library, runtime / name)
    modules = Path("/usr/lib/x86_64-linux-gnu/ossl-modules")
    if modules.is_dir():
        shutil.copytree(modules, runtime / "ossl-modules")
    for name in executables:
        entry = destination / "bin" / name
        entry.rename(destination / "libexec" / name)
        entry.write_text('''#!/bin/sh
# Use the bundled loader while preserving the working directory for database paths.
set -eu
package_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
export OPENSSL_MODULES="$package_root/lib/runtime/ossl-modules"
exec "$package_root/lib/runtime/ld-linux-x86-64.so.2" \\
  --library-path "$package_root/lib/runtime" \\
  "$package_root/libexec/''' + name + '''" "$@"
''')
        entry.chmod(0o755)

    # Include licenses, dependency provenance and checksums for package verification.
    licenses = destination / "licenses"
    licenses.mkdir()
    shutil.copy2(Path(__file__).resolve().parents[1] / "COPYING", licenses / "Virtuoso-COPYING")
    for package in ("libc6", "libssl3t64", "libssl3"):
        copyright_file = Path("/usr/share/doc") / package / "copyright"
        if copyright_file.exists():
            shutil.copy2(copyright_file, licenses / f"{package}-copyright")
    (destination / "runtime-manifest.json").write_text(json.dumps({
        "architecture": "linux-x86_64", "executables": executables,
        "libraries": {name: str(path) for name, path in dependencies.items()},
    }, indent=2) + "\n")
    start_script = destination / "start.sh"
    shutil.copy2(Path(__file__).with_name("start_runtime.sh"), start_script)
    start_script.chmod(0o755)
    checksums = []
    for path in sorted(destination.rglob("*")):
        if path.is_file() and not path.is_symlink():
            with path.open("rb") as stream:
                checksum = hashlib.file_digest(stream, "sha256").hexdigest()
            checksums.append(f"{checksum}  {path.relative_to(destination)}\n")
    (destination / "SHA256SUMS").write_text("".join(checksums))
    print(f"Packaged {len(executables)} executables and {len(dependencies)} libraries: {destination}")


if __name__ == "__main__":
    main()
