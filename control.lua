local chunks_per_tick = 1

script.on_init(function()
    -- mylog("my init")

    if not storage.gaddhi_sensible_deconstruction then
        storage.gaddhi_sensible_deconstruction = {}
        storage.gaddhi_sensible_deconstruction.version = 1 -- Version 1 since mod version 0.2.0
    end
    -- init: clear preexisting work orders
    storage.gaddhi_sensible_deconstruction.works = {}
end)

function on_player_selected_area(event)
    if not (event.item == 'gaddhi-sd-mark-region') then return end

    if storage.gaddhi_sensible_deconstruction and storage.gaddhi_sensible_deconstruction.works and table_size(storage.gaddhi_sensible_deconstruction.works) > 0 then
        game.print("Only a single sensible deconstructions can be active at any time. Ignoring newly selected region.")
        return
    end
    local area = event.area
    local player = game.players[event.player_index]
    player.remove_item({name = 'gaddhi-sd-mark-region'})

    local new_work = {
        left_top = {
            x = math.floor(area.left_top.x / 32),
            y = math.floor(area.left_top.y / 32)
        },
        right_botton = {
            x = math.floor(area.right_bottom.x / 32),
            y = math.floor(area.right_bottom.y / 32)
        },
        current = {
            x = math.floor(area.left_top.x / 32),
            y = math.floor(area.left_top.y / 32)
        },
        area = event.area,
        player_index = event.player_index,
        force_index = player.force_index,
        surface_index = player.surface.index,
        stage = 1,
        port_max_connection_range = 0,
        port_max_construction_range = 0,
        next_update_tick = 0,
        last_change_tick = 0,
        to_be_deleted = false,
        remaining_entities_to_be_deconstructed = 0,
        essential_entities_to_be_deconstructed = {},
        entities_to_be_deconstructed = 0,
        stage_30_power_poles = {},
        stage_30_power_pole_index = nil,
        stage_30_connection_removed = false,
    }

    -- Reset state
    if storage.gaddhi_sensible_deconstruction == nil then
        storage.gaddhi_sensible_deconstruction = {}
        storage.gaddhi_sensible_deconstruction.version = 1
        storage.gaddhi_sensible_deconstruction.works = {}
    end
    storage.gaddhi_sensible_deconstruction.works = nil -- Reset everything
    if storage.gaddhi_sensible_deconstruction.works == nil then
        storage.gaddhi_sensible_deconstruction.works = {}
    end

    table.insert(storage.gaddhi_sensible_deconstruction.works, new_work)
    mylog('Add Sensible Deconstruction on surface "' .. player.surface.name ..'" in area (' .. area.left_top.x .. ', ' .. area.left_top.y .. ') - (' .. area.right_bottom.x .. ', ' .. area.right_bottom.y .. ')')
end

script.on_event(defines.events.on_player_selected_area, on_player_selected_area)

