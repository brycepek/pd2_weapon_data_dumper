-- PD2 Weapon Data Dumper v3
-- Dumps weapon data, weapon stat mapping tables, stats_modifiers, factory data,
-- blackmarket mod metadata, blackmarket keys, DLC/achievement unlock mappings,
-- and localization strings needed for a PAYDAY 2 weapon-builder app.

local MOD_NAME = "PD2WeaponDataDumper"
local OUTPUT_DIR = "mods/pd2_weapon_data_dumper/"

local function dumper_log(message)
    log("[" .. MOD_NAME .. "] " .. tostring(message))
end

local function is_plain_array(tbl)
    if type(tbl) ~= "table" then
        return false
    end

    local count = 0
    local max_index = 0

    for key, _ in pairs(tbl) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
            return false
        end

        count = count + 1

        if key > max_index then
            max_index = key
        end
    end

    return count == max_index
end

local function sanitize_for_json(value, depth, stack)
    depth = depth or 0
    stack = stack or {}

    if depth > 40 then
        return "<max_depth_reached>"
    end

    local value_type = type(value)

    if value_type == "nil" then
        return nil
    end

    if value_type == "string" or value_type == "number" or value_type == "boolean" then
        return value
    end

    if value_type == "function" or value_type == "thread" then
        return nil
    end

    if value_type == "userdata" then
        return tostring(value)
    end

    if value_type ~= "table" then
        return tostring(value)
    end

    if stack[value] then
        return "<cycle>"
    end

    stack[value] = true

    local output = {}

    if is_plain_array(value) then
        for index = 1, #value do
            local sanitized_value = sanitize_for_json(value[index], depth + 1, stack)

            if sanitized_value == nil then
                output[index] = "<unsupported>"
            else
                output[index] = sanitized_value
            end
        end
    else
        for key, child_value in pairs(value) do
            local sanitized_key = tostring(key)
            local sanitized_value = sanitize_for_json(child_value, depth + 1, stack)

            if sanitized_value ~= nil then
                output[sanitized_key] = sanitized_value
            end
        end
    end

    stack[value] = nil

    return output
end

local function save_json(filename, data)
    local path = OUTPUT_DIR .. filename
    local cleaned_data = sanitize_for_json(data)

    dumper_log("Saving " .. path)

    local ok, result = pcall(function()
        return io.save_as_json(cleaned_data, path)
    end)

    if not ok then
        dumper_log("ERROR while saving " .. filename .. ": " .. tostring(result))
        return false
    end

    dumper_log("Saved " .. filename)
    return true
end

local function table_keys(tbl)
    local keys = {}

    if type(tbl) ~= "table" then
        return keys
    end

    for key, _ in pairs(tbl) do
        table.insert(keys, tostring(key))
    end

    table.sort(keys)
    return keys
end

local function is_real_weapon_entry(weapon_data)
    return type(weapon_data) == "table"
        and type(weapon_data.stats) == "table"
        and type(weapon_data.categories) == "table"
end

local function extract_base_weapons()
    local result = {}

    for weapon_id, weapon_data in pairs(tweak_data.weapon or {}) do
        if is_real_weapon_entry(weapon_data) then
            result[tostring(weapon_id)] = weapon_data
        end
    end

    return result
end

local function extract_weapon_tweak_data_without_factory()
    local result = {}

    for key, value in pairs(tweak_data.weapon or {}) do
        -- weapon_factory.json already dumps this separately.
        if key ~= "factory" then
            result[tostring(key)] = value
        end
    end

    return result
end

local function extract_weapon_stats_modifiers()
    local result = {}

    for weapon_id, weapon_data in pairs(tweak_data.weapon or {}) do
        if is_real_weapon_entry(weapon_data) then
            result[tostring(weapon_id)] = {
                name_id = weapon_data.name_id,
                desc_id = weapon_data.desc_id,
                categories = weapon_data.categories,
                raw_stats = weapon_data.stats,
                stats_modifiers = weapon_data.stats_modifiers or {}
            }
        end
    end

    return result
end

local function get_stat_table_value(stat_name, raw_index)
    if not tweak_data.weapon or not tweak_data.weapon.stats then
        return nil
    end

    local stat_table = tweak_data.weapon.stats[stat_name]

    if type(stat_table) ~= "table" then
        return nil
    end

    if raw_index == nil then
        return nil
    end

    return stat_table[raw_index]
