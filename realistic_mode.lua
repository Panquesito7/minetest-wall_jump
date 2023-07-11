--[[
    Realistic Mode (RLM) settings for the Wall Jump mod.
    Copyright (C) 2023 David Leal (halfpacho@gmail.com)

    This library is free software; you can redistribute it and/or
    modify it under the terms of the GNU Lesser General Public
    License as published by the Free Software Foundation; either
    version 2.1 of the License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public
    License along with this library; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
--]]

-- Node template.
-- All default values of each variable are set below.
-- Note: the setting name does not need to be mentioned if not changed.
--[[
    wall_jump.realistic_mode.nodes =
    {
        nodes = "",                     -- List of nodes that will be modified. Can be multiple nodes (use a table!), a group, or an specific node (string).
        exclude_nodes = "",             -- List of nodes that will be excluded from the modification. Can be multiple nodes (use a table!), a group, or an specific node (string).
        jump_height = 6.3,              -- Height of the jump.
        slide_fall_speed = 0.32,        -- Speed at which the player will slide down the wall (higher is slower). Higher values than 0.42 might have unwanted effects.
        slide_horizontal_speed = 0.25,  -- How freely can the player move on Z/X axis when sliding.
        horizontal_speed = 13,          -- Speed given when jumping from a wall to another. Applies only if `same_wall` is disabled.
        wall_jump_amount = 15,          -- The number of wall jumps the player can perform on the given nodes. Set 0 for infinite wall jumps.
        sticky_config = {
            is_sticky = false,          -- If enabled, the player will stick to the wall when jumping to it.
            time = 5,                   -- How long will the player stick to the wall. Set 0 for infinite sticky wall.
            reset_time_on_jump = false  -- If enabled, the player will be able to stick from one wall to another.
                                        -- Else, the sticky time will continue increasing.
        },
        sfx = {
            is_enabled = true,      -- Whether SFX are enabled or not. Disabling this will also disable the default node sounds from being played.
            -- NOTE: By having multiple sounds, the mod will randomly pick one of them and play it on the given event.
            -- For full information and the available values/fields, check out `SimpleSoundSpec` on the Minetest Lua API.
            -- The `object`, `to_player`, and `exclude_player` fields are currently not supported.
            sounds = {
                slide = "",         -- The sounds that will be played when sliding down the wall. Can be multiple sounds (use a table) or a single one (string).
                jump = "",          -- The sounds that will be played when jumping from a wall to another. Can be multiple sounds (use a table) or a single one (string).
                sticky = ""         -- The sounds that will be played when sticking to a wall. Can be multiple sounds (use a table) or a single one (string).
                                    -- NOTE: by default and if not specified, it's the same sound as `jump`.
            },
            config = {              -- Configuration for the sounds. For more information, check out `SimpleSoundSpec` in the Minetest Lua API.
                gain = 1,
                max_hear_distance = 16,
                pitch = 1.0,
                pos = vector.new(0,0,0)
            }
        }
    },
    -- Add more nodes here.
--]]

-- Armor template.
-- All default values of each variable are set below.
-- Note: the setting name does not need to be mentioned if not changed.
--[[
    wall_jump.realistic_mode.armor =
    {
        armor = "",                     -- List of armors that will be modified (for example: `wood`). Can be multiple armors (use a table!) or a single one (string).
        jump_height = 6.3,              -- Height of the jump.
        slide_fall_speed = 0.32,        -- Speed at which the player will slide down the wall (higher is slower). Higher values than 0.42 might have unwanted effects.
        slide_horizontal_speed = 0.25,  -- How freely can the player move on Z/X axis when sliding.
        horizontal_speed = 13,          -- Speed given when jumping from a wall to another. Applies only if `same_wall` is disabled.
    }
--]]

-- Add your configurations here.

-- Node settings.
wall_jump.realistic_mode.nodes = { }

-- 3D Armor settings.
wall_jump.realistic_mode.armor = { }

local realistic_mode = minetest.settings:get_bool("wall_jump.rlm") or true -- FALSE BY DEFAULT!
local mode_only = minetest.settings:get("wall_jump.rlm.only_mode") or "both"

local keep_def_settings = minetest.settings:get_bool("wall_jump.rlm.keep_default_settings") or true
local armor_effects = minetest.global_exists("armor") and minetest.settings:get_bool("wall_jump.rlm.armor_effects") or true

local modified_values = { } -- Whether the RLM values have been modified due to the armor or not.
local original_values = { } -- Original RLM values.

