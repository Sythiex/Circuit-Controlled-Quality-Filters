local ROOT_NAME = "quality_control_relative_gui_root"
local CHECKBOX_NAME = "quality_control_checkbox"
local TAG_KEY = "quality_control_set_filters"
local QUALITY_PROXY_PREFIX = "ccqf-quality-"
local FAST_REPLACE_WINDOW_TICKS = 6

local BATCH_SIZE = 50

-- updates BATCH_SIZE from the map mod setting
local function update_batch_size()
    local s = settings.global["ccqf-batch-size"]
    local v = (s and s.value) or 50
    BATCH_SIZE = v
end

local function state()
    storage.quality_filter_control = storage.quality_filter_control or {}
    local s = storage.quality_filter_control
    s.enabled_by_unit = s.enabled_by_unit or {} -- [unit_number] = true/nil
    s.open_entity_by_player = s.open_entity_by_player or {} -- [player_index] = LuaEntity (inserter or ghost)
    s.recent_replace_by_pos = s.recent_replace_by_pos or {} -- [pos_key] = { enabled=bool, tick=uint } - used for fast-replace

    -- use for scanning updates
    s.enabled_unit_array = s.enabled_unit_array or {} -- array of unit_numbers
    s.enabled_index = s.enabled_index or 1 -- round-robin position

    return s
end

local function debug_print(msg)
    for _, p in pairs(game.players) do
        p.print(msg)
    end
end

local function is_inserter_or_ghost_inserter(entity)
    return entity and entity.valid and entity.unit_number ~= nil and (entity.type == "inserter" or (entity.type == "entity-ghost" and entity.ghost_type == "inserter"))
end

-- Turns off "Set filters" from circuit network, turns on "Use filters", turns on "Whitelist"
local function ensure_correct_filter_settings(entity)
    if not (entity and entity.valid and entity.type == "inserter") then
        return
    end

    if (entity.filter_slot_count or 0) == 0 then
        return
    end

    local control_behavior = entity.get_control_behavior()
    if control_behavior and control_behavior.valid and control_behavior.circuit_set_filters then
        control_behavior.circuit_set_filters = false
    end

    if not entity.use_filters then
        entity.use_filters = true
    end

    if entity.inserter_filter_mode ~= "whitelist" then
        entity.inserter_filter_mode = "whitelist"
    end
end

local function set_enabled(entity, enabled)
    local s = state()
    if entity.type == "inserter" then
        local unit = entity.unit_number
        local was_enabled = (s.enabled_by_unit[unit] == true)
        local now_enabled = (enabled == true)

        if now_enabled then
            if not was_enabled then
                table.insert(s.enabled_unit_array, unit)
            end
            s.enabled_by_unit[unit] = true
            ensure_correct_filter_settings(entity)
        else
            s.enabled_by_unit[unit] = nil
        end
        return
    end

    -- ghost tags
    local tags = entity.tags or {}
    tags[TAG_KEY] = enabled and true or nil
    entity.tags = tags
end

local function get_enabled(entity)
    local s = state()
    if entity.type == "inserter" then
        return s.enabled_by_unit[entity.unit_number] == true
    end

    -- ghost tags
    local tags = entity.tags
    return tags and tags[TAG_KEY] == true or false
end

local function get_checkbox(player)
    local root = player.gui.relative and player.gui.relative[ROOT_NAME]
    if not (root and root.valid) then
        return nil
    end
    local checkbox = root[CHECKBOX_NAME]
    if checkbox and checkbox.valid then
        return checkbox
    end
    return nil
end