end

local function extract_weapon_stat_debug()
    local result = {}

    for weapon_id, weapon_data in pairs(tweak_data.weapon or {}) do
        if is_real_weapon_entry(weapon_data) then
            local raw_stats = weapon_data.stats or {}
            local modifiers = weapon_data.stats_modifiers or {}

            local raw_damage = raw_stats.damage
            local raw_suppression = raw_stats.suppression
            local raw_spread = raw_stats.spread
            local raw_recoil = raw_stats.recoil
            local raw_concealment = raw_stats.concealment
            local raw_alert_size = raw_stats.alert_size
            local raw_reload = raw_stats.reload
            local raw_zoom = raw_stats.zoom
            local raw_value = raw_stats.value
            local raw_extra_ammo = raw_stats.extra_ammo
            local raw_total_ammo_mod = raw_stats.total_ammo_mod

            local mapped_damage = get_stat_table_value("damage", raw_damage) or raw_damage
            local mapped_suppression = get_stat_table_value("suppression", raw_suppression)
            local mapped_spread = get_stat_table_value("spread", raw_spread) or raw_spread
            local mapped_recoil = get_stat_table_value("recoil", raw_recoil) or raw_recoil
            local mapped_concealment = get_stat_table_value("concealment", raw_concealment) or raw_concealment
            local mapped_alert_size = get_stat_table_value("alert_size", raw_alert_size)
            local mapped_reload = get_stat_table_value("reload", raw_reload)
            local mapped_zoom = get_stat_table_value("zoom", raw_zoom)
            local mapped_value = get_stat_table_value("value", raw_value)
            local mapped_extra_ammo = get_stat_table_value("extra_ammo", raw_extra_ammo)
            local mapped_total_ammo_mod = get_stat_table_value("total_ammo_mod", raw_total_ammo_mod)

            local damage_modifier = modifiers.damage or 1
            local suppression_modifier = modifiers.suppression or 1
            local spread_modifier = modifiers.spread or 1
            local recoil_modifier = modifiers.recoil or 1
            local alert_size_modifier = modifiers.alert_size or 1

            local display_damage = nil
            if mapped_damage ~= nil then
                display_damage = mapped_damage * damage_modifier
            end

            local runtime_suppression = nil
            local display_threat = nil
            if mapped_suppression ~= nil then
                runtime_suppression = mapped_suppression * suppression_modifier
                display_threat = runtime_suppression - 2
            end

            local display_accuracy = nil
            if mapped_spread ~= nil then
                display_accuracy = ((mapped_spread * spread_modifier) * 4) - 4
            end

            local display_stability = nil
            if mapped_recoil ~= nil then
                display_stability = ((mapped_recoil * recoil_modifier) * 4) - 4
            end

            result[tostring(weapon_id)] = {
                name_id = weapon_data.name_id,
                desc_id = weapon_data.desc_id,
                categories = weapon_data.categories,

                raw_stats = {
                    damage = raw_damage,
                    suppression = raw_suppression,
                    spread = raw_spread,
                    recoil = raw_recoil,
                    concealment = raw_concealment,
                    alert_size = raw_alert_size,
                    reload = raw_reload,
                    zoom = raw_zoom,
                    value = raw_value,
                    extra_ammo = raw_extra_ammo,
                    total_ammo_mod = raw_total_ammo_mod
                },

                mapped_stats = {
                    damage = mapped_damage,
                    suppression = mapped_suppression,
                    spread = mapped_spread,
                    recoil = mapped_recoil,
                    concealment = mapped_concealment,
                    alert_size = mapped_alert_size,
                    reload = mapped_reload,
                    zoom = mapped_zoom,
                    value = mapped_value,
                    extra_ammo = mapped_extra_ammo,
                    total_ammo_mod = mapped_total_ammo_mod
                },

                stats_modifiers = {
                    damage = damage_modifier,
                    suppression = suppression_modifier,
                    spread = spread_modifier,
                    recoil = recoil_modifier,
                    alert_size = alert_size_modifier,
                    original = modifiers
                },

                approximate_display_stats = {
                    damage = display_damage,
                    threat = display_threat,
                    runtime_suppression = runtime_suppression,
                    accuracy = display_accuracy,
                    stability = display_stability,
                    concealment = mapped_concealment
                }
            }
        end
    end

    return result