--- @brief Small helper function to check
--- if a table contains the given element.
--- @param table table the table that will be checked
--- @param element string the element that will be searched for
--- @return boolean true if the table contains the element
--- @return boolean false if the table does NOT contain the element
local function table_contains(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

--- @brief Initializes the realistic mode (RLM) settings.
--- @details Realistic mode consists of having different slide speeds, amount of wall jumps, and other values
--- depending on the node where the player wants to wall jump on. If enabled, the mod will take the default values.
--- NOTE: The default settings below will be added to the settings above if `keep_def_settings` is true.
--- @return nil
function wall_jump.realistic_mode.init()
    -- Is RLM enabled?
    if realistic_mode ~= true then
        minetest.log("info", "[WALL JUMP] Realistic Mode (RLM) is disabled. Not applying extra effects/settings.")
        wall_jump.realistic_mode.armor = { }
        wall_jump.realistic_mode.nodes = { }

        return
    end

    -- Armor.
    if armor_effects and (mode_only == "both" or mode_only == "armor") then
        if #wall_jump.realistic_mode.armor == 0 then
            minetest.log("action", "[WALL JUMP] Realistic mode is enabled, but no settings were found. Armor effects won't be applied.")
            armor_effects = false
        end
    end

    -- Nodes.
    if (mode_only == "both" or mode_only == "node") and keep_def_settings ~= false then
        if (minetest.get_modpath("default") or minetest.get_modpath("wool"))
            and #wall_jump.realistic_mode.nodes == 0 then
            minetest.log("action", "[WALL JUMP] Realistic mode is enabled, but no settings were found. Using default settings (nodes).")
        end

        -- Settings for various `default` nodes.
        if minetest.get_modpath("default") then
            table.insert(wall_jump.realistic_mode.nodes, {
                -- Basic.
                {
                    nodes = "group:soil",
                    exclude_nodes = { "default:ice", "default:snow", "default:snowblock", "default:cave_ice" },
                    jump_height = 6,
                    slide_fall_speed = 0.35,
                    wall_jump_amount = 17,
                },
                {
                    nodes = "group:stone",
                    jump_height = 6.5,
                    slide_fall_speed = 0.36,
                    slide_horizontal_speed = 0.33,
                },
                {
                    nodes = { "default:ice", "default:snow", "default:snowblock", "default:cave_ice" },
                    jump_height = 5.75,
                    slide_fall_speed = 0.25,
                    slide_horizontal_speed = 0.38
                },
                {
                    nodes = "group:tree",
                    jump_height = 6.57,
                    slide_fall_speed = 0.38,
                    slide_horizontal_speed = 0.21,
                    horizontal_speed = 13.25,
                    sticky_config = {
                        is_sticky = true,
                        sticky_time = 4.5,
                        reset_time_on_jump = true
                    },
                    wall_jump_amount = 19
                },
                -- Miscellaneous.
                {
                    nodes = "default:cactus",
                    slide_fall_speed = 0.36,
                    slide_horizontal_speed = 0.14,
                    wall_jump_amount = 8,
                },
                {
                    nodes = "group:leaves",
                    jump_height = 6,
                    slide_horizontal_speed = 0.32,
                    wall_jump_amount = 19,
                },
                {
                    nodes = { "default:glass", "default:obsidian_glass", "default:meselamp" },
                    jump_height = 7.6,
                    slide_fall_speed = 0.28,
                    horizontal_speed = 11.2,
                    wall_jump_amount = 20
                },
                {
                    nodes = "default:brick",
                    jump_height = 6.7,
                    slide_fall_speed = 0.4,
                    slide_horizontal_speed = 0.17,
                    horizontal_speed = 12.25
                },
                {
                    nodes = "default:bookshelf",
                    jump_height = 6,
                    slide_horizontal_speed = 0.1
                }
            })
        end

        -- Doors.
        if minetest.get_modpath("doors") then
            table.insert(wall_jump.realistic_mode.nodes, {
                {
                    nodes = "doors:door_wood",
                    jump_height = 6.54,
                    slide_fall_speed = 0.35,
                    wall_jump_amount = 18
                },
                {
                    nodes = "doors:door_steel",
                    jump_height = 5.9,
                    slide_fall_speed = 0.41
                },
                {
                    nodes = "doors:door_glass",
                    jump_height = 5.56,
                    slide_fall_speed = 0.28,
                    horizontal_speed = 11,
                    wall_jump_amount = 18
                },
                {
                    nodes = "doors:door_obsidian_glass",
                    jump_height = 6,
                    horizontal_speed = 13.5
                }
            })
        end

        -- Wool.
        if minetest.get_modpath("wool") then
            table.insert(wall_jump.realistic_mode.nodes, {
                {
                    nodes = "group:wool",
                    jump_height = 6.7,
                    slide_fall_speed = 0.41,
                    slide_horziontal_speed = 0.18,
                    wall_jump_amount = 24
                }
            })
        end
    end
end

--- @brief Gets the settings for the given node.
--- @param node_name string The name of the node.
--- @return table settings the settings for the given node
--- @todo Make sure the exclude nodes thing work.
function wall_jump.realistic_mode.get_settings(node_name)
    for _, node_settings in ipairs(wall_jump.realistic_mode.nodes) do
        for _, node in ipairs(node_settings) do
            if type(node.nodes) == "string" then
                local no_group = node.nodes:gsub("group:", "") or ""
                if node.nodes == node_name or minetest.get_item_group(node_name, no_group) > 0 then
                    return node
                end
            elseif type(node.nodes) == "table" then
                for _, name in ipairs(node.nodes) do
                    local no_group = name:gsub("group:", "") or ""
                    if name == node_name or minetest.get_item_group(node_name, no_group) > 0 then
                        return node
                    end
                end
            end
        end
    end

    return { }
end

--- @brief Small helper function that resets
--- the modified RLM values to its original values.
--- @param player userdata the player that will be checked
--- @param settings table the settings that will be reset
local function reset(player, settings)
    if modified_values[player] then
        -- Restore the original values.
        for key, value in pairs(original_values[player]) do
            settings[key] = value
        end
    end
end

--- @brief Checks whether the given armor material exists.
--- @param name string the name of the armor material
--- @return boolean true if the armor material exists
--- @return boolean false if the armor material does NOT exist
local function armor_exists(name)
    if armor.materials[name] then
        return true
    end
    return false
end

--- @brief Mixes the armor values with the node settings. The average of both will be used.
--- @details
---
--- Minor example:
--- If the node `default:ice` has its own values in `wall_jump.realistic_mode.nodes`, and
--- the player is wearing a wood armor, which also has its own values, then the average of the two values should be used.
--- Make sure to take a reference of how `wall_jump.realistic_mode.armor` is structured.
--- @param player userdata the player that will be checked
--- @param settings table the settings for the given node
--- @param node_name string the name of the node
--- @return table settings the mixed settings
function wall_jump.realistic_mode.mix_armor_node_values(player, settings, node_name)
    if not armor_effects or #wall_jump.realistic_mode.armor == 0 then
        reset(player, settings)
        return settings
    end

    -- Does the player have armor?
    local _, armor_inv = armor:get_valid_player(player, "3d_armor")
    local armor_names = {}
    for i = 1, 6 do
        local name = armor_inv:get_stack("armor", i):get_name()
        if name ~= "" then
            table.insert(armor_names, name)
        end
    end

    if #armor_names == 0 and modified_values[player] then
        reset(player, settings)
    end

    -- Initialize.
    if modified_values[player] then
        return settings
    elseif modified_values[player] == nil then
        modified_values[player] = false
    end

    local new_settings = settings
    local template = {
        "3d_armor:chestplate_",
        "3d_armor:boots_",
        "3d_armor:helmet_",
        "3d_armor:leggings_"
    }

    for _,armor_def in ipairs(wall_jump.realistic_mode.armor) do
        if type(armor_def.armor) == "string" then
            if armor_exists(armor_def.armor) ~= true then return settings end -- Safety check.
            for _, values in ipairs(template) do
                if table_contains(armor_names, values .. armor_def.armor) then
                    -- Get the values from the node that the player is standing on.
                    local node_settings = wall_jump.realistic_mode.get_settings(node_name)

                    -- Mix the values.
                    for key, value in pairs(node_settings) do
                        if type(value) == "number" then
                            -- Are the values very similar? If so, keep it as-is.
                            if math.abs(value - (armor_def[key] or 0)) < 0.1 then
                                goto continue
                            end

                            -- Save a copy of the original values.
                            if not original_values[player] then
                                original_values[player] = table.copy(settings)
                            end

                            new_settings[key] = (value + (armor_def[key] or 0)) / 2
                            modified_values[player] = true

                            ::continue::
                        end
                    end
                end
            end
        elseif type(armor_def.armor) == "table" then
            for _, armor in ipairs(armor_def.armor) do
                if armor_exists(armor) ~= true then return settings end -- Safety check.
                for _, values in ipairs(template) do
                    if table_contains(armor_names, values .. armor) then
                        -- Get the values from the node that the player is standing on.
                        local node_settings = wall_jump.realistic_mode.get_settings(node_name)

                        -- Mix the values.
                        for key, value in pairs(node_settings) do
                            if type(value) == "number" then
                                -- Are the values very similar? If so, keep it as-is.
                                if math.abs(value - (armor_def[key] or 0)) < 0.1 then
                                    goto continue
                                end

                                -- Save a copy of the original values.
                                if not original_values[player] then
                                    original_values[player] = table.copy(settings)
                                end

                                new_settings[key] = (value + (armor_def[key] or 0)) / 2
                                modified_values[player] = true

                                ::continue::
                            end
                        end
                    end
                end
            end
        end
    end

    return new_settings
end

minetest.register_on_mods_loaded(function()
    wall_jump.realistic_mode.init() -- Initialize RLM.
end)
