local fs = require "lua-ctags.fs"
local utils = require "lua-ctags.utils"

local check_state = {}

local CheckState = utils.class()

function CheckState:__init(source_bytes, filepath)
   self.source_bytes = source_bytes

   if filepath then
      if not fs.is_absolute(filepath) then
         filepath = fs.abspath(filepath)
      end
   
      self.filepath = fs.fix_filepath(filepath)
   end
end

function check_state.new(source_bytes, filepath)
   return CheckState(source_bytes, filepath)
end

return check_state