function on_tick()
    if not storage.gaddhi_sensible_deconstruction then return end
    if not storage.gaddhi_sensible_deconstruction.works then return end
    if not (type(storage.gaddhi_sensible_deconstruction.works) == "table") then return end
    local deletes = {}
    for index, work in pairs(storage.gaddhi_sensible_deconstruction.works) do
        if work.to_be_deleted then
            storage.gaddhi_sensible_deconstruction.works[index] = nil
        else
            if work.next_update_tick <= game.tick then
                -- Stage 1 ==================================================================
                -- Initialization
                if work.stage == 1 then
                    -- Stage 1: Gather rudimentary data about entities
                    local entities = game.surfaces[work.surface_index].find_entities_filtered{area = work.area, force = work.force_index, type = {"roboport"}}
                    for i, entity in pairs(entities) do
                        if entity.type == 'roboport' then
                            work.port_max_connection_range = math.max(work.port_max_connection_range, entity.prototype.logistic_parameters.logistics_connection_distance)
                            work.port_max_construction_range = math.max(work.port_max_construction_range, entity.prototype.logistic_parameters.construction_radius)
                        end
                    end

                    -- cancel upgrading and ghost building
                    entities = game.surfaces[work.surface_index].find_entities_filtered{area = work.area, force = work.force_index}
                    for i, entity in pairs(entities) do
                        if entity.is_registered_for_upgrade() then
                            entity.cancel_upgrade(work.force)
                        end
                        if entity.type == "entity-ghost" then
                            entity.order_deconstruction(work.force_index)
                        end
                    end
                    work.stage = 10
                    -- ("Stage : " .. work.stage)

                elseif work.stage == 10 then
                    -- Stage 10: Force deconstruction of all non essential entities (excludes Roboports and Power Poles)
                    deconstruct_non_essentials(work)
                elseif work.stage == 11 then
                    -- Stage 11: Wait until all non essential Entities are deconstructed

                    -- Check once per second 
                    if (game.tick + index) % 60 == 0 then
                        check_if_initial_deconstruction_is_finished(work)
                    end

                elseif work.stage == 20 then
                    -- Stage 20: Remove iteratively Powerpoles and Roboports at the end of the areas
                    deconstruct_essentials(work, false)
                elseif work.stage == 30 then
                    -- Stage 30: Break electric pole loops
                    local entities = game.surfaces[work.surface_index].find_entities_filtered{area = work.area, force = work.force_index, type = {'electric-pole'}}
                    work.stage_30_power_poles = {}
                    local pole_index = 1
                    for i, entity in pairs(entities) do
                        work.stage_30_power_poles[pole_index] = entity
                        pole_index = pole_index + 1
                    end
                    work.stage_30_power_pole_index = 1
                    work.stage_30_connection_removed = false
                    work.stage = 31
                    -- mylog("Stage : " .. work.stage)
                    -- mylog("Power-poles:" .. table_size(work.stage_30_power_poles))
                elseif work.stage == 31 then
                    if work.stage_30_power_pole_index <= table_size(work.stage_30_power_poles) then
                        check_power_pole_for_loops(work.stage_30_power_poles[work.stage_30_power_pole_index], work)
                        work.stage_30_power_pole_index = work.stage_30_power_pole_index + 1
                    else
                        if work.stage_30_connection_removed then
                            work.stage = 40
                            -- mylog("Stage : " .. work.stage)
                        else
                            work.stage = 50
                            -- mylog("Stage : " .. work.stage)
                            -- mylog("No more power pole connections removable")
                            -- mylog("End Process")
                        end
                    end
                elseif work.stage == 40 then
                    -- Stage 40: Remove iteratively Powerpoles and Roboports at the End of the areas
                    -- after getting rid of electric pole loops
                    deconstruct_essentials(work, false)
                elseif work.stage == 50 then
                    -- Stage 50: Remove iteratively Powerpoles and Roboports at the End of the areas
                    -- also force removal of roboports, that are not at the edges
                    deconstruct_essentials(work, true)
                end
            end
        end
    end
end

script.on_event(defines.events.on_tick, on_tick)


-- STAGE 10 ===================================

function deconstruct_non_essentials(work)
    local loop_checker = {
        x = work.current.x,
        y = work.current.y
    }
    for i = 1, chunks_per_tick do
        check_chunk(work)
        if work.current.x == work.right_botton.x then
            work.current.x = work.left_top.x
            if work.current.y == work.right_botton.y then
                work.stage = 11
                -- ("Stage : " .. work.stage)
                -- mylog("STAGE 11 ==================")
                return
            else
                work.current.y = work.current.y + 1
            end
        else
            work.current.x = work.current.x + 1
        end
        if loop_checker.x == work.current.x and loop_checker.y == work.current.y then
            i = chunks_per_tick -- finish loop for this workorder
        end
    end
end

