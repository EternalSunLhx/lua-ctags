local argparse = require "argparse"
local utils = require "lua-ctags.utils"
local version = require "lua-ctags.version"
local ctags = require "lua-ctags.ctags"

local exit_codes = {
   ok = 0,
   critical = 1,
}

local function critical(msg)
   io.stderr:write("Critical error: "..msg.."\n")
   os.exit(exit_codes.critical)
end

local function get_parser()
   local parser = argparse(
      "lua-ctags", "lua-ctags " .. version.lua_ctags .. ", a ctags for Lua.", [[
Links:

   lua-ctags on GitHub: https://github.com/EternalSunLhx/lua-ctags]])
      :help_max_width(80)
   -- lua-ctags documentation: https://lua-ctags.readthedocs.org]])

   parser:argument("files", "List of files, directories to generate tags file.")
      :args "+"
      :argname "<file>"

   parser:group("Input/Output Options",
      parser:flag("-R --recurse", "Recurse into directories supplied on command line [no]."):action("store_false"),
      parser:flag("-a --append", "Should tags should be appended to existing tag file [no]?"):action("store_false"),
      
      parser:option("-f", "Write tags to specified <tagfile>. Value of \"-\" writes tags to stdout\n[\"tags\"; or \"TAGS\" when -e supplied]."):argname "<tagfile>",
      parser:option("--min-var-length", "Specify minmum variable name length. Default: 2"):argname "<max_var_length>":convert(tonumber))

   parser:group("Output Format Options",
      parser:option("--output-format", "Specify the output format.(u-ctags|e-ctags|etags|xref|json). Default: e-ctags"):argname "<output_format>":choices { "u-ctags", "e-ctags", "etags", "xref", "json" },
      parser:option("--sort", "Should tags be sorted (optionally ignoring case) [yes]?":argname "<sort>":choices { "no", "yes", "foldcase" }:init("foldcase")),
      parser:flag("-u", "Equivalent to --sort=no."):target("sort"):init("no"))

   parser:option("--options", "Specify file (or directory) <pathname> from which command line options should be read."):argname "<options>"

   parser:flag("--version", "Show version info and exit.")
      :action(function() print(version.string) os.exit(exit_codes.ok) end)

   return parser
end

local function main()
   local parser = get_parser()
   local ok, args = parser:pparse()
   if not ok then
      io.stderr:write(("%s\n\nError: %s\n"):format(parser:get_usage(), args))
      os.exit(exit_codes.critical)
   end

   local ok, error_wrapper = utils.try(ctags.generate, args)

   if not ok then
      local msg = ("lua-ctags %s bug (please report at https://github.com/EternalSunLhx/lua-ctags/issues):\n%s\n%s"):format(version.lua_ctags, error_wrapper.err, error_wrapper.traceback)
      critical(msg)
   end
   
   os.exit(exit_codes.ok)
end

local _, error_wrapper = utils.try(main)
local err = error_wrapper.err
local traceback = error_wrapper.traceback

if utils.is_instance(err, utils.InvalidPatternError) then
   critical(("Invalid pattern '%s'"):format(err.pattern))
elseif type(err) == "string" and err:find("interrupted!$") then
   critical("Interrupted")
else
   local msg = ("lua-ctags %s bug (please report at https://github.com/EternalSunLhx/lua-ctags/issues):\n%s\n%s"):format(
      version.lua_ctags, err, traceback)
   critical(msg)
end