end

local function split_weapon_factory()
    local factory_weapons = {}
    local factory_parts = {}
    local factory_other = {}

    for factory_id, factory_data in pairs(tweak_data.weapon.factory or {}) do
        if type(factory_data) == "table" then
            if factory_data.default_blueprint or factory_data.uses_parts then
                factory_weapons[tostring(factory_id)] = factory_data
            elseif factory_data.type or factory_data.stats or factory_data.name_id then
                factory_parts[tostring(factory_id)] = factory_data
            else
                factory_other[tostring(factory_id)] = factory_data
            end
        else
            factory_other[tostring(factory_id)] = factory_data
        end
    end

    return factory_weapons, factory_parts, factory_other
end

local function collect_localization_ids(value, output, depth, stack)
    depth = depth or 0
    stack = stack or {}

    if depth > 30 then
        return
    end

    if type(value) ~= "table" then
        return
    end

    if stack[value] then
        return
    end

    stack[value] = true

    for key, child_value in pairs(value) do
        if type(child_value) == "string" then
            if key == "name_id"
                or key == "desc_id"
                or key == "description_id"
                or key == "achievement_id"
                or key == "challenge_id"
                or key == "text_id"
                or key == "unlock_id"
            then
                output[child_value] = true
            end
        elseif type(child_value) == "table" then
            collect_localization_ids(child_value, output, depth + 1, stack)
        end
    end

    stack[value] = nil
end

local function build_localization_dump()
    local id_set = {}

    collect_localization_ids(tweak_data.weapon, id_set)
    collect_localization_ids(tweak_data.weapon.factory, id_set)

    if tweak_data.blackmarket then
        collect_localization_ids(tweak_data.blackmarket.weapon_mods, id_set)
        collect_localization_ids(tweak_data.blackmarket.weapons, id_set)
    end

    if tweak_data.dlc then
        collect_localization_ids(tweak_data.dlc, id_set)
    end

    if tweak_data.achievement then
        collect_localization_ids(tweak_data.achievement, id_set)
    end

    local result = {}

    for localization_id, _ in pairs(id_set) do
        local ok, localized_text = pcall(function()
            return managers.localization:text(localization_id)
        end)

        if ok and localized_text then
            result[localization_id] = localized_text
        else
            result[localization_id] = localization_id
        end
    end

    return result
end

local function get_localized_text_or_id(localization_id)
    if not localization_id then
        return nil
    end

    if not managers or not managers.localization then
        return localization_id
    end

    local ok, localized_text = pcall(function()
        return managers.localization:text(localization_id)
    end)

    if ok and localized_text then
        return localized_text
    end

    return localization_id
end

local function extract_dlc_tweak_data()
    return tweak_data.dlc or {}
end

local function extract_achievement_tweak_data()
    return tweak_data.achievement or {}
end

local function add_unlock_entry(unlocks_by_item_type, item_type, item_entry, unlock_data)
    if not item_type or not item_entry then
        return
    end

    local item_type_key = tostring(item_type)
    local item_entry_key = tostring(item_entry)

    unlocks_by_item_type[item_type_key] = unlocks_by_item_type[item_type_key] or {}
    unlocks_by_item_type[item_type_key][item_entry_key] = unlocks_by_item_type[item_type_key][item_entry_key] or {}

    table.insert(unlocks_by_item_type[item_type_key][item_entry_key], unlock_data)
end