function check_chunk(work)
    local chunk_position = work.current
    if not game.forces[work.force_index].is_chunk_charted(work.surface_index, chunk_position) then return end
    local bounded_area = {
        left_top = {
            x = chunk_position.x * 32,
            y = chunk_position.y * 32
        },
        right_bottom = {
            x = chunk_position.x * 32 + 32,
            y = chunk_position.y * 32 + 32
        }
    }
    bounded_area = intersection(bounded_area, work.area, bounding_box)

    -- mylog({"Checking", chunk_position, bounded_area})

    local entities = game.surfaces[work.surface_index].find_entities_filtered{area = bounded_area, force = work.force_index}
    for i, entity in pairs(entities) do
        try_removing_entity(entity, work)
    end
    local tiles = game.surfaces[work.surface_index].find_tiles_filtered{area = bounded_area, force = work.force_index}
    for i, tile in pairs(tiles) do
        if tile.prototype.mineable_properties.minable then
            try_removing_tile(tile, work)
        end
    end
end

function try_removing_entity(entity, work)
    if entity.to_be_deconstructed() then return end
--    if entity.type == 'resource' then return end
--    if entity.type == 'simple-entity' then return end
--    if entity.type == 'tree' then return end
--    if entity.type == 'corpse' then return end
    if entity.type == 'character' then return end
    if entity.type == 'construction-robot' then return end

    if entity.type == 'roboport' then return end
    if entity.type == 'electric-pole' then return end
    if entity.type == 'car' then
        mylog("Found a car inside the deconstruction area. Unable to continue. Move the car out of the area before restarting the sensible deconstruction.")
        work.to_be_deleted = true
        return
    end

    -- check if the entity can be deconstructed (is in the range of a roboport)
    local roboport_area = entity.selection_box
    roboport_area.left_top.x = roboport_area.left_top.x - work.port_max_construction_range
    roboport_area.left_top.y = roboport_area.left_top.y - work.port_max_construction_range
    roboport_area.right_bottom.x = roboport_area.right_bottom.x + work.port_max_construction_range
    roboport_area.right_bottom.y = roboport_area.right_bottom.y + work.port_max_construction_range
    local entities = game.surfaces[work.surface_index].find_entities_filtered{area = roboport_area, force = work.force_index, type = {'roboport'}}
    local in_roboport_range = false
    for i, r in pairs(entities) do
        if can_be_deconstructed_by_roboport(entity, r) then
            in_roboport_range = true
            break
        end
    end

    if in_roboport_range then
        -- mylog({"remove", entity.name, entity.type, entity.gps_tag})

        entity.order_deconstruction(work.force_index)
        work.last_change_tick = game.tick
    else
        game.print("Entity " .. entity.gps_tag .. "isn't in range of a roboport and can't be deconstucted")
    end
end

function try_removing_tile(tile, work)
    if tile.to_be_deconstructed() then return end
    -- mylog({"remove tile", tile.name, tile.position})
    tile.order_deconstruction(work.force_index)
    work.last_change_tick = game.tick
end

-- STAGE 20 ===================================

function check_if_initial_deconstruction_is_finished(work)
    local res = game.surfaces[work.surface_index].count_entities_filtered{area = work.area, to_be_deconstructed = true, force = work.force_index, limit = 1}
    -- mylog({"in deconstruction: ", res})
    if res == 0 then
        work.stage = 20
        -- mylog("Stage : " .. work.stage)
        work.current.x = work.left_top.x
        work.current.y = work.left_top.y
        -- mylog("STAGE 20 ==================")
    else
        if work.last_change_tick + 10 * 60 * 60 < game.tick then -- ten minutes without update
            mylog("removing stale sensible deconstructor")
            work.to_be_deleted = true
        end
    end
end

-- STAGE 30 ===================================

