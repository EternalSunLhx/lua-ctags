#!/usr/bin/env bash
set -eu
set -o pipefail

# Creates rockspec and source rock for a new lua-ctags release given version number.
# Should be executed from root lua-ctags directory.
# Resulting rockspec and rock will be in `package/`.

version="$1"

rm -rf package
mkdir package
cd package


echo
echo "=== Creating rockspec for lua-ctags $version ==="
echo

luarocks new-version ../lua-ctags-dev-1.rockspec --tag="$version"

echo
echo "=== Copying lua-ctags files ==="
echo

mkdir lua-ctags
cp -r ../src lua-ctags
mkdir lua-ctags/bin
cp ../bin/lua-ctags.lua lua-ctags/bin
cp -r ../doc lua-ctags
cp ../README.md ../CHANGELOG.md ../LICENSE lua-ctags

echo
echo "=== Packing source rock for lua-ctags $version ==="
echo

zip -r lua-ctags-"$version"-1.src.rock lua-ctags lua-ctags-"$version"-1.rockspec

cd ..
