local package_name = "lua-ctags"
local package_version = "dev"
local rockspec_revision = "1"
local github_account_name = "EternalSunLhx"
local github_repo_name = package_name

rockspec_format = "3.0"
package = package_name
version = package_version .. "-" .. rockspec_revision

source = {
   url = "git+https://github.com/" .. github_account_name .. "/" .. github_repo_name .. ".git"
}

if package_version == "dev" then source.branch = "master" else source.tag = "v" .. package_version end

description = {
   summary = "A ctags for Lua",
   detailed = [[
      lua-ctags is a command-line tool for generate the ctags tags file of Lua
      code.
   ]],
   homepage = "https://github.com/EternalSunLhx/lua-ctags",
   license = "MIT"
}

dependencies = {
   "lua >= 5.1",
   "argparse >= 0.6.0",
   "luafilesystem >= 1.6.3"
}

build = {
   type = "builtin",
   modules = {
      ["lua-ctags.check_state"] = "src/lua-ctags/check_state.lua",
      ["lua-ctags.decoder"] = "src/lua-ctags/decoder.lua",
      ["lua-ctags.fs"] = "src/lua-ctags/fs.lua",
      ["lua-ctags.globbing"] = "src/lua-ctags/globbing.lua",
      ["lua-ctags.lexer"] = "src/lua-ctags/lexer.lua",
      ["lua-ctags.main"] = "src/lua-ctags/main.lua",
      ["lua-ctags.parser"] = "src/lua-ctags/parser.lua",
      ["lua-ctags.ctags"] = "src/lua-ctags/ctags.lua",
      ["lua-ctags.ctags_parser"] = "src/lua-ctags/ctags_parser.lua",
      ["lua-ctags.unicode"] = "src/lua-ctags/unicode.lua",
      ["lua-ctags.unicode_printability_boundaries"] = "src/lua-ctags/unicode_printability_boundaries.lua",
      ["lua-ctags.utils"] = "src/lua-ctags/utils.lua",
      ["lua-ctags.version"] = "src/lua-ctags/version.lua"
   },
   install = {
      bin = {
         lua-ctags = "bin/lua-ctags.lua"
      }
   }
}