function deconstruct_essentials(work, force_removal)
    local loop_checker = {
        x = work.current.x,
        y = work.current.y
    }
    for i = 1, chunks_per_tick do
        check_chunk_essentials(work, force_removal)
        if work.current.x == work.right_botton.x then
            work.current.x = work.left_top.x
            if work.current.y == work.right_botton.y then
                work.current.y = work.left_top.y
                after_deconstruct_essentials_loop_done(work)
            else
                work.current.y = work.current.y + 1
            end
        else
            work.current.x = work.current.x + 1
        end
        if loop_checker.x == work.current.x and loop_checker.y == work.current.y then
            i = chunks_per_tick -- finish loop for this workorder
        end
    end
end

function check_chunk_essentials(work, force_removal)
    local chunk_position = work.current
    if not game.forces[work.force_index].is_chunk_charted(work.surface_index, chunk_position) then return end
    local bounded_area = {
        left_top = {
            x = chunk_position.x * 32,
            y = chunk_position.y * 32
        },
        right_bottom = {
            x = chunk_position.x * 32 + 32,
            y = chunk_position.y * 32 + 32
        }
    }
    bounded_area = intersection(bounded_area, work.area)
    -- mylog({'Check Chunk Essentials', bounded_area})
    local entities = game.surfaces[work.surface_index].find_entities_filtered{area = bounded_area, force = force_index}
    for i, entity in pairs(entities) do
        if not entity.to_be_deconstructed() then
            if entity.type == 'roboport' then
                if work.essential_entities_to_be_deconstructed[entity.unit_number] == nil then
                    if not try_removing_roboport(entity, work, force_removal) then
                        work.essential_entities_to_be_deconstructed[entity.unit_number] = true
                        work.remaining_entities_to_be_deconstructed = work.remaining_entities_to_be_deconstructed + 1
                        -- mylog({"schedule roboport deconstruction for later", entity.gps_tag})
                    end
                end
            elseif entity.type == 'electric-pole' then
                if work.essential_entities_to_be_deconstructed[entity.unit_number] == nil then
                    if not try_removing_electric_pole(entity, work) then
                        work.remaining_entities_to_be_deconstructed = work.remaining_entities_to_be_deconstructed + 1
                        -- mylog({"schedule powerpole deconstruction for later", entity.gps_tag})
                    end
                end
            elseif
                entity.type == 'construction-robot' or
                entity.type == 'character' or
                entity.type == 'simple-entity' or
                entity.type == 'resource' or
                entity.type == 'tree'
            then
                -- do nothing
            else
                -- mylog({"unknown entity: ", entity.type})
            end
        else
            work.entities_to_be_deconstructed = work.entities_to_be_deconstructed + 1
        end
    end
end

