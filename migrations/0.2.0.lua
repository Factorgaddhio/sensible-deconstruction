if (not storage.gaddhi_sd_data == nil) then
    -- The storage variable has been renamed and its structure changed.
    if table_size(storage.gaddhi_sd_data.works) > 0 then
        game.print("Migrating from previous Sensible Deconstruction version.")
        for _, work in pairs(storage.gaddhi_sd_data.works) do
            game.print('Removed Sensible Deconstruction on surface "' .. game.surfaces[work.surface_index].name .. '" in area (' .. work.area.left_top.x .. ', ' .. work.area.left_top.y .. ') - (' .. work.area.right_bottom.x .. ', ' .. work.area.right_bottom.y .. ')')
        end
        game.print("Please restart them manually.")
    end
    storage.gaddhi_sd_data = nil
end
