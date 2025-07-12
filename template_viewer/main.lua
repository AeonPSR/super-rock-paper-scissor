package.path = package.path .. ";../?.lua"
local layout = require("layout")
local shape_recognizer = require("shape_recognizer")
local shape_recognizer_agnostic = require("shape_recognizer_agnostic")
local DrawingTool = require("drawing_tool")
local templates = layout.shape_templates

local templateNames = {}
for name in pairs(templates) do table.insert(templateNames, name) end
table.sort(templateNames)

local current = 1
local drawingTool = nil
local testDrawingTool = nil
local matchPercents = {}
local agnosticMatchPercents = {}
local testMode = false -- false = detailed view, true = test all shapes view
local debugMessages = {} -- Store debug messages to display on screen

-- Button properties
local buttonX = 10
local buttonY = 10
local buttonW = 140
local buttonH = 30

-- Reset button properties (for test mode)
local resetButtonX = 50
local resetButtonY = 360  -- Below the drawing area (150 + 200 + 10)
local resetButtonW = 200
local resetButtonH = 30

function love.load()
    -- Button positions are already set in the global variables
    
    -- Create drawing tool for detailed view
    local boxX, boxY, boxW, boxH = 100, 100, 400, 400
    drawingTool = DrawingTool.new(boxX, boxY, boxW, boxH, {
        max_strokes = 10,
        max_points = 1000,
        line_width = 2,
        stroke_color = {0.2, 1, 0.2, 1}, -- green for user strokes
        background_color = {0, 0, 0, 0}, -- transparent background so template shows through
        border_color = {1, 1, 1, 1} -- white border
    })
    
    -- Create smaller drawing tool for test mode
    local testBoxX, testBoxY, testBoxW, testBoxH = 50, 150, 200, 200
    testDrawingTool = DrawingTool.new(testBoxX, testBoxY, testBoxW, testBoxH, {
        max_strokes = 10,
        max_points = 1000,
        line_width = 2,
        stroke_color = {0.2, 1, 0.2, 1},
        background_color = {0.1, 0.1, 0.1, 1},
        border_color = {1, 1, 1, 1}
    })
end

function love.keypressed(key)
    if key == "tab" then
        -- Toggle between detailed view and test mode
        testMode = not testMode
        if drawingTool then drawingTool:clear() end
        if testDrawingTool then testDrawingTool:clear() end
    elseif not testMode then
        -- Detailed view controls
        if key == "right" or key == "d" then
            current = current % #templateNames + 1
            if drawingTool then drawingTool:clear() end
        elseif key == "left" or key == "a" then
            current = (current - 2) % #templateNames + 1
            if drawingTool then drawingTool:clear() end
        elseif key == "return" or key == "space" then
            if drawingTool then drawingTool:clear() end
        elseif key == "backspace" then
            if drawingTool then drawingTool:clear() end
        end
    else
        -- Test mode controls
        if key == "return" or key == "space" or key == "backspace" then
            if testDrawingTool then testDrawingTool:clear() end
        end
    end
end

function love.mousepressed(x, y, button)
    -- Check if mode toggle button was clicked
    if x >= buttonX and x <= buttonX + buttonW and y >= buttonY and y <= buttonY + buttonH then
        -- Toggle mode
        testMode = not testMode
        if drawingTool then drawingTool:clear() end
        if testDrawingTool then testDrawingTool:clear() end
        return -- Don't pass to drawing tools
    end
    
    -- Check if reset button was clicked (only in test mode)
    if testMode and x >= resetButtonX and x <= resetButtonX + resetButtonW and y >= resetButtonY and y <= resetButtonY + resetButtonH then
        if testDrawingTool then testDrawingTool:clear() end
        return -- Don't pass to drawing tools
    end
    
    -- Pass to appropriate drawing tool
    local currentTool = testMode and testDrawingTool or drawingTool
    if currentTool then
        currentTool:mousepressed(x, y, button)
    end
end

function love.mousemoved(x, y, dx, dy, istouch)
    local currentTool = testMode and testDrawingTool or drawingTool
    if currentTool then
        currentTool:mousemoved(x, y, dx, dy, istouch)
    end
end

function love.mousereleased(x, y, button)
    local currentTool = testMode and testDrawingTool or drawingTool
    if currentTool then
        currentTool:mousereleased(x, y, button)
    end
end