function try_removing_roboport(entity, work, force_removal)
    -- return true, if this entity was scheduled to be deconstructed
    -- return false, if this entity was not scheduled to be deconstructed

    if not force_removal then
        -- First, try to remove roboports at the ends of electric pole lines
        -- this is to bring roboport removal in accordance with power pole removal

        -- is disabled with the function argument force_removal, wich allows the deconstruction of
        -- Roboports, that are not at the end of electric pole lines
        local poles = get_powerpoles_of_roboport(entity, work)
        for i, p in pairs(poles) do
            if p.get_wire_connectors(false)[defines.wire_connector_id.pole_copper].real_connection_count > 1 then
                -- Assume that there is a different Roboport, that can be removed prefiously while keeping
                -- in sync with power poles
                return false
            end
        end
    end

    -- Second, check if other entities would be no longer in the construction range of a different roboport
    -- mylog("second")
    local search_area = get_search_area(entity.position, entity.prototype.logistic_parameters.construction_radius)
    local targets = game.surfaces[work.surface_index].find_entities_filtered{area = search_area, force = work.force_index, type = 'electric-pole'}
    -- mylog({"entities in construction range found: ", table_size(targets)})
    for index, target in pairs(targets) do
        -- mylog({"entity", target.name, target.gps_tag})
        local target_search_area = get_search_area(target.position, work.port_max_construction_range)
        local other_roboports = game.surfaces[work.surface_index].find_entities_filtered{area = target_search_area, force = work.force_index, type = "roboport"}
        local other_roboport_available = false
        for i2, other in pairs(other_roboports) do
            if other == entity then
                -- ignore
            else
                if can_be_deconstructed_by_roboport(target, other) then
                    -- mylog({"can be deconstructed by", other.gps_tag})
                    other_roboport_available = true
                    break
                end
            end
        end
        -- mylog({"entity", target.name, target.gps_tag, other_roboport_available})
        if not other_roboport_available then
            return false
        end
    end

    -- Last, check that removing entity would not disconnect Neighbour Reboports.
    -- mylog({"try removing roboport", entity.position})

    local other_roboports = get_logistic_connected_roboports(entity, work.surface_index, work.force_index)

    -- mylog({"connected roboports: ", table_size(other_roboports)})
    if table_size(other_roboports) == 0 then
        -- go on deconstructing the last roboport
    elseif table_size(other_roboports) == 1 then
        -- mylog("1 other roboport")
        if other_roboports[1].to_be_deconstructed() then
            -- delay until other is deconstructed
            return false
        end
        -- Roboport is linked only to a single other roboport, so it can be removed safely
    elseif table_size(other_roboports) >= 2 then
        local start_roboport = other_roboports[1]
        local todo_roboports = {}
        local need_to_find = 0
        for i, o in pairs(other_roboports) do
            if o ~= start_roboport and not o.to_be_deconstructed() then
                todo_roboports[o.unit_number] = true
                need_to_find = need_to_find + 1
                -- mylog("need to find "..o.gps_tag)
            end
        end
        local found = {}
        local foundi = {}
        found[start_roboport.unit_number] = true
        local indexf = 1
        foundi[indexf] = start_roboport
        indexf = indexf + 1
        local index = 1
        -- mylog("others:" .. table_size(other_roboports))
        while index <= table_size(foundi) do
            -- mylog("index:" .. index)
            local others = get_logistic_connected_roboports(foundi[index], work.surface_index, work.force_index)
            for _, o in pairs(others) do
                if o ~= entity and found[o.unit_number] == nil and not o.to_be_deconstructed() then
                    -- mylog({"adding", o.gps_tag})
                    found[o.unit_number] = true
                    foundi[indexf] = o
                    indexf = indexf + 1
                    if todo_roboports[o.unit_number] ~= nil then
                        todo_roboports[o.unit_number] = nil
                        need_to_find = need_to_find - 1
                        -- mylog({"found ", o.gps_tag})
                    end
                end
            end
            if need_to_find == 0 then break end
            index = index + 1
        end
        -- mylog({"delta", need_to_find})
        if need_to_find > 0 then
            -- at least one roboport woult be separated from the others
            return false
        end
    end

    entity.order_deconstruction(work.force_index)
    work.entities_to_be_deconstructed = work.entities_to_be_deconstructed + 1
    -- mylog({"Deconstruct Roboport", entity.gps_tag, work.entities_to_be_deconstructed})
    work.last_change_tick = game.tick
    return true
end

function try_removing_electric_pole(entity, work)
    -- mylog("trying to remove pole" .. entity.gps_tag)
    local connector = entity.get_wire_connectors(false)[defines.wire_connector_id.pole_copper]
    if connector.real_connection_count > 1 then return end
    local search_area = get_search_area(entity.position, entity.prototype.get_supply_area_distance(entity.quality))
    local other_roboports = game.surfaces[work.surface_index].find_entities_filtered{area = search_area, force = work.force_index, type = "roboport"}
    for i, o in pairs(other_roboports) do
        -- mylog("powers roboport" .. o.gps_tag)
        local app = get_powerpoles_of_roboport(o, work)
        local counter = 0 -- number of other power poles, that are powering the roboport and are not deconstructed
        for i, p in pairs(app) do
            if p ~= entity and not p.to_be_deconstructed() then
                -- mylog("roboport is additionally powered by" .. p.gps_tag)
                counter = counter + 1
            end
        end
        if counter == 0 then
            -- roboport is only supported by this electric pole, so tha pole can't be removed
            return
        end
    end
    
    -- mylog("Deconstruct pole" .. entity.gps_tag .. "(" .. work.entities_to_be_deconstructed .. ")")
    entity.get_wire_connectors(false)[defines.wire_connector_id.pole_copper].disconnect_all()
    entity.order_deconstruction(work.force_index)
    work.entities_to_be_deconstructed = work.entities_to_be_deconstructed + 1
    work.last_change_tick = game.tick
