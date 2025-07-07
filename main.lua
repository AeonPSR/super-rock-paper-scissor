local choices = {"rock", "paper", "scissors"}
local playerMove = nil
local opponentMove = nil
local result = ""
local ShapeRecognizer = require("shape_recognizer")
local layout = require("layout_config")
local DrawingTool = require("drawing_tool")

-- Drawing state
local drawingTool = nil

local drawingConfig = require("drawing_config")
local RECOGNITION_THRESHOLD = drawingConfig.recognition_threshold or 0.05


-- Icon images
local iconImages = {}
local recognizedMove = nil -- holds the move detected by recognition, but not yet validated


-- Layout state (will be updated in love.load and love.resize)
local screenW, screenH, buttonW, buttonH, buttonSpacing, buttonX
local validateButton = {}
local resetButton = {}
local drawArea = {}


local function updateLayout()
    screenW = love.graphics.getWidth()
    screenH = love.graphics.getHeight()
    buttonW = layout.buttonWidth
    buttonH = layout.buttonHeight
    buttonSpacing = layout.buttonSpacing

    -- Calculate UI rectangle width: left margin + drawing area + spacing + button + right margin
    local marginBoard = layout.marginVerticalBoard
    local drawAreaW = layout.drawAreaWidth or 500 -- fallback if not set
    local uiRectW = marginBoard + drawAreaW + layout.uiRecInnerVerticalMargin + buttonW + marginBoard
    local uiRectH = layout.uiRectHeight

    -- Calculate available space for margins
    local totalMarginX = screenW - uiRectW
    local totalMarginY = screenH - uiRectH
    local leftPercent = layout.uiRectMarginLeftPercent or 0.5
    local topPercent = layout.uiRectMarginTopPercent or 0.5
    local minLeft = layout.marginVerticalBoard or 0
    local minTop = layout.uiRectMarginTop or 0
    local marginX = math.max(minLeft, math.floor(totalMarginX * leftPercent))
    local marginY = math.max(minTop, math.floor(totalMarginY * topPercent))

    -- All content is now positioned relative to the UI rectangle (marginX, marginY)
    -- Button block (bottom right of UI rect)
    local buttonBlockHeight = buttonH * 2 + buttonSpacing
    local buttonX = marginX + marginBoard + drawAreaW + layout.uiRecInnerVerticalMargin
    local buttonBlockY = marginY + uiRectH - layout.blockMarginBottom - buttonBlockHeight

    validateButton.x = buttonX
    validateButton.y = buttonBlockY
    validateButton.w = buttonW
    validateButton.h = buttonH

    resetButton.x = buttonX
    resetButton.y = buttonBlockY + buttonH + buttonSpacing
    resetButton.w = buttonW
    resetButton.h = buttonH

    -- Drawing area (left of UI rect)
    drawArea.w = drawAreaW
    drawArea.h = layout.drawAreaHeight
    drawArea.x = marginX + marginBoard
    drawArea.y = marginY + uiRectH - layout.blockMarginBottom - drawArea.h

    -- Store for use in love.draw (for debug rectangle, etc)
    layout._uiRectX = marginX
    layout._uiRectY = marginY
    layout._uiRectW = uiRectW
    layout._uiRectH = uiRectH
end

function love.load()
    font = love.graphics.newFont(24)
    love.graphics.setFont(font)
    -- Set fixed window size (disable resizing for now)
    if love.window and love.window.setMode then
        love.window.setMode(layout.screenWidth or 1280, layout.screenHeight or 720) -- default size from layout.lua
        -- love.window.setMode(layout.screenWidth, layout.screenHeight, {resizable = true}) -- (deactivated)
    end
    -- Load icons
    iconImages.rock = love.graphics.newImage("assets/icons/icon_rock.png")
    iconImages.paper = love.graphics.newImage("assets/icons/icon_paper.png")
    iconImages.scissors = love.graphics.newImage("assets/icons/icon_scissor.png")
    updateLayout()
    
    -- Create drawing tool
    drawingTool = DrawingTool.new(0, 0, 400, 400, {
        max_strokes = drawingConfig.max_strokes,
        max_points = drawingConfig.max_points,
        line_width = 2,
        stroke_color = {1, 1, 1, 1},
        background_color = {0.9, 0.9, 1, 0.2},
        border_color = {0.2, 0.2, 0.5, 1}
    })
