local argparse = require "argparse"
local lfs = require "lfs"
local utils = require "lua-ctags.utils"

local version = {}

version.lua_ctags = "0.1.0"

if rawget(_G, "jit") then
   version.lua = rawget(_G, "jit").version
elseif _VERSION:find("^Lua ") then
   version.lua = "PUC-Rio " .. _VERSION
else
   version.lua = _VERSION
end

version.argparse = argparse.version

version.lfs = utils.unprefix(lfs._VERSION, "LuaFileSystem ")

version.string = ([[
lua-ctags: %s
Lua: %s
Argparse: %s
LuaFileSystem: %s]]):format(version.lua_ctags, version.lua, version.argparse, version.lfs)

return version
