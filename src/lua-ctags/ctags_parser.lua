local ctags_parser = {}

local empty_table = setmetatable({}, { __newindex = function(t, k, v) end })

local function try_parse_block(block, lines, tags_data, module_define, class_define)
    local ctags_parser_handle = ctags_parser[block.tag]
    if ctags_parser_handle == nil then return end
    ctags_parser_handle(block, lines, tags_data, module_define, class_define)
end

local function for_each_block(block, lines, tags_data, module_define, class_define)
    if block == nil then return end
    for _, sub_block in ipairs(block) do
        try_parse_block(sub_block, lines, tags_data, module_define, class_define)
    end
end

local function get_var_name(var_block)
    if var_block.tag == "Id" then
        return var_block[1], var_block.line
    end

    if var_block.tag == "Index" then
        local var_name_block = var_block[2]
        if var_name_block.tag == "String" then
            return var_name_block[1], var_name_block.line
        end
    end
end

local function get_var_type(var_value_block)
    if var_value_block == nil then return "v" end

    if var_value_block.tag == "Function" then return "f" end

    return "v"
end

local function format_line(line)
    return string.format("/^%s$/;\"", line)
end

local function __add_var_define(lines, tags_data, var_name, var_line, var_type)
    local token_data = tags_data[var_name] or {}
    token_data[format_line(lines[var_line])] = var_type
    tags_data[var_name] = token_data
end

local function add_var_define(lines, tags_data, var_block, value_block, var_type)
    local var_name, var_line = get_var_name(var_block)
    if var_name ~= nil then
        __add_var_define(lines, tags_data, var_name, var_line, var_type or get_var_type(value_block))
    end
end

ctags_parser["Set"] = function(set_block, lines, tags_data, module_define, class_define)
    local var_define_block = set_block[1]
    local value_define_block = set_block[2]
    
    for var_index, var_block in ipairs(var_define_block) do
        local value_block = value_define_block[var_index]
        if value_block ~= nil then
            if value_block.tag == "Function" or value_block.tag == "Table" or value_block.tag == "Op" then
                try_parse_block(value_block, lines, tags_data, module_define, class_define)
            end
        end

        add_var_define(lines, tags_data, var_block, value_block)
    end
end

ctags_parser["Local"] = function(local_block, lines, tags_data, module_define, class_define)
    local value_define_block = local_block[2] or empty_table
    
    for index, var_block in ipairs(local_block[1]) do
        local value_block = value_define_block[index]

        add_var_define(lines, tags_data, var_block, value_block)

        if value_block ~= nil and (value_block.tag == "Call" or value_block.tag == "Table") then
            ctags_parser[value_block.tag](value_block, lines, tags_data, module_define, class_define)
        end
    end
end

ctags_parser["Localrec"] = ctags_parser["Local"]

ctags_parser["Do"] = function(do_block, lines, tags_data, module_define, class_define)
    for_each_block(do_block, lines, tags_data, module_define, class_define)
end

ctags_parser["Op"] = function(op_block, lines, tags_data, module_define, class_define)
    for block_index, block in ipairs(op_block) do
        if block_index ~= 1 then
            try_parse_block(block, lines, tags_data, module_define, class_define)
        end
    end
end

ctags_parser["Repeat"] = function(repeat_block, lines, tags_data, module_define, class_define)
    for_each_block(repeat_block[1], lines, tags_data, module_define, class_define)
end

ctags_parser["Fornum"] = function(for_block, lines, tags_data, module_define, class_define)
    for _, block in ipairs(for_block) do
        if block.tag == nil then
            for_each_block(block, lines, tags_data, module_define, class_define)
        end
    end
end

ctags_parser["Forin"] = ctags_parser["Fornum"]

ctags_parser["While"] = function(while_block, lines, tags_data, module_define, class_define)
    for_each_block(while_block[2], lines, tags_data, module_define, class_define)
end

ctags_parser["If"] = function(if_block, lines, tags_data, module_define, class_define)
    for _, block in ipairs(if_block) do
        if block.tag == nil then
            for_each_block(block, lines, tags_data, module_define, class_define)
        end
    end
end

ctags_parser["Pair"] = function(pair_block, lines, tags_data, module_define, class_define)
    local key_block = pair_block[1]
    if key_block.tag == "String" then
        __add_var_define(lines, tags_data, key_block[1], key_block.line, "v")
    else
        try_parse_block(key_block, lines, tags_data, module_define, class_define)
    end

    -- value
    try_parse_block(pair_block[2], lines, tags_data, module_define, class_define)
end

ctags_parser["Table"] = function(table_block, lines, tags_data, module_define, class_define)
    for_each_block(table_block, lines, tags_data, module_define, class_define)
end

ctags_parser["Function"] = function(function_block, lines, tags_data, module_define, class_define)
    for_each_block(function_block[2], lines, tags_data, module_define, class_define)
end

ctags_parser["Return"] = function(return_block, lines, tags_data, module_define, class_define)
    for block_index, block in ipairs(return_block) do
        if block.tag == "Call" or block.tag == "Table" then
            ctags_parser[block.tag](block, lines, tags_data, module_define, class_define)
        end
    end
end

local function is_module_or_class(function_name_block, module_define, class_define)
    local var_name, var_line = get_var_name(function_name_block)
    if var_name == nil then return end

    if module_define ~= nil then
        local module_name_index = module_define[var_name]
        if module_name_index ~= nil then
            return module_name_index, "m"
        end
    end

    if class_define ~= nil then
        local class_name_index = class_define[var_name]
        if class_name_index ~= nil then
            return class_name_index, "c"
        end
    end
end

ctags_parser["Call"] = function(call_block, lines, tags_data, module_define, class_define)
    local name_index, var_type = is_module_or_class(call_block[1], module_define, class_define)
    if name_index ~= nil then
        local name_arg_block = call_block[name_index + 1]
        if name_arg_block ~= nil and name_arg_block.tag == "String" then
            __add_var_define(lines, tags_data, name_arg_block[1], name_arg_block.line, var_type)
        end
    end

    for block_index, block in ipairs(call_block) do
        if block_index ~= 1 then
            try_parse_block(block, lines, tags_data, module_define, class_define)
        end
    end
end

return ctags_parser
