data:extend({
    {
        type = "selection-tool",
        name = "gaddhi:sd-mark-region",
        stack_size = 1,
        selection_color = { r = 1, g = 0.1, b = 0.1 },
        alt_selection_color = { r = 1, g = 0.1, b = 0.1 },
        selection_mode = {"items-to-place"},
        alt_selection_mode = {"items-to-place"},
        always_include_tiles = true,
        selection_cursor_box_type = "entity",
        alt_selection_cursor_box_type = "entity",
        mouse_cursor = "selection-tool-cursor",

        icon = "__sensible-deconstruction__/icon.png",
        icon_size = 32,
        flags = {"only-in-cursor", "spawnable"},
        subgroup = "tool",
    },


    -- This is the hotkey for initializing a deconstruction area.
    {
        type = 'custom-input',
        name = 'gaddhi:sd-mark-region-key',
        -- TODO: make key configurable

        key_sequence = 'CONTROL + SHIFT + D',
        consuming = nil,
        item_to_spawn = "gaddhi:sd-mark-region",
        action = "spawn-item"
    }
})
