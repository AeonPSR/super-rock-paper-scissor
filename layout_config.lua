-- layout_config.lua
-- All layout and UI-related variables for the game

local layout = {}
layout.screenWidth = 1280  -- Default window width
layout.screenHeight = 720  -- Default window height

-- UI red rectangle (the block containing the drawing area and validation)
-- The width of the UI block will be calculated in main.lua by using the drawing area and buttons width and margins
layout.uiRectHeight = 400  -- Total height of the UI block

-- Margin settings for UI rectangle centering
layout.marginVerticalBoard = 60 -- Margin on left/right
layout.uiRectMarginTop = 60    -- Minimum space from the top edge of the window (used as fallback)

-- Percentage of total available margin to place on the left and top (0-1)
-- For example, 0.3 means 30% of the available margin is on the left/top, the rest is on the right/bottom
layout.uiRectMarginLeftPercent = 1 -- Default: center (50% left, 50% right)
layout.uiRectMarginTopPercent = 1  -- Default: center (50% top, 50% bottom)

-- Drawing area (inside the UI rectangle)
-- layout.drawAreaWidth = 500   -- Drawing area width
layout.drawAreaHeight = 300  -- Drawing area height
layout.uiRecInnerVerticalMargin = 30 -- Space between drawing area and buttons

-- Button sizes and positions (inside the UI rectangle)
layout.buttonWidth = 180
layout.buttonHeight = 60
layout.buttonSpacing = 30 -- Vertical space between buttons
layout.blockMarginBottom = 40     -- Space from the bottom edge of the UI block



-- BoardContainer (blue rectangle to the left of the UI block)
layout.boardContainer = {}
layout.boardContainer.width = nil -- If nil, will use all space to the left of the UI block
layout.boardContainer.height = 480 -- If nil, will use 2/3 of the UI block height
layout.boardContainer.marginTop = 0
layout.boardContainer.marginBottom = 0
layout.boardContainer.marginLeft = 0
layout.boardContainer.marginRight = 0


return layout
