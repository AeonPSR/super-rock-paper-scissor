package.path = package.path .. ";../?.lua"
local layout = require("layout")
local templates = layout.shape_templates

local templateNames = {}
for name in pairs(templates) do table.insert(templateNames, name) end
table.sort(templateNames)

local current = 1
local drawing = false
local userStroke = {}
local userStrokes = {}
local matchPercents = {}

function love.keypressed(key)
    if key == "right" or key == "d" then
        current = current % #templateNames + 1
        userStroke = {}
        userStrokes = {}
    elseif key == "left" or key == "a" then
        current = (current - 2) % #templateNames + 1
        userStroke = {}
        userStrokes = {}
    elseif key == "return" or key == "space" then
        if #userStroke > 0 then
            table.insert(userStrokes, userStroke)
            userStroke = {}
        end
    elseif key == "backspace" then
        userStroke = {}
        userStrokes = {}
    end
end

function love.mousepressed(x, y, button)
    if button == 1 then
        local boxX, boxY, boxW, boxH = 100, 100, 400, 400
        if x >= boxX and x <= boxX + boxW and y >= boxY and y <= boxY + boxH then
            drawing = true
            userStroke = {}
        end
    end
end

function love.mousemoved(x, y, dx, dy, istouch)
    if drawing then
        local boxX, boxY, boxW, boxH = 100, 100, 400, 400
        if x >= boxX and x <= boxX + boxW and y >= boxY and y <= boxY + boxH then
            local nx = (x - boxX) / boxW
            local ny = (y - boxY) / boxH
            table.insert(userStroke, {x = nx, y = ny})
        end
    end
end

function love.mousereleased(x, y, button)
    if button == 1 and drawing then
        drawing = false
        if #userStroke > 0 then
            table.insert(userStrokes, userStroke)
            userStroke = {}
        end
    end
end

-- Simple template matching for debug (copy of recognizer logic)
local function dist(a, b)
    return math.sqrt((a.x - b.x)^2 + (a.y - b.y)^2)
end
local function resamplePath(path, n)
    if #path < 2 then return path end
    local totalLength = 0
    for i = 2, #path do totalLength = totalLength + dist(path[i-1], path[i]) end
    local interval = totalLength / (n-1)
    local D = 0
    local newPath = {path[1]}
    local prev = path[1]
    local i = 2
    while i <= #path do
        local d = dist(prev, path[i])
        if (D + d) >= interval then
            local t = (interval - D) / d
            local nx = prev.x + t * (path[i].x - prev.x)
            local ny = prev.y + t * (path[i].y - prev.y)
            local newpt = {x = nx, y = ny}
            table.insert(newPath, newpt)
            prev = newpt
            D = 0
        else
            D = D + d
            prev = path[i]
            i = i + 1
        end
    end
    while #newPath < n do
        table.insert(newPath, {x = path[#path].x, y = path[#path].y})
    end
    return newPath
end
local function normalizePath(path)
    local minX, maxX = path[1].x, path[1].x
    local minY, maxY = path[1].y, path[1].y
    for _, p in ipairs(path) do
        minX = math.min(minX, p.x)
        maxX = math.max(maxX, p.x)
        minY = math.min(minY, p.y)
        maxY = math.max(maxY, p.y)
    end
    local width = maxX - minX
    local height = maxY - minY
    local scale = math.max(width, height)
    local norm = {}
    for _, p in ipairs(path) do
        table.insert(norm, {x = (p.x - minX) / scale, y = (p.y - minY) / scale})
    end
    return norm
end
local function pathDistance(p1, p2)
    local sum = 0
    for i = 1, #p1 do sum = sum + dist(p1[i], p2[i]) end
    return sum / #p1
end
local function strokesDistance(userStrokes, tmplStrokes, N)
    if #userStrokes ~= #tmplStrokes then return math.huge end
    local total = 0
    for i = 1, #userStrokes do
        local upath = normalizePath(resamplePath(userStrokes[i], N))
        local tpath = normalizePath(resamplePath(tmplStrokes[i], N))
        total = total + pathDistance(upath, tpath)
    end
    return total / #userStrokes
end
local function getMatchPercents(userStrokes)
    local N = 16
    local percents = {}
    for _, name in ipairs(templateNames) do
        local tmpl = templates[name]
        local d = strokesDistance(userStrokes, tmpl, N)
        percents[name] = (d == math.huge) and 0 or math.max(0, 1 - d)
    end
    return percents
end

function love.update(dt)
    matchPercents = getMatchPercents(userStrokes)
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

    -- Draw user strokes
    for si, stroke in ipairs(userStrokes) do
        love.graphics.setColor(0.2, 1, 0.2, 1)
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
            love.graphics.setColor(0.2, 1, 0.2)
            love.graphics.circle("fill", boxX + p.x * boxW, boxY + p.y * boxH, 4)
        end
    end
    -- Draw current stroke (not yet committed)
    love.graphics.setColor(1, 1, 0.2, 1)
    if #userStroke > 1 then
        for i = 2, #userStroke do
            local p1 = userStroke[i-1]
            local p2 = userStroke[i]
            love.graphics.line(
                boxX + p1.x * boxW, boxY + p1.y * boxH,
                boxX + p2.x * boxW, boxY + p2.y * boxH
            )
        end
    end
    for _, p in ipairs(userStroke) do
        love.graphics.circle("fill", boxX + p.x * boxW, boxY + p.y * boxH, 4)
    end

    -- Draw match percent for current template
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(string.format("Accuracy: %d%%", math.floor((matchPercents[name] or 0) * 100 + 0.5)), boxX + boxW + 30, boxY + boxH/2 - 16, 200, "left")
end