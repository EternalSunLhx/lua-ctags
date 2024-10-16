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
}

local exist_tags_data = {}

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

local function init_files()
    local files = {}
    for _, filepath in ipairs(config.files) do
        filepath = fs.abspath(filepath)
        if fs.is_file(filepath) then
            files[fs.normalize(filepath)] = true
        elseif fs.is_dir(filepath) then
            local lua_files = fs.extract_files(filepath, ".*%.lua$")
            for _, lua_filepath in ipairs(lua_files) do
                files[fs.normalize(lua_filepath)] = true
            end
        end
    end

    config.files = files
end

local function init_exist_tags()
    local tagfile = fs.abspath(config.f or "tags")
    config.tagfile = tagfile

    local tag_cache_file = tagfile .. ".cache"
    config.tag_cache_file = tag_cache_file

    local source = utils.read_file(tag_cache_file)
    if source == nil then return end

    local load_func = utils.load(source, nil, "load tags")
    if load_func == nil then return end

    exist_tags_data = load_func() or {}
end

local function init_args(args)
    utils.update(config, args)
    init_options()
    init_files()

    if not next(config.files) then
        print("No files to parse.")
        return false
    end

    init_exist_tags()
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

local function parse_tag(chstate, module_define, class_define)
    if not chstate then return false end

    local lines = chstate.all_lines

    local tags_data = {}
    local tags_line_data = {}

    for block_index, block in ipairs(chstate.ast) do
        local ctags_parser_handle = ctags_parser[block.tag]
        if ctags_parser_handle ~= nil then
            ctags_parser_handle(block, lines, tags_data, module_define, class_define)
        end
    end

    local user_ignore_token = get_user_ignore_token()
    local filepath = chstate.filepath

    for token, token_data in pairs(tags_data) do
        if is_valid_token(token, user_ignore_token) then
            for line, var_type in pairs(token_data) do
                table.insert(tags_line_data, string.format("%s\t%s\t%s\t%s", token, filepath, line, var_type))
            end
        end
    end

    local is_changed = true

    if config.append then
        table.sort(tags_line_data)
        is_changed = not deepcompare(exist_tags_data[filepath], tags_line_data, true)
    end

    exist_tags_data[filepath] = tags_line_data
    return is_changed
end

local function get_options_define()
    local options = config.options
    if options == nil then return end

    return options.module_define, options.class_define
end

local function parse_tags()
    local module_define, class_define = get_options_define()

    local need_save = false

    for filepath in pairs(config.files) do
        local chstate = parse_source(filepath)
        local is_changed = parse_tag(chstate, module_define, class_define)
        if not need_save then
            need_save = is_changed
        end
    end

    if not config.append then
        for filepath in pairs(exist_tags_data) do
            if not config.files[filepath] then
                need_save = true
                exist_tags_data[filepath] = nil
            end
        end
    end

    return need_save
end

local function save_tags()
    local tags = {}
    local filepath_contents = {}

    for filepath, tags_line_data in pairs(exist_tags_data) do
        for index, tag_line in ipairs(tags_line_data) do
            table.insert(tags, tag_line)
            tags_line_data[index] = string.format("        \"%s\"", tag_line:gsub("\\", "\\\\"):gsub('"', '\\"'))
        end
        table.insert(filepath_contents, string.format("    [\"%s\"] = {\n%s\n    }", string.gsub(filepath, "\\", "\\\\"), table.concat(tags_line_data, ",\n")))
    end

    table.sort(tags)

    local file_handle = io.open(config.tagfile, "w")
    if file_handle ~= nil then
        file_handle:write(table.concat(tags, "\n"))
        file_handle:close()
    end

    file_handle = io.open(config.tag_cache_file, "w")
    if file_handle ~= nil then
        file_handle:write(string.format("return {\n%s\n}", table.concat(filepath_contents, ",\n")))
        file_handle:close()
    end
end

function ctags.generate_tags(args)
    if not init_args(args) then
        return
    end

    local need_save = parse_tags()
    if need_save then
        save_tags()
    end
end

return ctags