-- create the setting gui for the player if needed
local function ensure_gui(player)
    local relative = player.gui.relative

    if relative[ROOT_NAME] and relative[ROOT_NAME].valid then
        return
    end

    -- Create frame anchored to the inserter GUI
    local frame = relative.add {
        type = "frame",
        name = ROOT_NAME,
        direction = "vertical",
        caption = {"", ""},
        anchor = {
            gui = defines.relative_gui_type.inserter_gui,
            position = defines.relative_gui_position.right,
            ghost_mode = "both"
        }
    }

    frame.add {
        type = "checkbox",
        name = CHECKBOX_NAME,
        caption = {"", "Set filters with quality signals"},
        state = false
    }
end

local function ensure_gui_for_all_players()
    for _, player in pairs(game.players) do
        ensure_gui(player)
    end
end

local function rebuild_enabled_unit_array(s)
    local before_length = #(s.enabled_unit_array or {})

    local array = {}
    for unit, _ in pairs(s.enabled_by_unit) do
        table.insert(array, unit)
    end
    s.enabled_unit_array = array

    local after_length = #array
    if after_length == 0 or s.enabled_index > after_length then
        s.enabled_index = 1
    end

    -- debug_print(("rebuild_enabled_unit_array: before_length=%d after_length=%d enabled_by_unit=%d tick=%d"):format(before_length, after_length, (function()
    --     local c = 0
    --     for _ in pairs(s.enabled_by_unit) do
    --         c = c + 1
    --     end
    --     return c
    -- end)(), game.tick))
end

script.on_init(function()
    update_batch_size()
    local s = state()
    s.open_entity_by_player = {}
    ensure_gui_for_all_players()
    rebuild_enabled_unit_array(s)
end)

script.on_configuration_changed(function()
    update_batch_size()
    local s = state()
    s.open_entity_by_player = {}
    ensure_gui_for_all_players()
    rebuild_enabled_unit_array(s)
end)

script.on_event(defines.events.on_runtime_mod_setting_changed, function(e)
    if e.setting == "ccqf-batch-size" then
        update_batch_size()
    end
end)

script.on_nth_tick(600, function()
    local s = state()

    -- lazy cleanup of fast-replace cache
    local current_tick = game.tick
    for key, rec in pairs(s.recent_replace_by_pos) do
        if (current_tick - rec.tick) > FAST_REPLACE_WINDOW_TICKS then
            s.recent_replace_by_pos[key] = nil
        end
    end

    -- lazy cleanup
    rebuild_enabled_unit_array(s)
end)

-- Create GUI for new players
script.on_event(defines.events.on_player_created, function(e)
    local player = game.get_player(e.player_index)
    if player then
        ensure_gui(player)
    end
end)

-- Whenever an inserter GUI is opened, save which inserter it is and sync checkbox from storage
script.on_event(defines.events.on_gui_opened, function(e)
    local player = game.get_player(e.player_index)
    if not player then
        return
    end

    ensure_gui(player)

    local s = state()
    local entity = e.entity

    if is_inserter_or_ghost_inserter(entity) then
        s.open_entity_by_player[e.player_index] = entity -- save which inserter the player has open

        local checkbox = get_checkbox(player)
        if checkbox then
            checkbox.state = get_enabled(entity) -- sync checkbox setting from saved state
        end
    else
        s.open_entity_by_player[e.player_index] = nil
    end
end)

-- Clear "currently open inserter" when GUI closes
if defines.events.on_gui_closed then
    script.on_event(defines.events.on_gui_closed, function(e)
        local s = state()
        s.open_entity_by_player[e.player_index] = nil
    end)
end

-- Handle checkbox changes and store them per inserter by unit_number
script.on_event(defines.events.on_gui_checked_state_changed, function(e)
    local element = e.element
    if not (element and element.valid and element.name == CHECKBOX_NAME) then
        return
    end

    local s = state()
    local entity = s.open_entity_by_player[e.player_index]
    if not is_inserter_or_ghost_inserter(entity) then
        return
    end

    set_enabled(entity, element.state)
end)

-- Cleanup stored state when inserter is removed to avoid stale entries
local function cleanup_entity(entity)
    if not (entity and entity.valid and entity.unit_number) then
        return
    end
    local s = state()
    s.enabled_by_unit[entity.unit_number] = nil
