local function add_flag(flags, flag)
    flags = flags or {}
    for _, f in ipairs(flags) do
        if f == flag then
            return flags
        end
    end
    table.insert(flags, flag)
    return flags
end

for _, proto in pairs(data.raw["inserter"] or {}) do
    proto.flags = add_flag(proto.flags, "get-by-unit-number")
end