local function extract_unlock_mappings_from_dlc()
    local result = {
        by_item_type = {},
        packages = {}
    }

    if type(tweak_data.dlc) ~= "table" then
        return result
    end

    for package_id, package_data in pairs(tweak_data.dlc) do
        if type(package_data) == "table" then
            local package_key = tostring(package_id)

            local package_unlock = {
                package_id = package_key,
                free = package_data.free,
                dlc = package_data.dlc,
                app_id = package_data.app_id,
                no_install = package_data.no_install,
                content = package_data.content,

                achievement_id = package_data.achievement_id,
                achievement = package_data.achievement,
                achievement_visual = package_data.achievement_visual,

                milestone_id = package_data.milestone_id,
                milestone = package_data.milestone,

                stat_id = package_data.stat_id,
                stat = package_data.stat,
                stat_value = package_data.stat_value,

                source_data = package_data
            }

            result.packages[package_key] = package_unlock

            if package_data.content and type(package_data.content.loot_drops) == "table" then
                for _, loot_drop in pairs(package_data.content.loot_drops) do
                    if type(loot_drop) == "table" then
                        local item_type = loot_drop.type_items
                        local item_entry = loot_drop.item_entry

                        local unlock_data = {
                            package_id = package_key,
                            item_type = item_type,
                            item_entry = item_entry,
                            amount = loot_drop.amount,
                            global_value = loot_drop.global_value,

                            achievement_id = package_data.achievement_id,
                            achievement = package_data.achievement,
                            achievement_visual = package_data.achievement_visual,

                            milestone_id = package_data.milestone_id,
                            milestone = package_data.milestone,

                            stat_id = package_data.stat_id,
                            stat = package_data.stat,
                            stat_value = package_data.stat_value,

                            free = package_data.free,
                            dlc = package_data.dlc,
                            app_id = package_data.app_id,
                            no_install = package_data.no_install,

                            raw_loot_drop = loot_drop
                        }

                        add_unlock_entry(result.by_item_type, item_type, item_entry, unlock_data)
                    end
                end
            end
        end
    end

    return result
end

local function extract_weapon_mod_unlocks()
    local result = {}
    local unlock_mappings = extract_unlock_mappings_from_dlc()

    if unlock_mappings.by_item_type.weapon_mods then
        result.weapon_mods = unlock_mappings.by_item_type.weapon_mods
    else
        result.weapon_mods = {}
    end

    return result
end

local function extract_achievement_unlock_debug()
    local result = {}
    local unlock_mappings = extract_unlock_mappings_from_dlc()

    for item_type, item_entries in pairs(unlock_mappings.by_item_type or {}) do
        result[item_type] = result[item_type] or {}

        for item_entry, unlock_entries in pairs(item_entries) do
            result[item_type][item_entry] = {}

            for _, unlock_entry in ipairs(unlock_entries) do
                local achievement_id = unlock_entry.achievement_id
                local achievement_name_id = nil
                local achievement_desc_id = nil

                if achievement_id then
                    achievement_name_id = "achievement_" .. tostring(achievement_id)
                    achievement_desc_id = "achievement_" .. tostring(achievement_id) .. "_desc"
                end

                table.insert(result[item_type][item_entry], {
                    package_id = unlock_entry.package_id,
                    item_type = unlock_entry.item_type,
                    item_entry = unlock_entry.item_entry,

                    achievement_id = achievement_id,
                    achievement_name_id = achievement_name_id,
                    achievement_desc_id = achievement_desc_id,
                    achievement_name = get_localized_text_or_id(achievement_name_id),
                    achievement_description = get_localized_text_or_id(achievement_desc_id),

                    milestone_id = unlock_entry.milestone_id,
                    stat_id = unlock_entry.stat_id,
                    stat_value = unlock_entry.stat_value,

                    free = unlock_entry.free,
                    dlc = unlock_entry.dlc,
                    app_id = unlock_entry.app_id
                })
            end
        end
    end

    return result
end

