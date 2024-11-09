data:extend({
    {
        type = "selection-tool",
        name = "gaddhi-sd-mark-region",
        select = {
            border_color = { r = 1, g = 0.1, b = 0.1 },
            mode = {"items-to-place"},
            cursor_box_type = "entity"
        },
        alt_select = {
            border_color = { r = 1, g = 0.1, b = 0.1 },
            mode = {"items-to-place"},
            cursor_box_type = "entity"
        },
        stack_size = 1,

        always_include_tiles = true,
        mouse_cursor = "selection-tool-cursor",

        icon = "__sensible-deconstruction__/icon.png",
        icon_size = 32,
        flags = {"only-in-cursor", "spawnable"},
        subgroup = "tool",
    },


    -- This is the hotkey for initializing a deconstruction area.
    {
        type = 'custom-input',
        name = 'gaddhi-sd-mark-region-key',
        -- TODO: make key configurable

        key_sequence = 'CONTROL + SHIFT + D',
        consuming = nil,
        item_to_spawn = "gaddhi-sd-mark-region",
        action = "spawn-item"
    }
})