function love.update(dt)
    local currentTool = testMode and testDrawingTool or drawingTool
    local userStrokes = currentTool and currentTool:getNormalizedStrokes() or {}
    if #userStrokes > 0 then
        local _, percentages = shape_recognizer.recognizeShape(userStrokes)
        matchPercents = percentages or {}
        
        local _, agnosticPercentages = shape_recognizer_agnostic.recognizeShape(userStrokes)
        agnosticMatchPercents = agnosticPercentages or {}
    else
        matchPercents = {}
        agnosticMatchPercents = {}
    end
end

function love.draw()
    if testMode then
        drawTestMode()
    else
        drawDetailedMode()
    end
    drawModeButton()
    if testMode then
        drawResetButton()
    end
end

function drawModeButton()
    -- Draw button background
    love.graphics.setColor(0.3, 0.3, 0.3, 1)
    love.graphics.rectangle("fill", buttonX, buttonY, buttonW, buttonH)
    
    -- Draw button border
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", buttonX, buttonY, buttonW, buttonH)
    
    -- Draw button text
    local buttonText = testMode and "Detailed View" or "Test Mode"
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(buttonText, buttonX, buttonY + buttonH/2 - 6, buttonW, "center")
end

function drawResetButton()
    -- Draw reset button background
    love.graphics.setColor(0.5, 0.2, 0.2, 1) -- Reddish background
    love.graphics.rectangle("fill", resetButtonX, resetButtonY, resetButtonW, resetButtonH)
    
    -- Draw reset button border
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", resetButtonX, resetButtonY, resetButtonW, resetButtonH)
    
    -- Draw reset button text
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Clear Drawing", resetButtonX, resetButtonY + resetButtonH/2 - 6, resetButtonW, "center")
end

function drawTestMode()
    love.graphics.setBackgroundColor(0.12, 0.12, 0.12)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Shape Recognition Test", 0, 10, love.graphics.getWidth(), "center")
    love.graphics.printf("Draw in the box | Tab or click button to switch views | Space/Enter/Backspace: clear", 0, 30, love.graphics.getWidth(), "center")

    -- Draw the small drawing area
    if testDrawingTool then
        testDrawingTool:draw()
    end

    -- Clear debug messages for this frame
    debugMessages = {}
    
    -- Load and display icons with percentages
    local iconSize = 64
    local startX = 300
    local startY = 100
    local cols = 3
    local spacing = 120
    
    for i, name in ipairs(templateNames) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local x = startX + col * spacing
        local y = startY + row * spacing
        
        -- Load icon using the symbolic link
        local iconPath = "assets/icons/icon_" .. name .. ".png"
        local success, icon = pcall(love.graphics.newImage, iconPath)
        
        if success then
            table.insert(debugMessages, "Icon " .. name .. ": loaded successfully")
        else
            table.insert(debugMessages, "Icon " .. name .. ": failed to load")
        end
        
        if success and icon then
            love.graphics.setColor(1, 1, 1, 1)
            local scaleX = iconSize / icon:getWidth()
            local scaleY = iconSize / icon:getHeight()
            love.graphics.draw(icon, x, y, 0, scaleX, scaleY)
        else
            -- Fallback: draw colored rectangle with name if no icon found
            love.graphics.setColor(0.3, 0.3, 0.3, 1)
            love.graphics.rectangle("fill", x, y, iconSize, iconSize)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.rectangle("line", x, y, iconSize, iconSize)
            love.graphics.printf(name, x, y + iconSize/2 - 10, iconSize, "center")
        end
        
        -- Draw percentages below icon
        local strokePercent = math.floor((matchPercents[name] or 0) * 100 + 0.5)
        local agnosticPercent = math.floor((agnosticMatchPercents[name] or 0) * 100 + 0.5)
        
        love.graphics.setColor(0.2, 1, 1, 1) -- cyan for stroke recognizer
        love.graphics.printf(string.format("S: %d%%", strokePercent), x, y + iconSize + 5, iconSize, "center")
        
        love.graphics.setColor(1, 1, 0.2, 1) -- yellow for agnostic recognizer
        love.graphics.printf(string.format("P: %d%%", agnosticPercent), x, y + iconSize + 20, iconSize, "center")
    end
    
    -- Display debug messages at the bottom of the screen
    love.graphics.setColor(1, 1, 0, 1) -- yellow for debug info
    for i, msg in ipairs(debugMessages) do
        love.graphics.print(msg, 10, love.graphics.getHeight() - 100 + i * 15)
    end
end

