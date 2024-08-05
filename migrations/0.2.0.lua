if table_size(global.gaddhi_sd_data.works) > 0 then
    game.print("Migrating from previous Sensible Deconstruction version.")
    for _, work in pairs(global.gaddhi_sd_data.works) do
    game.print('Removed Sensible Deconstruction on surface "' .. player.surface.name .. '" in area (' .. area.left_top.x .. ', ' .. area.left_top.y .. ') - (' .. area.right_bottom.x .. ', ' .. area.right_bottom.y .. ')')
    end
    game.print("Please restart them manually.")
    global.gaddhi_sd_data.works = {}
end