end

function after_deconstruct_essentials_loop_done(work)
    -- mylog({"LOOP done:", work.remaining_entities_to_be_deconstructed, work.entities_to_be_deconstructed})
    if work.remaining_entities_to_be_deconstructed == 0 and work.entities_to_be_deconstructed == 0 then
        mylog("Sensible Deconstruction sucessfully completed.")
        work.to_be_deleted = true
        return
    end
    if work.remaining_entities_to_be_deconstructed > 0 and work.entities_to_be_deconstructed == 0 then
        -- Nothing has changed in current loop and there are still entities to be removed
        if work.stage == 20 then
            work.stage = 30
            -- mylog("Stage : " .. work.stage)
            -- mylog("STAGE 30 ==================")
        elseif work.stage == 40 then
            work.stage = 50
            -- mylog("Stage : " .. work.stage)
        elseif work.stage == 50 then
            mylog("Sensible Deconstruction canceled with " .. work.remaining_entities_to_be_deconstructed .. " entities remaining")
            work.to_be_deleted = true
        end
    else
        -- There is still work to be done. Check again in 5 seconds.
        -- TODO: Replace by a system that listens to events when buildings are deconstructed
        work.next_update_tick = game.tick + 60 * 5 -- 5 seconds in future
        -- mylog("sleep 5")
    end
    work.remaining_entities_to_be_deconstructed = 0
    work.essential_entities_to_be_deconstructed = {}
    work.entities_to_be_deconstructed = 0
end

-- STAGE 40 ===================================

function check_power_pole_for_loops(entity, work)
    local connector = entity.get_wire_connectors(false)[defines.wire_connector_id.pole_copper]
    for i, other in pairs(connector.real_connections) do
        if is_connected_indirectly(connector, other.target, work) then
            connector.disconnect_from(other.target)
            --entity.disconnect_neighbour(other)
            work.stage_30_connection_removed = true
        end
    end
end

function is_connected_indirectly(a_connector, b_connector, work)
    -- mylog({"ICI", a.owner.gps_tag, b.owner.gps_tag})
    local found = {}
    local foundi = {}
    local findex = 1
    for i, other_connection in pairs(a_connector.real_connections) do
        if not (other_connection.target == b_connector) and other_connection.target.owner.surface_index == work.surface_index then
            found[other_connection.target.owner.unit_number] = true
            foundi[findex] = other_connection.target
            findex = findex + 1
        end
    end
    local index = 1
    while index <= table_size(foundi) do
        local source = foundi[index]
        -- mylog({"S", source.gps_tag, index})
        for i, other_connection in pairs(source.real_connections) do
            if other_connection.target == b_connector then
                return true
            end
            if other_connection.target ~= a_connector then
                if found[other_connection.target.owner.unit_number] == nil then
                    -- mylog({"adding", o.gps_tag})
                    found[other_connection.target.owner.unit_number] = true
                    foundi[findex] = other_connection.target
                    findex = findex + 1
                end
            end
        end
        index = index + 1
    end
    return false
end

-- Helper functions ===================================

