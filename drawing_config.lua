-- drawing_config.lua
-- Configuration for drawing limits and shape recognition

return {
    max_strokes = 1000,
    max_points = 20000,
    recognition_threshold = 0.15, -- threshold for shape recognition confidence
    
    -- Shape recognition parameters
    resampling_points = 16,        -- number of points to resample each path to
    match_threshold = 0.4,         -- minimum confidence to accept a shape match (0-1)
    early_exit_threshold = 0.1,    -- stop searching if we find a match this good (0-1)
}