function drawDetailedMode()
    love.graphics.setBackgroundColor(0.12, 0.12, 0.12)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Template Viewer", 0, 10, love.graphics.getWidth(), "center")
    love.graphics.printf("Use ←/→ or A/D to switch | Draw in the box | Enter/Space: new stroke | Backspace: clear", 0, 30, love.graphics.getWidth(), "center")

    local name = templateNames[current]
    love.graphics.setColor(1, 1, 0)
    love.graphics.printf(name, 0, 60, love.graphics.getWidth(), "center")

    -- Draw the template in a box
    local boxX, boxY, boxW, boxH = 100, 100, 400, 400
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", boxX, boxY, boxW, boxH)

    -- Draw template strokes
    local strokes = templates[name]
    for si, stroke in ipairs(strokes) do
        love.graphics.setColor(0.6, 0.8, 1, 1)
        if #stroke > 1 then
            for i = 2, #stroke do
                local p1 = stroke[i-1]
                local p2 = stroke[i]
                love.graphics.line(
                    boxX + p1.x * boxW, boxY + p1.y * boxH,
                    boxX + p2.x * boxW, boxY + p2.y * boxH
                )
            end
        end
        for _, p in ipairs(stroke) do
            love.graphics.setColor(1, 0.5, 0.5)
            love.graphics.circle("fill", boxX + p.x * boxW, boxY + p.y * boxH, 5)
        end
    end

    -- Draw user's drawing using the drawing tool (without background, just strokes)
    if drawingTool then
        -- Draw only the strokes, not the background/border (template already provides that)
        love.graphics.setColor(drawingTool.config.stroke_color)
        love.graphics.setLineWidth(drawingTool.config.line_width)
        
        local userStrokes = drawingTool:getStrokes()
        for _, stroke in ipairs(userStrokes) do
            if #stroke > 1 then
                for i = 2, #stroke do
                    local p1 = stroke[i-1]
                    local p2 = stroke[i]
                    love.graphics.line(p1.x, p1.y, p2.x, p2.y)
                end
            end
        end
        
        -- Draw current stroke (if drawing)
        if drawingTool.currentStroke and #drawingTool.currentStroke > 1 then
            love.graphics.setColor(1, 1, 0.2, 1) -- yellow for current stroke
            for i = 2, #drawingTool.currentStroke do
                local p1 = drawingTool.currentStroke[i-1]
                local p2 = drawingTool.currentStroke[i]
                love.graphics.line(p1.x, p1.y, p2.x, p2.y)
            end
        end
        
        -- Draw the individual points (like the original template viewer)
        drawingTool:drawPoints(4, {0.2, 1, 0.2, 1}, {1, 1, 0.2, 1}) -- green for completed strokes, yellow for current
        
        -- Draw resampled points (what the recognizer uses before normalization)
        local userStrokes = drawingTool:getStrokes()
        if #userStrokes > 0 then
            -- Get resampled strokes (before normalization)
            local resampledStrokes = shape_recognizer.getResampledStrokes(userStrokes)
            love.graphics.setColor(1, 0.2, 1, 1) -- magenta for resampled points
            for _, stroke in ipairs(resampledStrokes) do
                for _, point in ipairs(stroke) do
                    love.graphics.circle("fill", point.x, point.y, 6) -- slightly larger circles
                end
            end
        end
        
        -- Reset graphics state
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setLineWidth(1)
    end

    -- Draw small normalized preview window (positioned above accuracy rating)
    local previewX = boxX + boxW + 30
    local previewY = boxY + boxH/2 - 150  -- moved further up
    local previewW = 100
    local previewH = 100
    
    love.graphics.setColor(0.1, 0.1, 0.1, 1)
    love.graphics.rectangle("fill", previewX, previewY, previewW, previewH)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", previewX, previewY, previewW, previewH)
    
    -- Label for normalized preview
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Normalized View", previewX, previewY - 15)
    
    -- Draw template in normalized view (stroke-based recognizer version)
    local name = templateNames[current]
    local templateStrokes = templates[name]
    for _, stroke in ipairs(templateStrokes) do
        love.graphics.setColor(0.6, 0.8, 1, 0.7) -- template lines in preview
        if #stroke > 1 then
            for i = 2, #stroke do
                local p1 = stroke[i-1]
                local p2 = stroke[i]
                love.graphics.line(
                    previewX + p1.x * previewW, previewY + p1.y * previewH,
                    previewX + p2.x * previewW, previewY + p2.y * previewH
                )
            end
        end
        -- Template points
        for _, p in ipairs(stroke) do
            love.graphics.setColor(1, 0.5, 0.5, 0.7)
            love.graphics.circle("fill", previewX + p.x * previewW, previewY + p.y * previewH, 2)
        end
    end
    
    -- Draw agnostic recognizer template points (flattened point cloud)
    local agnosticTemplatePoints = shape_recognizer_agnostic.getProcessedTemplatePoints(name)
    love.graphics.setColor(1, 0.5, 1, 0.8) -- magenta for agnostic template points
    for _, point in ipairs(agnosticTemplatePoints) do
        love.graphics.circle("fill", previewX + point.x * previewW, previewY + point.y * previewH, 3)
    end
    
    -- Draw user's normalized points in preview
    local userStrokes = drawingTool and drawingTool:getStrokes() or {}
    if #userStrokes > 0 then
        -- Stroke-based recognizer points
        local processedStrokes = shape_recognizer.getProcessedStrokes(userStrokes)
        love.graphics.setColor(0.2, 1, 1, 1) -- cyan for stroke-based normalized points
        for _, stroke in ipairs(processedStrokes) do
            -- Draw lines between normalized points
            if #stroke > 1 then
                for i = 2, #stroke do
                    local p1 = stroke[i-1]
                    local p2 = stroke[i]
                    love.graphics.line(
                        previewX + p1.x * previewW, previewY + p1.y * previewH,
                        previewX + p2.x * previewW, previewY + p2.y * previewH
                    )
                end
            end
            -- Draw normalized points
            for _, point in ipairs(stroke) do
                love.graphics.circle("fill", previewX + point.x * previewW, previewY + point.y * previewH, 2)
            end
        end
        
        -- Agnostic recognizer points (flattened point cloud)
        local agnosticUserPoints = shape_recognizer_agnostic.getProcessedUserPoints(userStrokes)
        love.graphics.setColor(1, 1, 0.2, 1) -- yellow for agnostic user points
        for _, point in ipairs(agnosticUserPoints) do
            love.graphics.circle("fill", previewX + point.x * previewW, previewY + point.y * previewH, 4)
        end
    end

    -- Draw match percent for current template (positioned below the normalized preview)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(string.format("Stroke recognizer: %d%%", math.floor((matchPercents[name] or 0) * 100 + 0.5)), boxX + boxW + 30, previewY + previewH + 20, 200, "left")
    
    -- Draw agnostic recognizer match percent
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(string.format("Point-cloud recognizer: %d%%", math.floor((agnosticMatchPercents[name] or 0) * 100 + 0.5)), boxX + boxW + 30, previewY + previewH + 40, 200, "left")
    
    -- Draw legend (positioned below the accuracy ratings)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Legend:", boxX + boxW + 30, previewY + previewH + 70)
    
    -- Template points (red)
    love.graphics.setColor(1, 0.5, 0.5)
    love.graphics.circle("fill", boxX + boxW + 40, previewY + previewH + 90, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Template (stroke)", boxX + boxW + 55, previewY + previewH + 85)
    
    -- Agnostic template points (magenta)
    love.graphics.setColor(1, 0.5, 1)
    love.graphics.circle("fill", boxX + boxW + 40, previewY + previewH + 110, 3)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Template (point-cloud)", boxX + boxW + 55, previewY + previewH + 105)
    
    -- User drawing points (green)
    love.graphics.setColor(0.2, 1, 0.2)
    love.graphics.circle("fill", boxX + boxW + 40, previewY + previewH + 130, 4)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Your drawing", boxX + boxW + 55, previewY + previewH + 125)
    
    -- Resampled points (magenta)
    love.graphics.setColor(1, 0.2, 1)
    love.graphics.circle("fill", boxX + boxW + 40, previewY + previewH + 150, 6)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Resampled (16pt)", boxX + boxW + 55, previewY + previewH + 145)
    
    -- Stroke-based normalized points (cyan)
    love.graphics.setColor(0.2, 1, 1)
    love.graphics.circle("fill", boxX + boxW + 40, previewY + previewH + 170, 2)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Stroke recognizer points", boxX + boxW + 55, previewY + previewH + 165)
    
    -- Agnostic normalized points (yellow)
    love.graphics.setColor(1, 1, 0.2)
    love.graphics.circle("fill", boxX + boxW + 40, previewY + previewH + 190, 4)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Point-cloud recognizer points", boxX + boxW + 55, previewY + previewH + 185)
end