function get_powerpoles_of_roboport(entity, work)
    -- Return a table of all power poles, that currently supply power to the roboport.
    local power_pole_search_area = entity.selection_box
    power_pole_search_area.left_top.x = power_pole_search_area.left_top.x - prototypes.max_electric_pole_supply_area_distance
    power_pole_search_area.left_top.y = power_pole_search_area.left_top.y - prototypes.max_electric_pole_supply_area_distance
    power_pole_search_area.right_bottom.x = power_pole_search_area.right_bottom.x + prototypes.max_electric_pole_supply_area_distance
    power_pole_search_area.right_bottom.y = power_pole_search_area.right_bottom.y + prototypes.max_electric_pole_supply_area_distance
    -- mylog({"GPPOR", entity.gps_tag, power_pole_search_area, prototypes.max_electric_pole_supply_area_distance})
    local res = {}
    local poles = game.surfaces[work.surface_index].find_entities_filtered{area = power_pole_search_area, force = work.force_index, type = "electric-pole"}
    for i, pole in pairs(poles) do
        -- mylog({"POLE " .. pole.type .. pole.prototype.type .. pole.position .. power_pole_search_area .. prototypes.max_electric_pole_supply_area_distance})
        local power_area = get_search_area(pole.position, pole.prototype.get_supply_area_distance(pole.quality))
        -- mylog({"pole", pole.gps_tag, power_area, pole.prototype.supply_area_distance})
        if is_in_area(entity, power_area) then
            -- mylog("supply")
            table.insert(res, pole)
        end
    end
    return res
end

function get_logistic_connected_roboports(entity, surface_index, force_index)
    local connected_roboports_search_area = get_search_area(entity.position, entity.prototype.logistic_parameters.logistics_connection_distance * 2)
    local other_roboports = game.surfaces[surface_index].find_entities_filtered{area = connected_roboports_search_area, force = force_index, type = "roboport"}
    local res = {}
    for i, o in pairs(other_roboports) do
        if not (o == entity) and are_logistic_connected(entity, o) then
            table.insert(res, o)
        end
    end
    return res
end

function are_logistic_connected(r1, r2)
    local range = r1.prototype.logistic_parameters.logistics_connection_distance +
        r2.prototype.logistic_parameters.logistics_connection_distance
    local connected =
        math.abs(r1.position.x - r2.position.x) <= range and
        math.abs(r1.position.y - r2.position.y) <= range
    -- mylog({"ALC", r1.position, r2.position, range, connected})
    return connected
end

function can_be_deconstructed_by_roboport(entity, roboport)
    local area = get_search_area(roboport.position, roboport.prototype.logistic_parameters.construction_radius)
    local bb = entity.selection_box
    local i = intersection(area, bb)
    -- mylog({entity.gps_tag, roboport.gps_tag, i})
    if i.left_top.x < i.right_bottom.x and i.left_top.y < i.right_bottom.y then
        return true
    end
    return false
end

function intersection(a, b)
    return {
        left_top = {
            x = math.max(a.left_top.x, b.left_top.x),
            y = math.max(a.left_top.y, b.left_top.y)
        },
        right_bottom = {
            x = math.min(a.right_bottom.x, b.right_bottom.x),
            y = math.min(a.right_bottom.y, b.right_bottom.y)
        }
    }
end

function get_search_area(pos, radius)
    -- Return an rectangular area, centered on pos with a given radius.
    return {
        left_top = {
            x = pos.x - radius,
            y = pos.y - radius
        },
        right_bottom = {
            x = pos.x + radius,
            y = pos.y + radius
        }
    }
end

function is_in_area(entity, area)
    -- Return, if the entity is within the area.
    local a = entity.selection_box
    local inter = intersection(a, area)
    -- mylog({"iia", entity.name, entity.gps_tag, entity.selection_box, inter})
    return inter.left_top.x < inter.right_bottom.x and inter.left_top.y < inter.right_bottom.y
end

function mylog(x)
    if type(x) ~= "string" then
        x = serpent.line(x)
    end
    game.print(x)
    log(x)
end