end

function love.resize(w, h)
    updateLayout()
    -- Update drawing tool bounds
    if drawingTool then
        drawingTool:setBounds(drawArea.x, drawArea.y, drawArea.w, drawArea.h)
    end
end

function love.mousepressed(x, y, button)
    if button == 1 then
        -- Check if validate button is pressed
        if x >= validateButton.x and x <= validateButton.x + validateButton.w and y >= validateButton.y and y <= validateButton.y + validateButton.h then
            if recognizedMove then
                choose(recognizedMove)
                resetDrawingArea()
            else
                result = "No move recognized. Draw a shape first."
            end
            return
        end
        -- Check if reset button is pressed
        if x >= resetButton.x and x <= resetButton.x + resetButton.w and y >= resetButton.y and y <= resetButton.y + resetButton.h then
            resetDrawingArea()
            return
        end
        -- Handle drawing
        if drawingTool then
            drawingTool:mousepressed(x, y, button)
        end
    end
end

function love.mousemoved(x, y, dx, dy, istouch)
    if drawingTool then
        drawingTool:mousemoved(x, y, dx, dy, istouch)
    end
    
    -- Live recognition: update recognizedMove as user draws
    -- Pass all strokes (multi-stroke) directly to recognizer
    local strokes = drawingTool and drawingTool:getStrokes() or {}
    if #strokes > 0 and #strokes[1] > 1 then
        local shape, matchPercents = ShapeRecognizer.recognizeShape(strokes)
        if shape == "rock" or shape == "paper" or shape == "scissors" then
            recognizedMove = shape
        else
            -- Pick the most likely move if available
            if matchPercents then
                local best, bestScore = nil, -1
                for move, score in pairs(matchPercents) do
                    if score > bestScore then
                        best = move
                        bestScore = score
                    end
                end
                if bestScore > RECOGNITION_THRESHOLD then -- Only show if above threshold from config
                    recognizedMove = best
                else
                    recognizedMove = nil
                end
            else
                recognizedMove = nil
            end
        end
        -- Store matchPercents for debug display
        _G._matchPercents = matchPercents
    else
        recognizedMove = nil
        _G._matchPercents = nil
    end
end

function love.mousereleased(x, y, button)
    if drawingTool then
        drawingTool:mousereleased(x, y, button)
    end
end

