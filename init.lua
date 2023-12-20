--[[
    Gives the player advanced wall jump abilities. Highly customizable providing a lot of configurations. Built for Minetest.
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

wall_jump = {
    realistic_mode = { } -- Defined in `realistic_mode.lua`.
}

local player_physics = {
    sticky_time = { },      -- How long the player has been stickied to a wall.
    is_jumping = { },       -- Whether the player is holding the jump button or not.
    walljump_count = { },   -- How many wall jumps has the player performed. Resets when the player touches the ground.
    slide_time = { },       -- Delay before the player can properly slide (`slide_delay`).
    jump_time = { }         -- Delay between jumps to prevent going high very quickly (`jump_delay`).
}

local sounds = {
    sticky_has_played = { },   -- Whether the sticky sound has been played or not.
    slide_sound_id = { },      -- The sound ID of the slide sound per player.
    slide_has_played = { }     -- Whether the slide sound has been played or not.
}

---------------
-- Settings --
---------------

-- All settings are described in `settingtypes.txt` and in the `README.md` file.

-- Booleans/basics
local same_wall = minetest.settings:get_bool("wall_jump.same_wall") or false
local slide_delay = tonumber(minetest.settings:get("wall_jump.slide_delay")) or 0.13
local jump_delay = tonumber(minetest.settings:get("wall_jump.jump_delay")) or 0.13
local show_particles = minetest.settings:get_bool("wall_jump.show_particles") or true

-- Numbers
-- Note: these values are overriden by their specific node configuration in `realistic_mode.lua`.
local jump_height = tonumber(minetest.settings:get("wall_jump.jump_height")) or 6.3
local slide_fall_speed = tonumber(minetest.settings:get("wall_jump.slide_fall_speed")) or 0.32 -- Higher values than 0.42 might have unwanted effects.
local slide_horizontal_speed = tonumber(minetest.settings:get("wall_jump.slide_horizontal_speed")) or 0.2
local horizontal_speed = tonumber(minetest.settings:get("wall_jump.horizontal_speed")) or 13
local wall_jump_amount = tonumber(minetest.settings:get("wall_jump.wall_jump_amount")) or 15

-------------
-- Models --
-------------

-- Currently supports vanilla model only.
-- 3D Armor and SkinsDB support will be added soon.
player_api.register_model("character_wj.b3d", {
	animation_speed = 30,
	textures = {"character.png"},
	animations = {
		stand     = {x = 0,   y = 79},
		lay       = {x = 162, y = 166, eye_height = 0.3, override_local = true,
			collisionbox = {-0.6, 0.0, -0.6, 0.6, 0.3, 0.6}},
		walk      = {x = 168, y = 187},
		mine      = {x = 189, y = 198},
		walk_mine = {x = 200, y = 219},
		sit       = {x = 81,  y = 160, eye_height = 0.8, override_local = true,
			collisionbox = {-0.3, 0.0, -0.3, 0.3, 1.0, 0.3}},
        slide_right_animated    = {x = 221, y = 235, override_local = true,
            collisionbox = {-0.42, 0.0, -0.42, 0.42, 1.7, 0.42}},
        slide_left_animated    = {x = 236, y = 250, override_local = true,
            collisionbox = {-0.42, 0.0, -0.42, 0.42, 1.7, 0.42}},
        slide_right = {x = 235, y = 235, override_local = true,
            collisionbox = {-0.42, 0.0, -0.42, 0.42, 1.7, 0.42}},
        slide_left = {x = 250, y = 250, override_local = true,
            collisionbox = {-0.42, 0.0, -0.42, 0.42, 1.7, 0.42}},
	},
})

minetest.register_on_joinplayer(function(player)
    player_api.set_model(player, "character_wj.b3d")
end)

local play_animated_right = { } -- Whether to play the right sliding animation or not.
local play_animated_left = { } -- Whether to play the left sliding animation or not.

--------------------
-- Realistic mode --
--------------------

dofile(minetest.get_modpath(minetest.get_current_modname()) .. "/realistic_mode.lua")

----------------------
-- Normal functions --
----------------------

--- @brief Initializes all the `player_physics` arrays.
--- @param player userdata the player whose values will be initialized
--- @return nil
local function initialize(player)
    if player_physics.sticky_time[player:get_player_name()] == nil then
        player_physics.sticky_time[player:get_player_name()] = 0
    end

    if player_physics.walljump_count[player:get_player_name()] == nil then
        player_physics.walljump_count[player:get_player_name()] = 0
    end

    if player_physics.slide_time[player:get_player_name()] == nil then
        player_physics.slide_time[player:get_player_name()] = 0
    end

    if player_physics.jump_time[player:get_player_name()] == nil then
        player_physics.jump_time[player:get_player_name()] = jump_delay
    end

    if player_physics.is_jumping[player:get_player_name()] == nil then
        player_physics.is_jumping[player:get_player_name()] = false
    end

    if sounds.sticky_has_played[player:get_player_name()] == nil then
        sounds.sticky_has_played[player:get_player_name()] = false
    end

    if sounds.slide_sound_id[player:get_player_name()] == nil then
        sounds.slide_sound_id[player:get_player_name()] = 0
    end

    if sounds.slide_has_played[player:get_player_name()] == nil then
        sounds.slide_has_played[player:get_player_name()] = false
    end

    if play_animated_right[player] == nil then
        play_animated_right[player] = false
    end

    if play_animated_left[player] == nil then
        play_animated_left[player] = false
    end
end

--- @brief Checks if the player on the Z and X axis is on a block.
--- This will help to later on perform the wall jump.
--- @param player userdata the player that will be checked
--- @return boolean
--- @return table
--- @return string
--- @return table
local function is_player_on_block(player, get_data, y_vel)
    local pos = player:get_pos()
    local offsets = {
        vector.new(0.56, y_vel or 1, 0),
        vector.new(-0.56, y_vel or 1, 0),
        vector.new(0, y_vel or 1, 0.56),
        vector.new(0, y_vel or 1, -0.56)
    }

    local closest_node_pos, closest_offset, closest_node = nil, nil, nil

    for _, offset in pairs(offsets) do
        local node_pos = vector.add(pos, offset)
        local node = minetest.get_node(node_pos)
        local node_def = minetest.registered_nodes[node.name]

        -- Make sure the node is walkable and valid.
        if node_def and node_def.walkable then
            if get_data then
                local distance = vector.distance(pos, node_pos)
                if distance < math.huge then
                    closest_node_pos = node_pos
                    closest_offset = offset
                    closest_node = node.name
                end

                -- Invert the offset.
                if closest_offset then
                    local old_y = closest_offset.y
                    closest_offset = vector.multiply(closest_offset, -1)
                    closest_offset.y = old_y
                end

                return closest_node_pos, closest_offset, closest_node
            end
            return true
        end
    end
    return false
end

--- @brief Gets the RLM settings from the node the player is on.
--- @param player userdata the player that will be checked
--- @return table armor_settings the RLM settings
local function get_rlm_node(player)
    local _,_,rlm_node = is_player_on_block(player, true)
    local rlm_settings = wall_jump.realistic_mode.get_settings(rlm_node)

    local armor_settings = wall_jump.realistic_mode.mix_armor_node_values(player, rlm_settings, rlm_node)
    return armor_settings
end

--- @brief Checks whether the given player is moving or not.
--- @param player userdata the player that will be checked
--- @return boolean true if the player is moving
--- @return boolean false if the player is NOT moving
local function is_player_moving(player)
    local control = player:get_player_control()
    if control.left or control.right or control.up or control.down then
        return true
    end
    return false
end

--- @brief Plays a sound with the given RLM configurations.
--- @param player userdata the position of the player that will be used
--- @param rlm table all the RLM settings for the given node
--- @param def table the node definition to obtain the default sounds from
--- @param sound string the type of sound that will be played. Available options are: `slide`, `jump`, and `sticky`.
--- @return nil
local function play_sound(player, rlm, def, sound)
    local sfx = rlm.sfx or {
        sounds = {
            jump = { },
            slide = { },
            sticky = { }
        },
        config = { }
    }

    local sfx_enabled = sfx and sfx.is_enabled or true
    local sound_def = { }

    if sound == "jump" then
        sound_def = sfx.sounds.jump
    elseif sound == "slide" then
        sound_def = sfx.sounds.slide
    elseif sound_def == "sticky" then
        sound_def = sfx.sounds.sticky
    end

    if def and sfx_enabled and (#sound_def == 0 or sound_def == "") then
        -- Play the sound only once by checking the sticky time of the player.
        if sound == "sticky" and sounds.sticky_has_played[player:get_player_name()] == false then
            minetest.sound_play("wall_jump_stick", { gain = 0.7, object = player, max_hear_distance = 16 })
            sounds.sticky_has_played[player:get_player_name()] = true
        elseif sound == "slide" and sounds.slide_has_played[player:get_player_name()] == false then
            -- Stop the sound first if there's any.

            minetest.sound_stop(sounds.slide_sound_id[player:get_player_name()])
            sounds.slide_sound_id[player:get_player_name()] = minetest.sound_play("wall_jump_slide", { gain = 0.11, object = player, max_hear_distance = 16 })
            sounds.slide_has_played[player:get_player_name()] = true
        end

        if type(def.sounds) == "table" then
            if sound == "jump" then
                minetest.sound_play(def.sounds.footstep, { gain = 1.1, object = player, max_hear_distance = 16 })
            end
        elseif type(def.sounds) == "string" and sound ~= "slide" then
            minetest.sound_play(def.sounds, { gain = 1.1, object = player, max_hear_distance = 16 })
        end
    elseif sfx_enabled and (#sound_def > 0 or sound_def ~= "") then
        -- Obtain the sound settings if available.
        local gain = sfx.config.gain or 1.1
        local pitch = sfx.config.pitch or 1
        local fade = sfx.config.fade or 0
        local max_hear_distance = sfx.config.max_hear_distance or 16
        local start_time = sfx.config.start_time or 0.0
        local loop = sfx.config.loop or false
        local sfx_pos = sfx.config.pos or player:get_pos()

        -- Is it a string?
        if type(sound_def) == "string" then
            minetest.sound_play({ name = sound_def }, {
                pos = sfx_pos,
                max_hear_distance = max_hear_distance,
                gain = gain,
                pitch = pitch,
                fade = fade,
                start_time = start_time,
                loop = loop
            })
        -- Is it a table?
        elseif type(sound_def) == "table" then
            -- Choose a random sound from the table.
            local number = math.random(1, #sound_def)
            minetest.sound_play({ name = sound_def[number] }, {
                pos = sfx_pos,
                max_hear_distance = max_hear_distance,
                gain = gain,
                pitch = pitch,
                fade = fade,
                start_time = start_time,
                loop = loop
            })
        end
    end
end

--- @brief Makes the player slide down the wall.
--- @param player userdata the player that will be modified
--- @param dtime number time taken from the globalstep
--- @return nil
local function player_slide(player, dtime)
    player_physics.slide_time[player:get_player_name()] = player_physics.slide_time[player:get_player_name()] + dtime

    -- Reduce the player's falling speed smoothly.
    local vel = player:get_velocity()

    -- Is the player standing on the air?
    local pos = player:get_pos()
    local node = minetest.get_node(vector.new(pos.x, pos.y - 0.3, pos.z))
    local node_def = minetest.registered_nodes[node.name]

    -- SHS = Slide Horizontal Speed
    -- SFS = Slide Fall Speed
    -- STW = Sticky Wall
    local rlm_settings = get_rlm_node(player)
    local sfs = rlm_settings.slide_fall_speed or slide_fall_speed
    local shs = rlm_settings.slide_horizontal_speed or slide_horizontal_speed
    local stw = rlm_settings.sticky_config or { }

    -- The player shouldn't be able to slide before they reach the minimum slide time.
    if player_physics.slide_time[player:get_player_name()] < slide_delay then
        player:set_physics_override({ speed = 1 }) -- Previously `shs`.
        player:set_physics_override({ gravity = 1 })

        return
    end

    if stw and stw.sticky_time == 0 then
        player_physics.sticky_time[player:get_player_name()] = -1
    end

    if vel.y < 0 then
        local node_pos, node_dir, name = is_player_on_block(player, true, 1.9)
        local def = minetest.registered_nodes[name]

        if node and node_def and node.name == "air" or node_def.drawtype == "plantlike" then
            -- Do not let the player move fast on Z/X axis.
            player:set_physics_override({ speed = shs })
        else
            player:set_physics_override({ speed = 1 })
            return
        end

        if stw and stw.is_sticky == true then
            if player_physics.sticky_time[player:get_player_name()] < stw.sticky_time then
                if node and node_def and node.name == "air" or node_def.drawtype == "plantlike" then
                    -- Make sure to remove X and Z speed, otherwise, the player will be moving while being stickied to a wall.
                    if vel.x > 0 then
                        player:add_velocity(vector.new(vel.x * -0.1, 0, 0))
                    end

                    if vel.z > 0 then
                        player:add_velocity(vector.new(0, 0, vel.z * -0.1))
                    end

                    player:set_physics_override({ speed = 0.01 })
                end

                player:set_velocity(vector.new(vel.x, 0, vel.z))
                player:set_physics_override({ gravity = 0 })

                player:add_velocity(vector.new(0, -0.38938, 0))

                -- Play the sticky sound.
                play_sound(player, rlm_settings, def, "sticky")
            else
                player:set_physics_override({ gravity = 1 })
                player:set_physics_override({ speed = 1 })
            end
        end

        local adjusted_slide_speed = sfs + math.abs(vel.y) * 0.1
        player:add_velocity(vector.new(0, adjusted_slide_speed, 0))

        -- Particle effects.
        if node_pos and player_physics.sticky_time[player:get_player_name()] >= (stw.sticky_time or 0) then
            local particle_def = {
                amount = 1,
                time = 0.1,
                minpos = vector.new(node_pos.x, player:get_pos().y + 1.9, node_pos.z),
                maxpos = vector.new(node_pos.x, player:get_pos().y + 1.9, node_pos.z),
                minvel = vector.new(0.1, 0.1, 0.1),
                maxvel = vector.new(0.1, 0.1, 0.1),
                minacc = vector.new(),
                maxacc = vector.new(),
                minexptime = 0.17,
                maxexptime = 0.28,
                minsize = 3.75,
                maxsize = 4,
                vertical = false,
                texture = {
                    name = "wall_jump_smoke.png",
                    alpha_tween = {1,0},
                    blend = "screen"
                },
                glow = 4,
            }

            -- Where should we put the particles: X or Z?
            if math.abs(node_dir.x) > math.abs(node_dir.z) and math.abs(node_dir.x) > 0.1 then
                if node_dir.x < 0 then
                    particle_def.minpos.x = particle_def.minpos.x - 0.3
                    particle_def.maxpos.x = particle_def.maxpos.x - 0.3

                    if player:get_look_horizontal() > 0 and player:get_look_horizontal() < 2 or player:get_look_horizontal() > 4.8 and player:get_look_horizontal() < 6.280 then
                        if play_animated_right[player] == false then
                            player_api.set_animation(player, "slide_right_animated")

                            minetest.after(0.4, function()
                                play_animated_right[player] = true
                                player_api.set_animation(player, "slide_right")
                            end)
                        else
                            player_api.set_animation(player, "slide_right")
                        end
                    else
                        if play_animated_left[player] == false then
                            player_api.set_animation(player, "slide_left_animated")

                            minetest.after(0.4, function()
                                play_animated_left[player] = true
                                player_api.set_animation(player, "slide_left")
                            end)
                        else
                            player_api.set_animation(player, "slide_left")
                        end
                    end
                else
                    particle_def.minpos.x = particle_def.minpos.x + 0.3
                    particle_def.maxpos.x = particle_def.maxpos.x + 0.3

                    if player:get_look_horizontal() > 0 and player:get_look_horizontal() < 2 or player:get_look_horizontal() > 4.8 and player:get_look_horizontal() < 6.280 then
                        if play_animated_left[player] == false then
                            player_api.set_animation(player, "slide_left_animated")

                            minetest.after(0.4, function()
                                play_animated_left[player] = true
                                player_api.set_animation(player, "slide_left")
                            end)
                        else
                            player_api.set_animation(player, "slide_left")
                        end
                    else
                        if play_animated_right[player] == false then
                            player_api.set_animation(player, "slide_right_animated")

                            minetest.after(0.4, function()
                                play_animated_right[player] = true
                                player_api.set_animation(player, "slide_right")
                            end)
                        else
                            player_api.set_animation(player, "slide_right")
                        end
                    end
                end

                if show_particles then
                    minetest.add_particlespawner(particle_def)
                end
            else
                if node_dir.z < 0 then
                    particle_def.minpos.z = particle_def.minpos.z - 0.3
                    particle_def.maxpos.z = particle_def.maxpos.z - 0.3

                    local angle = player:get_look_horizontal()
                    if angle > math.pi - 0.4 then
                        if play_animated_left[player] == false then
                            player_api.set_animation(player, "slide_left_animated")

                            minetest.after(0.4, function()
                                play_animated_left[player] = true
                                player_api.set_animation(player, "slide_left")
                            end)
                        else
                            player_api.set_animation(player, "slide_left")
                        end
                    else
                        if play_animated_right[player] == false then
                            player_api.set_animation(player, "slide_right_animated")

                            minetest.after(0.4, function()
                                play_animated_right[player] = true
                                player_api.set_animation(player, "slide_right")
                            end)
                        else
                            player_api.set_animation(player, "slide_right")
                        end
                    end
                else
                    particle_def.minpos.z = particle_def.minpos.z + 0.3
                    particle_def.maxpos.z = particle_def.maxpos.z + 0.3

                    local angle = player:get_look_horizontal()
                    if angle > math.pi + 0.4 then
                        if play_animated_right[player] == false then
                            player_api.set_animation(player, "slide_right_animated")

                            minetest.after(0.4, function()
                                play_animated_right[player] = true
                                player_api.set_animation(player, "slide_right")
                            end)
                        else
                            player_api.set_animation(player, "slide_right")
                        end
                    else
                        if play_animated_left[player] == false then
                            player_api.set_animation(player, "slide_left_animated")

                            minetest.after(0.4, function()
                                play_animated_left[player] = true
                                player_api.set_animation(player, "slide_left")
                            end)
                        else
                            player_api.set_animation(player, "slide_left")
                        end
                    end
                end

                if show_particles then
                    minetest.add_particlespawner(particle_def)
                end
            end

            -- Play the slide sound.
            play_sound(player, rlm_settings, def, "slide")
        end
    end
end

--- @brief Handles player jumping when performing
--- a wall jump. It will also move the player depending if `same_wall` is true.
--- @param player userdata the player that will be modified
--- @param dtime number time taken from the globalstep
--- @return nil
local function player_jump(player, dtime)
    player_physics.jump_time[player:get_player_name()] = player_physics.jump_time[player:get_player_name()] + dtime

    local control = player:get_player_control()
    local rlm_settings = get_rlm_node(player) -- Get RLM settings.

    -- WJA = Wall Jump Amount
    -- JH = Jump Height
    -- HS = Horizontal Speed
    -- STW = Sticky Wall
    local wja = rlm_settings.wall_jump_amount or wall_jump_amount
    local jh = rlm_settings.jump_height or jump_height
    local hs = rlm_settings.horizontal_speed or horizontal_speed
    local stw = rlm_settings.sticky_config or { }

    -- The player shouldn't be able to jump before they reach the minimum time.
    if player_physics.jump_time[player:get_player_name()] < jump_delay then
        return
    end

    if control.jump then
        if not player_physics.is_jumping[player:get_player_name()] then
            if player_physics.walljump_count[player:get_player_name()] < wja or wja == 0 then
                player_physics.walljump_count[player:get_player_name()] = player_physics.walljump_count[player:get_player_name()] + 1

                local pos = player:get_pos()
                local node = minetest.get_node(vector.new(pos.x, pos.y - 0.5, pos.z))
                local node_def = node and minetest.registered_nodes[node.name]

                if node and node_def and node.name ~= "air" and node_def.drawtype ~= "plantlike" then
                    return
                end

                local vel = player:get_velocity()
                if vel.y < 0 then
                    player:add_velocity(vector.new(0, math.abs(vel.y) - 1, 0))
                end

                -- Make the player jump.
                player:add_velocity(vector.new(0, jh, 0))

                -- Do we have to reset the sticky time?
                if stw and stw.reset_time_on_jump == true then
                    player_physics.sticky_time[player:get_player_name()] = 0
                end

                -- Play the `player_jump` sound.
                -- This is originally played on each jump.
                minetest.sound_play({ name = "player_jump" }, { pos = player:get_pos(), to_player = player:get_player_name() })

                play_animated_right[player] = false
                play_animated_left[player] = false

                local node_pos, node_dir, name = is_player_on_block(player, true)
                local def = minetest.registered_nodes[name]
                if node_pos then
                    -- Particle effects.
                    local particle_def = {
                        amount = 1,
                        time = 0.1,
                        minpos = vector.new(node_pos.x, player:get_pos().y - 0.18, node_pos.z),
                        maxpos = vector.new(node_pos.x, player:get_pos().y - 0.18, node_pos.z),
                        minvel = vector.new(0.1, 0.1, 0.1),
                        maxvel = vector.new(0.1, 0.1, 0.1),
                        minacc = vector.new(),
                        maxacc = vector.new(),
                        minexptime = 0.3,
                        maxexptime = 0.3,
                        minsize = 4.7,
                        maxsize = 4.75,
                        vertical = false,
                        texture = {
                            name = "wall_jump_smoke.png",
                            alpha_tween = {1,0},
                            blend = "add"
                        },
                        glow = 4,
                    }

                    local explode_particle = {
                        amount = 1,
                        time = 0.1,
                        minpos = vector.new(node_pos.x, player:get_pos().y + 0.8, node_pos.z),
                        maxpos = vector.new(node_pos.x, player:get_pos().y + 0.8, node_pos.z),
                        minvel = vector.new(0.1, 0.1, 0.1),
                        maxvel = vector.new(0.1, 0.1, 0.1),
                        minacc = vector.new(),
                        maxacc = vector.new(),
                        minexptime = 0.3,
                        maxexptime = 0.35,
                        minsize = 10,
                        maxsize = 10.25,
                        vertical = false,
                        texture = {
                            name = "wall_jump_explode.png",
                            alpha = 0.75,
                            alpha_tween = {1,0},
                            scale_tween = {
                                {x = 0.65, y = 0.65},
                                {x = 1, y = 1},
                            },
                        },
                        glow = 6,
                    }

                    if math.abs(node_dir.x) > math.abs(node_dir.z) and math.abs(node_dir.x) > 0.1 then
                        if same_wall ~= true then
                            player:add_velocity(vector.new(node_dir.x * hs, 0, 0))
                        end

                        if show_particles then
                            if node_dir.x < 0 then
                                particle_def.minpos.x = particle_def.minpos.x - 0.3
                                particle_def.maxpos.x = particle_def.maxpos.x - 0.3

                                explode_particle.minpos.x = explode_particle.minpos.x - 0.17
                                explode_particle.maxpos.x = explode_particle.maxpos.x - 0.17
                            else
                                particle_def.minpos.x = particle_def.minpos.x + 0.3
                                particle_def.maxpos.x = particle_def.maxpos.x + 0.3

                                explode_particle.minpos.x = explode_particle.minpos.x + 0.17
                                explode_particle.maxpos.x = explode_particle.maxpos.x + 0.17
                            end

                            minetest.add_particlespawner(particle_def)

                            -- Modify the Y position to add it near the player's arm.
                            particle_def.minpos.y = particle_def.minpos.y + 2
                            particle_def.maxpos.y = particle_def.maxpos.y + 2

                            minetest.add_particlespawner(particle_def)
                            minetest.add_particlespawner(explode_particle)
                        end
                    else
                        if same_wall ~= true then
                            player:add_velocity(vector.new(0, 0, node_dir.z * hs))
                        end

                        if show_particles then
                            if node_dir.z < 0 then
                                particle_def.minpos.z = particle_def.minpos.z - 0.3
                                particle_def.maxpos.z = particle_def.maxpos.z - 0.3

                                explode_particle.minpos.z = explode_particle.minpos.z - 0.17
                                explode_particle.maxpos.z = explode_particle.maxpos.z - 0.17
                            else
                                particle_def.minpos.z = particle_def.minpos.z + 0.3
                                particle_def.maxpos.z = particle_def.maxpos.z + 0.3

                                explode_particle.minpos.z = explode_particle.minpos.z + 0.17
                                explode_particle.maxpos.z = explode_particle.maxpos.z + 0.17
                            end

                            minetest.add_particlespawner(particle_def)

                            -- Modify the Y position to add it near the player's arm.
                            particle_def.minpos.y = particle_def.minpos.y + 2
                            particle_def.maxpos.y = particle_def.maxpos.y + 2

                            minetest.add_particlespawner(particle_def)
                            minetest.add_particlespawner(explode_particle)
                        end
                    end

                    -- Play a sound when the player jumps that is the node's sound.
                    play_sound(player, rlm_settings, def, "jump")

                    -- Stop the slide sound.
                    minetest.sound_stop(sounds.slide_sound_id[player:get_player_name()])

                    minetest.after(0.68, function()
                        sounds.sticky_has_played[player:get_player_name()] = false
                        sounds.slide_has_played[player:get_player_name()] = false
                    end)
                end

                player_physics.jump_time[player:get_player_name()] = 0
            end
        end
        player_physics.is_jumping[player:get_player_name()] = true
    else
        player_physics.is_jumping[player:get_player_name()] = false
    end
end

--- @brief Function that calls the slide
--- and jumping functions altogether.
--- @param player userdata the player that will be modified
--- @return nil
local function wall_jump(player, dtime)
    local node = minetest.get_node(vector.new(player:get_pos().x, player:get_pos().y - 0.3, player:get_pos().z))
    local node_def = node and minetest.registered_nodes[node.name]

    if node and node_def and node.name ~= "air" and node_def.drawtype ~= "plantlike" then
        minetest.sound_stop(sounds.slide_sound_id[player:get_player_name()] or 0)
    end

    if is_player_on_block(player, false, 1.5) and is_player_moving(player) then
        player_physics.sticky_time[player:get_player_name()] = player_physics.sticky_time[player:get_player_name()] + dtime

        player_slide(player, dtime)
        player_jump(player, dtime)
    else
        local pos = player:get_pos()
        node = minetest.get_node(vector.new(pos.x, pos.y - 0.1, pos.z))

        if node and node.name ~= "air" then
            player_physics.sticky_time[player:get_player_name()] = 0
            player_physics.slide_time[player:get_player_name()] = 0

            player_physics.jump_time[player:get_player_name()] = jump_delay
            player_physics.walljump_count[player:get_player_name()] = 0

            sounds.sticky_has_played[player:get_player_name()] = false
            sounds.slide_has_played[player:get_player_name()] = false

            play_animated_right[player] = false
            play_animated_left[player] = false
        end

        player:set_physics_override({ speed = 1 })
        player:set_physics_override({ gravity = 1 })

        minetest.sound_stop(sounds.slide_sound_id[player:get_player_name()] or 0)
    end
end

minetest.register_globalstep(function(dtime)
    for _, player in pairs(minetest.get_connected_players()) do
        wall_jump(player, dtime)
    end
end)

minetest.register_on_joinplayer(function(player)
    initialize(player)
end)
