local parser = require "lua-ctags.parser"
local decoder = require "lua-ctags.decoder"
local check_state = require "lua-ctags.check_state"
local ctags_parser = require "lua-ctags.ctags_parser"
local utils = require "lua-ctags.utils"
local fs = require "lua-ctags.fs"

local ctags = {}

local config = {
    output_format = "e-ctags",
    sort = "foldcase",
    recurse = false,
    append = false,
    max_var_length = 2,
    ignore_token = { 
        ["_"] = true, ["_ENV"] =  true, ["_G"] = true,
        ["false"] = true, ["true"] = true, ["local"] = true,
        ["nil"] = true, ["end"] = true, ["if"] = true,
        ["else"] = true, ["then"] = true, ["for"] = true,
        ["while"] = true, ["break"] = true, ["return"] = true,
        ["goto"] = true, ["elseif"] = true, ["do"] = true,
        ["until"] = true, ["repeat"] = true,
    },
    exclude = {},
}

local function init_options()
    local options_file = config.options
    if options_file == nil then return end
    options_file = fs.abspath(options_file)

    config.options = nil

    local content = utils.read_file(options_file)
    if content == nil then return end

    local options = {}
    local load_func, err = utils.load(content, options, "load options")
    if load_func == nil then return end

    load_func()
    config.options = options
end

local function is_file_exclude(filepath)
    for _, pattern in pairs(config.exclude) do
        if filepath:match(pattern) then
            return true
        end
    end

    return false
end

local function scan_files(files, filepath)
    if is_file_exclude(filepath) then return end

    if fs.is_file(filepath) then
        files[fs.normalize(filepath)] = true
        return
    end
    
    if fs.is_dir(filepath) then
        local lua_files = fs.extract_files(filepath, ".*%.lua$", is_file_exclude)
        for _, lua_filepath in ipairs(lua_files) do
            files[fs.normalize(lua_filepath)] = true
        end
    end
end

local function init_files()
    local files = {}
    for _, filepath in ipairs(config.files) do
        filepath = fs.abspath(filepath)
        scan_files(files, filepath)
    end

    config.files = files
end

local function init_args(args)
    utils.update(config, args)

    for idx, pattern in pairs(config.exclude) do
        config.exclude[idx] = pattern:gsub("%.", "%%."):gsub("%*", ".*")
    end

    init_options()
    init_files()

    if not next(config.files) then
        print("No files to parse.")
        return false
    end

    config.tagfile = fs.abspath(config.f or "tags")
    return true
end

local function parse_source(filepath)
    local all_lines = {}
    local source, err = utils.read_file(filepath, all_lines)
    if source == nil then
        print(err)
        return
    end
    local chstate = check_state.new(source, filepath)
    chstate.source = decoder.decode(chstate.source_bytes)
    chstate.line_offsets = {}
    chstate.line_lengths = {}
    local ast, comments, code_lines, line_endings, useless_semicolons = parser.parse(
       chstate.source, chstate.line_offsets, chstate.line_lengths)
    chstate.ast = ast
    chstate.comments = comments
    chstate.code_lines = code_lines
    chstate.line_endings = line_endings
    chstate.useless_semicolons = useless_semicolons
    chstate.all_lines = all_lines

    return chstate
end

local function deepcompare(t1,t2,ignore_mt)
    local ty1 = type(t1)
    local ty2 = type(t2)
    if ty1 ~= ty2 then return false end
    -- non-table types can be directly compared
    if ty1 ~= 'table' and ty2 ~= 'table' then return t1 == t2 end
    -- as well as tables which have the metamethod __eq
    if not ignore_mt then
        local mt = getmetatable(t1)
        if mt and mt.__eq then return t1 == t2 end
    end
    for k1,v1 in pairs(t1) do
        local v2 = t2[k1]
        if v2 == nil or not deepcompare(v1,v2) then return false end
    end
    for k2,v2 in pairs(t2) do
        local v1 = t1[k2]
        if v1 == nil or not deepcompare(v1,v2) then return false end
    end
    return true
end

local function is_ignore_token(token, user_ignore_token)
    if config.ignore_token[token] then return true end

    if user_ignore_token ~= nil and user_ignore_token[token] then return true end

    return false
end

local function is_valid_variable_name(token)
    return (string.match(token, "^[a-zA-Z_][a-zA-Z0-9_]*$"))
end

local function is_valid_token(token, user_ignore_token)
    return not is_ignore_token(token, user_ignore_token)
        and #token > config.max_var_length 
        and is_valid_variable_name(token)
end

local function get_user_ignore_token()
    local options = config.options
    if options == nil then return end

    return options.user_ignore_token
end

local tag_line_format = { 1, 2, 3, 4 }

local function parse_tag(chstate, module_define, class_define)
    if not chstate then return false end

    local lines = chstate.all_lines

    local tags_data = {}
    local tags_line_data = {}

    for block_index, block in ipairs(chstate.ast) do
        local ctags_parser_handle = ctags_parser[block.tag]
        if ctags_parser_handle ~= nil then
            ctags_parser_handle(block, lines, tags_data, module_define, class_define, true)
        end
    end

    local user_ignore_token = get_user_ignore_token()
    local filepath = chstate.filepath

    for token, token_data in pairs(tags_data) do
        if is_valid_token(token, user_ignore_token) then
            for line, var_type in pairs(token_data) do
                tag_line_format[1] = token
                tag_line_format[2] = filepath
                tag_line_format[3] = line
                tag_line_format[4] = var_type
                table.insert(tags_line_data, table.concat(tag_line_format, "\t"))
            end
        end
    end

    return table.concat(tags_line_data, "\n")
end

local function get_options_define()
    local options = config.options
    if options == nil then return end

    return options.module_define, options.class_define
end

local function parse_tags()
    local module_define, class_define = get_options_define()

    local need_save = false
    local new_tags = {}

    for filepath in pairs(config.files) do
        local ok, chstate = pcall(parse_source, filepath)
        if ok then
            new_tags[filepath] = parse_tag(chstate, module_define, class_define)
        end
    end

    return new_tags
end

local function try_get_current_tag_content()
    if not config.append then return end

    local file_handle = io.open(config.tagfile, "r")
    if file_handle == nil then return end

    local sContent = file_handle:read("*all")
    file_handle:close()

    if #sContent == 0 then return end
    return sContent
end

local function save_tags(new_tags)
    local tags = {}
    local filepath_contents = {}

    local new_contents = {}

    local sCurrentTagContent = try_get_current_tag_content()

    for filepath, tag_content in pairs(new_tags) do
        if sCurrentTagContent then
            local sPattern = "[%d%a_]+\t" .. filepath .. "\t.-\t.-\t[fvmc]+[\r\n]+"
            sCurrentTagContent = string.gsub(sCurrentTagContent, sPattern, "")
        end
        table.insert(new_contents, tag_content)
    end

    local file_handle = io.open(config.tagfile, "w")
    if file_handle ~= nil then
        if sCurrentTagContent then
            file_handle:write(sCurrentTagContent)
        end

        file_handle:write(table.concat(new_contents, "\n"))
        file_handle:write("\n")
        file_handle:close()
    end
end

function ctags.generate_tags(args)
    if not init_args(args) then
        return
    end

    save_tags(parse_tags())
end

return ctags
