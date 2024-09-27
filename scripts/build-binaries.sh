#!/usr/bin/env bash
set -eu
set -o pipefail

# Builds the following binaries:
# * lua-ctags (Linux x86-64)
# * lua-ctags32 (Linux x86)
# * lua-ctags.exe (Windows x86-64)
# * lua-ctags32.exe (Windows x86)
# Should be executed from root lua-ctags directory.
# Resulting binaries will be in `build/bin/`.

cd build

make fetch

function build {
    label="$1"
    shift

    echo
    echo "=== Building lua-ctags ($label) ==="
    echo

    make clean "$@"
    make "-j$(nproc)" "$@"
}

build "Linux x86-64" LINUX=1
#build "Linux x86" LINUX=1 "BASE_CC=gcc -m32" SUFFIX=32
build "Windows x86-64" CROSS=x86_64-w64-mingw32- SUFFIX=.exe
build "Windows x86" CROSS=i686-w64-mingw32- SUFFIX=32.exe