local function dump_weapon_data()
    if not tweak_data then
        dumper_log("Waiting for tweak_data...")
        return false
    end

    if not tweak_data.weapon then
        dumper_log("Waiting for tweak_data.weapon...")
        return false
    end

    if not tweak_data.weapon.factory then
        dumper_log("Waiting for tweak_data.weapon.factory...")
        return false
    end

    if not tweak_data.blackmarket then
        dumper_log("Waiting for tweak_data.blackmarket...")
        return false
    end

    if not managers or not managers.localization then
        dumper_log("Waiting for managers.localization...")
        return false
    end

    dumper_log("Data appears ready. Starting dump.")

    local factory_weapons, factory_parts, factory_other = split_weapon_factory()
    local base_weapons = extract_base_weapons()
    local unlock_mappings = extract_unlock_mappings_from_dlc()

    -- Existing app-friendly base weapon dump.
    save_json("weapon_base_stats.json", base_weapons)

    -- Aliases with simpler names, so your app can use whichever name you prefer.
    save_json("base_weapons.json", base_weapons)
    save_json("weapons.json", base_weapons)

    -- Full weapon tweak dump, excluding factory because weapon_factory.json already handles that.
    -- This includes global tables like tweak_data.weapon.stats.
    save_json("weapon_tweak_data.json", extract_weapon_tweak_data_without_factory())

    -- Important raw stat mapping tables:
    -- damage, spread, recoil, suppression, alert_size, zoom, reload, value, etc.
    save_json("weapon_stats_tables.json", tweak_data.weapon.stats or {})

    -- Dedicated per-weapon stats_modifiers dump.
    save_json("weapon_stats_modifiers.json", extract_weapon_stats_modifiers())

    -- Small debug-friendly version for checking displayed stat math.
    save_json("weapon_stat_debug.json", extract_weapon_stat_debug())

    -- Original full factory dump.
    save_json("weapon_factory.json", tweak_data.weapon.factory)

    -- Cleaner split files for our app.
    save_json("factory_weapons.json", factory_weapons)
    save_json("factory_parts.json", factory_parts)
    save_json("factory_other.json", factory_other)

    if tweak_data.blackmarket.weapon_mods then
        save_json("blackmarket_weapon_mods.json", tweak_data.blackmarket.weapon_mods)
    else
        dumper_log("WARNING: tweak_data.blackmarket.weapon_mods was nil")
    end

    -- Diagnostic: this tells us what actually exists under tweak_data.blackmarket.
    save_json("blackmarket_keys.json", table_keys(tweak_data.blackmarket))

    if tweak_data.blackmarket.weapons then
        save_json("blackmarket_weapons.json", tweak_data.blackmarket.weapons)
    else
        save_json("blackmarket_weapons_missing.json", {
            exists = false,
            note = "tweak_data.blackmarket.weapons was nil at runtime. This is probably not needed; weapon data is in tweak_data.weapon."
        })
    end

    -- Raw DLC and achievement tables. Useful for unlock logic.
    if tweak_data.dlc then
        save_json("dlc_tweak_data.json", extract_dlc_tweak_data())
    else
        save_json("dlc_tweak_data_missing.json", {
            exists = false,
            note = "tweak_data.dlc was nil at runtime."
        })
    end

    if tweak_data.achievement then
        save_json("achievement_tweak_data.json", extract_achievement_tweak_data())
    else
        save_json("achievement_tweak_data_missing.json", {
            exists = false,
            note = "tweak_data.achievement was nil at runtime."
        })
    end

    -- Processed unlock mappings from tweak_data.dlc content.loot_drops.
    save_json("unlock_mappings.json", unlock_mappings)
    save_json("weapon_mod_unlocks.json", extract_weapon_mod_unlocks())
    save_json("achievement_unlock_debug.json", extract_achievement_unlock_debug())

    -- Localization IDs collected from weapons, factory, blackmarket, DLC, and achievements.
    save_json("localization.json", build_localization_dump())

    save_json("dump_summary.json", {
        generated_by = MOD_NAME,
        version = "v3",
        note = "Generated from live PAYDAY 2 tweak_data at runtime.",
        useful_files_for_app = {
            "weapon_base_stats.json",
            "base_weapons.json",
            "weapons.json",
            "weapon_tweak_data.json",
            "weapon_stats_tables.json",
            "weapon_stats_modifiers.json",
            "weapon_stat_debug.json",
            "weapon_factory.json",
            "factory_weapons.json",
            "factory_parts.json",
            "factory_other.json",
            "blackmarket_weapon_mods.json",
            "blackmarket_keys.json",
            "blackmarket_weapons.json",
            "dlc_tweak_data.json",
            "achievement_tweak_data.json",
            "unlock_mappings.json",
            "weapon_mod_unlocks.json",
            "achievement_unlock_debug.json",
            "localization.json"
        },
        stat_formula_notes = {
            accuracy = "(mappedSpreadTotal * 4) - 4, then clamp 0 - 100",
            stability = "(mappedRecoilTotal * 4) - 4, then clamp 0 - 100",
            damage = "mappedDamageTotal * stats_modifiers.damage",
            threat = "(mappedSuppressionTotal * stats_modifiers.suppression) - 2, then clamp 0 - 43"
        }
    })

    dumper_log("DONE. Weapon data dump completed.")
    return true
end

if dump_weapon_data() then
    PD2WeaponDataDumperDone = true
end