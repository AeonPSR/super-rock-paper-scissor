package.path = package.path .. ";../?.lua"
local layout = require("layout")
local shape_recognizer = require("shape_recognizer")
local DrawingTool = require("drawing_tool")
local templates = layout.shape_templates

local templateNames = {}
for name in pairs(templates) do table.insert(templateNames, name) end
table.sort(templateNames)

local current = 1
local drawingTool = nil
local matchPercents = {}

function love.load()
    -- Create drawing tool
    local boxX, boxY, boxW, boxH = 100, 100, 400, 400
    drawingTool = DrawingTool.new(boxX, boxY, boxW, boxH, {
        max_strokes = 10,
        max_points = 1000,
        line_width = 2,
        stroke_color = {0.2, 1, 0.2, 1}, -- green for user strokes
        background_color = {0, 0, 0, 0}, -- transparent background so template shows through
        border_color = {1, 1, 1, 1} -- white border
    })
end

function love.keypressed(key)
    if key == "right" or key == "d" then
        current = current % #templateNames + 1
        if drawingTool then
            drawingTool:clear()
        end
    elseif key == "left" or key == "a" then
        current = (current - 2) % #templateNames + 1
        if drawingTool then
            drawingTool:clear()
        end
    elseif key == "return" or key == "space" then
        -- For multi-stroke drawing, this could commit current stroke
        -- For now, we'll just clear to start fresh
        if drawingTool then
            drawingTool:clear()
        end
    elseif key == "backspace" then
        if drawingTool then
            drawingTool:clear()
        end
    end
end

function love.mousepressed(x, y, button)
    if drawingTool then
        drawingTool:mousepressed(x, y, button)
    end
end

function love.mousemoved(x, y, dx, dy, istouch)
    if drawingTool then
        drawingTool:mousemoved(x, y, dx, dy, istouch)
    end
end

function love.mousereleased(x, y, button)
    if drawingTool then
        drawingTool:mousereleased(x, y, button)
    end
end

function love.update(dt)
    local userStrokes = drawingTool and drawingTool:getNormalizedStrokes() or {}
    if #userStrokes > 0 then
        local _, percentages = shape_recognizer.recognizeShape(userStrokes)
        matchPercents = percentages or {}
    else
        matchPercents = {}
    end
end

function love.draw()
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
    
    -- Draw template in normalized view
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
    
    -- Draw user's normalized points in preview
    local userStrokes = drawingTool and drawingTool:getStrokes() or {}
    if #userStrokes > 0 then
        local processedStrokes = shape_recognizer.getProcessedStrokes(userStrokes)
        love.graphics.setColor(0.2, 1, 1, 1) -- cyan for normalized points
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
    end

    -- Draw match percent for current template (positioned below the normalized preview)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(string.format("Accuracy: %d%%", math.floor((matchPercents[name] or 0) * 100 + 0.5)), boxX + boxW + 30, previewY + previewH + 20, 200, "left")
    
    -- Draw legend (positioned below the accuracy rating)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Legend:", boxX + boxW + 30, previewY + previewH + 50)
    
    -- Template points (red)
    love.graphics.setColor(1, 0.5, 0.5)
    love.graphics.circle("fill", boxX + boxW + 40, previewY + previewH + 70, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Template", boxX + boxW + 55, previewY + previewH + 65)
    
    -- User drawing points (green)
    love.graphics.setColor(0.2, 1, 0.2)
    love.graphics.circle("fill", boxX + boxW + 40, previewY + previewH + 90, 4)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Your drawing", boxX + boxW + 55, previewY + previewH + 85)
    
    -- Resampled points (magenta)
    love.graphics.setColor(1, 0.2, 1)
    love.graphics.circle("fill", boxX + boxW + 40, previewY + previewH + 110, 6)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Resampled (16pt)", boxX + boxW + 55, previewY + previewH + 105)
    
    -- Normalized points (cyan)
    love.graphics.setColor(0.2, 1, 1)
    love.graphics.circle("fill", boxX + boxW + 40, previewY + previewH + 130, 3)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Normalized (used for matching)", boxX + boxW + 55, previewY + previewH + 125)
end