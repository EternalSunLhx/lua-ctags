-- Version of bin/lua-ctags.lua for use in lua-ctags binaries.

-- Do not load modules from filesystem in case a bundled module is broken.
package.path = ""
package.cpath = ""

require "lua-ctags.main"