end

local function pos_key(entity)
    local pos = entity.position
    return string.format("%d:%d:%.3f:%.3f", entity.surface.index, entity.force.index, pos.x, pos.y)
end

local destroy_events = {defines.events.on_player_mined_entity, defines.events.on_robot_mined_entity, defines.events.on_entity_died, defines.events.script_raised_destroy}

script.on_event(destroy_events, function(e)
    local entity = e.entity
    if entity and entity.valid and entity.type == "inserter" and entity.unit_number then
        if get_enabled(entity) then
            local s = state()
            s.recent_replace_by_pos[pos_key(entity)] = {
                enabled = true,
                tick = game.tick
            }
        end
    end

    cleanup_entity(entity)
end)

local build_events = {
    defines.events.on_built_entity, defines.events.on_robot_built_entity, defines.events.on_space_platform_built_entity, defines.events.script_raised_built, defines.events.script_raised_revive
}

script.on_event(build_events, function(e)
    local entity = e.entity
    if not (entity and entity.valid and entity.type == "inserter" and entity.unit_number) then
        return
    end

    local s = state()

    -- blueprint/ghost tags
    if e.tags and e.tags[TAG_KEY] == true then
        set_enabled(entity, true)
        s.recent_replace_by_pos[pos_key(entity)] = nil -- clear any stale cache for this tile
        return
    end

    -- fast-replace cache
    local key = pos_key(entity)
    local rec = s.recent_replace_by_pos[key]
    if rec and (game.tick - rec.tick) <= FAST_REPLACE_WINDOW_TICKS then
        set_enabled(entity, rec.enabled)
        s.recent_replace_by_pos[key] = nil
    end
end)

-- If the player has the same entity open, update the checkbox state
local function sync_checkbox_for_entity(changed_entity)
    local s = state()
    for player_index, open_entity in pairs(s.open_entity_by_player) do
        if not (open_entity and open_entity.valid) then
            s.open_entity_by_player[player_index] = nil
        else
            if open_entity == changed_entity or ((open_entity.unit_number ~= nil) and (changed_entity.unit_number ~= nil) and open_entity.unit_number == changed_entity.unit_number) then
                local player = game.get_player(player_index)
                if player then
                    ensure_gui(player)
                    local checkbox = get_checkbox(player)
                    if checkbox then
                        checkbox.state = get_enabled(changed_entity)
                    end
                end
            end
        end
    end
end

local copy_events = {defines.events.on_entity_settings_pasted, defines.events.on_entity_cloned}

script.on_event(copy_events, function(e)
    local source = e.source
    local destination = e.destination

    if not (is_inserter_or_ghost_inserter(source) and is_inserter_or_ghost_inserter(destination)) then
        return
    end

    local enabled = get_enabled(source)
    set_enabled(destination, enabled)
    sync_checkbox_for_entity(destination)
end)

local function stamp_tags_to_blueprint(player_index, blueprint_stack, mapping_lazy)
    if not (blueprint_stack and blueprint_stack.valid_for_read and blueprint_stack.is_blueprint) then
        return
    end
    if not (mapping_lazy and mapping_lazy.valid) then
        return
    end

    local mapping = mapping_lazy:get()
    if not mapping then
        return
    end

    local entities = blueprint_stack.get_blueprint_entities()
    if not entities then
        return
    end

    for _, be in ipairs(entities) do
        local source = mapping[be.entity_number]
        if source and source.valid and is_inserter_or_ghost_inserter(source) then
            blueprint_stack.set_blueprint_entity_tag(be.entity_number, TAG_KEY, get_enabled(source) and true or nil)
        end
    end
end

