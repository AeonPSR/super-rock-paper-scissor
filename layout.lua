-- layout.lua
-- Centralized layout configuration for shape templates and UI

return {
    -- Example: shape templates for recognizer (multi-stroke)
    shape_templates = {
        rock = {
            { -- one closed stroke (circle)
                {x=0.5, y=0.1}, {x=0.8, y=0.3}, {x=0.9, y=0.5}, {x=0.8, y=0.7}, {x=0.5, y=0.9}, {x=0.2, y=0.7}, {x=0.1, y=0.5}, {x=0.2, y=0.3}, {x=0.5, y=0.1}
            }
        },
        paper = {
            { -- one closed stroke (rectangle)
                {x=0.1, y=0.1}, {x=0.9, y=0.1}, {x=0.9, y=0.9}, {x=0.1, y=0.9}, {x=0.1, y=0.1}
            }
        },
        scissors = {
            -- two strokes for a cross
            {
                {x=0.2, y=0.2}, {x=0.8, y=0.8}
            },
            {
                {x=0.8, y=0.2}, {x=0.2, y=0.8}
            }
        }
    }
}