function choose(move)
    playerMove = move
    opponentMove = choices[math.random(#choices)]
    result = getResult(playerMove, opponentMove)
end

function resetDrawingArea()
    if drawingTool then
        drawingTool:clear()
    end
    result = ""
    playerMove = nil
    opponentMove = nil
    recognizedMove = nil
end

function getResult(p1, p2)
    if p1 == p2 then
        return "Draw!"
    elseif (p1 == "rock" and p2 == "scissors")
        or (p1 == "scissors" and p2 == "paper")
        or (p1 == "paper" and p2 == "rock") then
        return "You win!"
    else
        return "You lose!"
    end
end

-- Debug mode global variable
-- 0 = off, 1 = on
_G.debug = 0

function love.keypressed(key)
    if key == "p" then
        if _G.debug == 0 then
            _G.debug = 1
        else
            _G.debug = 0
        end
    end
end

function love.draw()
    -- Draw BoardContainer (blue rectangle to the left of the red UI block)
    local boardMarginTop = layout.boardContainer and layout.boardContainer.marginTop or 0
    local boardMarginBottom = layout.boardContainer and layout.boardContainer.marginBottom or 0
    local boardMarginLeft = layout.boardContainer and layout.boardContainer.marginLeft or 0
    local boardMarginRight = layout.boardContainer and layout.boardContainer.marginRight or 0
    local boardW = (layout.boardContainer and layout.boardContainer.width) or (layout._uiRectX - boardMarginLeft - boardMarginRight)
    local boardH = (layout.boardContainer and layout.boardContainer.height) or (love.graphics.getHeight() * (2/3) - boardMarginTop - boardMarginBottom)
    local boardX = boardMarginLeft
    local boardY = layout._uiRectY + layout._uiRectH - boardH - boardMarginBottom
    if _G.debug == 1 then
        love.graphics.setColor(0.2, 0.4, 1, 0.3)
        love.graphics.rectangle("fill", boardX, boardY, boardW, boardH)
        love.graphics.setColor(0.2, 0.4, 1, 1)
        love.graphics.rectangle("line", boardX, boardY, boardW, boardH)
        love.graphics.setColor(1, 1, 1, 1)
    end

    -- Draw UI rectangle (debug: red border)
    if _G.debug == 1 then
        love.graphics.setColor(1, 0, 0, 0.3)
        love.graphics.rectangle("fill", layout._uiRectX, layout._uiRectY, layout._uiRectW, layout._uiRectH)
        love.graphics.setColor(1, 0, 0, 1)
        love.graphics.rectangle("line", layout._uiRectX, layout._uiRectY, layout._uiRectW, layout._uiRectH)
        love.graphics.setColor(1, 1, 1, 1)
    end

    -- Draw drawing area and user's drawing
    if drawingTool then
        -- Update drawing tool bounds in case layout changed
        drawingTool:setBounds(drawArea.x, drawArea.y, drawArea.w, drawArea.h)
        
        if _G.debug == 1 then
            drawingTool:drawDebug()
        else
            drawingTool:draw()
        end
    end

    -- Draw icon for recognized move above the validate button
    if recognizedMove and iconImages[recognizedMove] then
        local icon = iconImages[recognizedMove]
        local iconW, iconH = icon:getWidth(), icon:getHeight()
        local iconScale = math.min(validateButton.w / iconW, 1)
        local iconX = validateButton.x + (validateButton.w - iconW * iconScale) / 2
        local iconY = validateButton.y - iconH * iconScale - 10
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(icon, iconX, iconY, 0, iconScale, iconScale)
    end

    -- Draw validate button
    love.graphics.setColor(0.2, 0.8, 0.2, 1)
    love.graphics.rectangle("fill", validateButton.x, validateButton.y, validateButton.w, validateButton.h)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", validateButton.x, validateButton.y, validateButton.w, validateButton.h)
    love.graphics.printf("Validate", validateButton.x, validateButton.y + 18, validateButton.w, "center")

    -- Draw reset button
    love.graphics.setColor(0.8, 0.2, 0.2, 1)
    love.graphics.rectangle("fill", resetButton.x, resetButton.y, resetButton.w, resetButton.h)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", resetButton.x, resetButton.y, resetButton.w, resetButton.h)
    love.graphics.printf("Reset", resetButton.x, resetButton.y + 18, resetButton.w, "center")

    -- Display stroke/point debug info (top left corner)
    if _G.debug == 1 then
        local strokes = drawingTool and drawingTool:getStrokes() or {}
        local numStrokes = #strokes
        local numPoints = drawingTool and drawingTool:getTotalPoints() or 0
        love.graphics.setColor(1, 1, 0, 1)
        love.graphics.print("Strokes: " .. numStrokes .. "  Points: " .. numPoints, 10, 10)
        love.graphics.setColor(1, 1, 1, 1)

        -- Debug: show icon and match % for each move
        local y = 40
        local x = 10
        local iconSize = 32
        local moves = {"rock", "paper", "scissors"}
        for _, move in ipairs(moves) do
            local percent = _G._matchPercents and _G._matchPercents[move] or 0
            if iconImages[move] then
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(iconImages[move], x, y, 0, iconSize / iconImages[move]:getWidth(), iconSize / iconImages[move]:getHeight())
            end
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(string.format("%s: %d%%", move, math.floor(percent * 100 + 0.5)), x + iconSize + 8, y + 8)
            y = y + iconSize + 8
        end
    end

    -- Display result
    if playerMove then
        love.graphics.printf("You chose: " .. playerMove, 0, 100, drawArea.x + drawArea.w, "left")
        love.graphics.printf("Opponent chose: " .. opponentMove, 0, 140, drawArea.x + drawArea.w, "left")
        love.graphics.printf(result, 0, 180, drawArea.x + drawArea.w, "left")
    else
        love.graphics.printf("Draw a shape to play!", 0, 100, drawArea.x + drawArea.w, "left")
    end
end