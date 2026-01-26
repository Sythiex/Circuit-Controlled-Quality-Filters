local util = require("util")

local PREFIX = "ccqf-quality-"

-- Put the proxies under their own subgroup within the Signals group
data:extend({
    {
        type = "item-subgroup",
        name = "ccqf-quality-proxies",
        group = "signals",
        order = "cd[ccqf]"
    }})

local function pad3(n)
    n = tonumber(n) or 0
    if n < 0 then
        n = 0
    end
    return string.format("%03d", n)
end

-- "super-rare" -> "Super Rare"
local function title_case(id)
    local s = tostring(id or "")
    s = s:gsub("[-_]+", " ")
    s = s:gsub("(%a)([%w']*)", function(first, rest)
        return first:upper() .. rest:lower()
    end)
    return s
end

local to_extend = {}

-- dynamically create virtual signals for each quality (so we can add them to the Signals tab under the comparators)
for qname, q in pairs(data.raw["quality"] or {}) do
    local display = q.localised_name or {"", title_case(qname)} -- Reuse the quality's localized name

    local vs = {
        type = "virtual-signal",
        name = PREFIX .. qname,
        subgroup = "ccqf-quality-proxies",
        order = "a[level-" .. pad3(q.level) .. "]-" .. qname, -- Sort by quality tier first (level), then name
        localised_name = display
    }

    -- Reuse the quality's icon (supports both icon and icons forms)
    if q.icons then
        vs.icons = util.table.deepcopy(q.icons)
    else
        vs.icon = q.icon
        vs.icon_size = q.icon_size or 64
        vs.icon_mipmaps = q.icon_mipmaps
    end

    -- Mirror hidden flags if present
    if q.hidden ~= nil then
        vs.hidden = q.hidden
    end
    if q.hidden_in_factoriopedia ~= nil then
        vs.hidden_in_factoriopedia = q.hidden_in_factoriopedia
    end

    to_extend[#to_extend + 1] = vs
end

data:extend(to_extend)