script.on_event(defines.events.on_player_setup_blueprint, function(e)
    local player = game.get_player(e.player_index)
    if not player then
        return
    end

    local bp = e.stack
    if not (bp and bp.valid_for_read and bp.is_blueprint) then
        bp = player.cursor_stack
    end
    if not (bp and bp.valid_for_read and bp.is_blueprint) then
        return
    end

    stamp_tags_to_blueprint(e.player_index, bp, e.mapping)
end)

local function read_signal(entity, signal_id)
    local signal = entity.get_signal(signal_id, defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green)
    return signal or 0
end

local function gather_signals(entity)
    local totals = {} -- key -> { signal = SignalID, count = int }

    -- Create keys to merge identical signals
    local function key_for(id)
        local k = tostring(id.type) .. ":" .. tostring(id.name)
        if id.quality ~= nil then
            k = k .. ":" .. tostring(id.quality)
        end
        return k
    end

    local function add_from(connector_id)
        local signals = entity.get_signals(connector_id)
        if not signals then
            return
        end

        for _, s in ipairs(signals) do
            local id = s.signal
            local c = s.count or 0
            if id and c > 0 then
                local k = key_for(id)
                local existing = totals[k]
                if existing then
                    existing.count = existing.count + c
                else
                    totals[k] = {
                        signal = id,
                        count = c
                    }
                end
            end
        end
    end

    add_from(defines.wire_connector_id.circuit_red)
    add_from(defines.wire_connector_id.circuit_green)

    local combined = {} -- { signal = SignalID, count = int }
    for _, v in pairs(totals) do
        combined[#combined + 1] = v
    end
    return combined
end

-- Filter/sort quality signals out of a combined signal list
-- Input: array of { signal = SignalID, count = int }
-- Returns: array of { quality = QualityID, value = int, level = int }
local function extract_quality_signals_sorted(combined_signals)
    local present = {}

    for _, s in ipairs(combined_signals or {}) do
        local id = s.signal
        local c = s.count or 0
        if id and c > 0 then
            -- Support both real quality signals (type="quality") and generated proxy signals
            local qname = nil
            if id.type == "quality" then
                qname = id.name
            elseif id.type == "virtual" and type(id.name) == "string" and id.name:sub(1, #QUALITY_PROXY_PREFIX) == QUALITY_PROXY_PREFIX then
                qname = id.name:sub(#QUALITY_PROXY_PREFIX + 1)
            end

            if qname then
                local q = prototypes.quality[qname]
                if q then
                    present[#present + 1] = {
                        quality = qname,
                        value = c,
                        level = q.level or 0
                    }
                end
            end
        end
    end

    -- sort: signal count desc, then quality tier desc, then name
    table.sort(present, function(a, b)
        if a.value ~= b.value then
            return a.value > b.value
        end
        if a.level ~= b.level then
            return a.level > b.level
        end
        return a.quality < b.quality
    end)

    return present
end

local function is_item_signal(id)
    if not id or not id.name then
        return false
    end
    if id.type == "item" or id.type == "item-with-quality" then
        return true
    end
    return prototypes.item[id.name] ~= nil
end

-- Filter/sort item signals out of a combined signal list
-- Input: array of { signal = SignalID, count = int }
-- Returns: array of { name = string, value = int, order = string }
local function extract_item_signals_sorted(combined_signals)
    local by_name = {}

    for _, s in ipairs(combined_signals or {}) do
        local id = s.signal
        local c = s.count or 0
        if is_item_signal(id) and c > 0 then
            local entry = by_name[id.name]
            if entry then
                entry.value = entry.value + c
            else
                local proto = prototypes.item[id.name]
                by_name[id.name] = {
                    name = id.name,
                    value = c,
                    order = proto and proto.order or ""
                }
            end
        end
    end

    local present = {}
    for _, v in pairs(by_name) do
        present[#present + 1] = v
    end

    -- sort: signal count desc, then item order, then name
    table.sort(present, function(a, b)
        if a.value ~= b.value then
            return a.value > b.value
        end
        if a.order ~= b.order then
            return a.order < b.order
        end
        return a.name < b.name
    end)

    return present
end

-- Returns:
--   comparator :: ComparatorString (e.g. "=", ">", "<", ">=", "<=", "!=")
--   conflict   :: boolean  (true if strongest comparator is tied with another)
local function extract_comparator_signal(signals)
    local MAP = {
        ["signal-greater-than"] = ">",
        ["signal-less-than"] = "<",
        ["signal-equal"] = "=",
        ["signal-greater-than-or-equal-to"] = ">=",
        ["signal-less-than-or-equal-to"] = "<=",
        ["signal-not-equal"] = "!="
    }

    local best = "="
    local best_count = 0
    local conflict = false

    for _, s in ipairs(signals or {}) do
        local id = s.signal
        local c = s.count or 0
        if id and id.type == "virtual" and c > 0 then
            local comparator = MAP[id.name]
            if comparator then
                if c > best_count then
                    best = comparator
                    best_count = c
                    conflict = false
                elseif c == best_count and comparator ~= best then
                    conflict = true
                end
            end
        end
    end

    if best_count == 0 then
        return "=", false
    end

    if conflict then
        return nil, true
    end

    return best, false
end

local function are_filters_equal(a, b)
    if a == nil and b == nil then
        return true
    end
    if a == nil or b == nil then
        return false
    end
    if type(a) == "string" or type(b) == "string" then
        return a == b
    end
    -- ItemFilter table: name/quality/comparator
    return a.name == b.name and a.quality == b.quality and a.comparator == b.comparator
end

-- desired_filters: array of ItemFilter (or nil)
local function apply_inserter_filters(entity, desired_filters)
    if not (entity and entity.valid and entity.type == "inserter") then
        return
    end

    ensure_correct_filter_settings(entity)

    for i = 1, entity.filter_slot_count do
        local want = desired_filters[i]
        local current = entity.get_filter(i)
        if not are_filters_equal(current, want) then
            entity.set_filter(i, want)
        end
    end
end

local function process_enabled_entity(entity)
    local max_slots = entity.filter_slot_count or 0
    if max_slots == 0 then
        return
    end

    local signals = gather_signals(entity)
    local qualities = extract_quality_signals_sorted(signals)
    local items = extract_item_signals_sorted(signals)
    local comparator, conflict = extract_comparator_signal(signals)
    local filters = {}

    -- clear filters if strongest comparator signals are tied
    if conflict then
        apply_inserter_filters(entity, filters)
        return
    end

    -- Build desired filters in sorted order
    if #items > 0 and qualities[1] then
        local slot = 1
        for _, q in ipairs(qualities) do
            for _, it in ipairs(items) do
                filters[slot] = {
                    name = it.name,
                    quality = q.quality,
                    comparator = comparator
                }
                slot = slot + 1
                if slot > max_slots then
                    break
                end
            end
            if slot > max_slots then
                break
            end
        end
    else
        for i, entry in ipairs(qualities) do
            filters[i] = {
                quality = entry.quality,
                comparator = comparator
            }
        end
    end

    apply_inserter_filters(entity, filters)
end

-- loop through enabled entities in batches
script.on_event(defines.events.on_tick, function()
    local s = state()
    local list = s.enabled_unit_array
    local n = #list
    if n == 0 then
        return
    end

    for _ = 1, math.min(BATCH_SIZE, n) do
        -- wrap index position
        if s.enabled_index > n then
            s.enabled_index = 1
        end

        local unit = list[s.enabled_index]
        s.enabled_index = s.enabled_index + 1

        if unit and s.enabled_by_unit[unit] then
            local entity = game.get_entity_by_unit_number(unit)
            if entity and entity.valid and entity.type == "inserter" then
                process_enabled_entity(entity)
            else
                s.enabled_by_unit[unit] = nil -- remove stale entry
            end
        end
    end
end)
