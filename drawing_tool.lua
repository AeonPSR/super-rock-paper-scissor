local M = {}

-- Default configuration
local DEFAULT_CONFIG = {
    max_strokes = 10,
    max_points = 1000,
    line_width = 2,
    stroke_color = {1, 1, 1, 1}, -- white
    background_color = {0.9, 0.9, 1, 0.2}, -- light blue
    border_color = {0.2, 0.2, 0.5, 1}, -- dark blue
}

-- DrawingTool class
local DrawingTool = {}
DrawingTool.__index = DrawingTool

function M.new(x, y, width, height, config)
    local self = setmetatable({}, DrawingTool)
    
    -- Drawing area bounds
    self.x = x or 0
    self.y = y or 0
    self.width = width or 400
    self.height = height or 400
    
    -- Configuration
    self.config = config or {}
    for k, v in pairs(DEFAULT_CONFIG) do
        if self.config[k] == nil then
            self.config[k] = v
        end
    end
    
    -- Drawing state
    self.drawing = false
    self.strokes = {} -- 2D array: each stroke is a table of points
    self.currentStroke = nil
    
    return self
end

function DrawingTool:setBounds(x, y, width, height)
    self.x = x
    self.y = y
    self.width = width
    self.height = height
end

function DrawingTool:isInDrawArea(x, y)
    return x >= self.x and x <= self.x + self.width and y >= self.y and y <= self.y + self.height
end

function DrawingTool:getTotalPoints()
    local total = 0
    for _, stroke in ipairs(self.strokes) do
        total = total + #stroke
    end
    return total
end

function DrawingTool:canAddPoint()
    return #self.strokes < self.config.max_strokes and self:getTotalPoints() < self.config.max_points
end

function DrawingTool:mousepressed(x, y, button)
    if button == 1 and self:isInDrawArea(x, y) and self:canAddPoint() then
        if not self.drawing then
            self.drawing = true
            self.currentStroke = {}
            table.insert(self.strokes, self.currentStroke)
        end
        if self:getTotalPoints() < self.config.max_points then
            table.insert(self.currentStroke, {x = x, y = y})
        end
        return true -- consumed the event
    end
    return false
end

function DrawingTool:mousemoved(x, y, dx, dy, istouch)
    if self.drawing and self:isInDrawArea(x, y) and self.currentStroke then
        if self:getTotalPoints() < self.config.max_points then
            table.insert(self.currentStroke, {x = x, y = y})
        end
        return true -- consumed the event
    end
    return false
end

function DrawingTool:mousereleased(x, y, button)
    if button == 1 and self.drawing then
        self.drawing = false
        self.currentStroke = nil
        return true -- consumed the event
    end
    return false
end

function DrawingTool:clear()
    self.strokes = {}
    self.currentStroke = nil
    self.drawing = false
end

function DrawingTool:getStrokes()
    return self.strokes
end

function DrawingTool:setStrokes(strokes)
    self.strokes = strokes or {}
    self.currentStroke = nil
    self.drawing = false
end

-- Convert absolute coordinates to normalized coordinates (0-1 range)
function DrawingTool:getNormalizedStrokes()
    local normalized = {}
    for _, stroke in ipairs(self.strokes) do
        local normalizedStroke = {}
        for _, point in ipairs(stroke) do
            table.insert(normalizedStroke, {
                x = (point.x - self.x) / self.width,
                y = (point.y - self.y) / self.height
            })
        end
        table.insert(normalized, normalizedStroke)
    end
    return normalized
end

-- Set strokes from normalized coordinates (0-1 range)
function DrawingTool:setNormalizedStrokes(normalizedStrokes)
    self.strokes = {}
    for _, stroke in ipairs(normalizedStrokes) do
        local absoluteStroke = {}
        for _, point in ipairs(stroke) do
            table.insert(absoluteStroke, {
                x = self.x + point.x * self.width,
                y = self.y + point.y * self.height
            })
        end
        table.insert(self.strokes, absoluteStroke)
    end
    self.currentStroke = nil
    self.drawing = false
end

function DrawingTool:draw()
    -- Draw background
    love.graphics.setColor(self.config.background_color)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
    
    -- Draw border
    love.graphics.setColor(self.config.border_color)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
    
    -- Draw strokes
    love.graphics.setColor(self.config.stroke_color)
    love.graphics.setLineWidth(self.config.line_width)
    
    for _, stroke in ipairs(self.strokes) do
        if #stroke > 1 then
            for i = 2, #stroke do
                local p1 = stroke[i-1]
                local p2 = stroke[i]
                love.graphics.line(p1.x, p1.y, p2.x, p2.y)
            end
        end
    end
    
    -- Draw current stroke (if drawing)
    if self.currentStroke and #self.currentStroke > 1 then
        love.graphics.setColor(1, 1, 0.2, 1) -- yellow for current stroke
        for i = 2, #self.currentStroke do
            local p1 = self.currentStroke[i-1]
            local p2 = self.currentStroke[i]
            love.graphics.line(p1.x, p1.y, p2.x, p2.y)
        end
    end
    
    -- Reset graphics state
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

-- Draw only the stroke points as circles (for debugging/visualization)
function DrawingTool:drawPoints(pointRadius, strokeColor, currentStrokeColor)
    pointRadius = pointRadius or 2
    strokeColor = strokeColor or {1, 0, 0, 0.7}
    currentStrokeColor = currentStrokeColor or {1, 1, 0, 0.7}
    
    -- Draw points of completed strokes
    love.graphics.setColor(strokeColor)
    for _, stroke in ipairs(self.strokes) do
        for _, point in ipairs(stroke) do
            love.graphics.circle("fill", point.x, point.y, pointRadius)
        end
    end
    
    -- Draw current stroke points
    if self.currentStroke then
        love.graphics.setColor(currentStrokeColor)
        for _, point in ipairs(self.currentStroke) do
            love.graphics.circle("fill", point.x, point.y, pointRadius)
        end
    end
    
    -- Reset graphics state
    love.graphics.setColor(1, 1, 1, 1)
end

-- Debug drawing with additional info
function DrawingTool:drawDebug()
    self:draw()
    
    -- Draw debug info
    love.graphics.setColor(1, 1, 0, 1)
    love.graphics.print(
        string.format("Strokes: %d/%d  Points: %d/%d", 
            #self.strokes, self.config.max_strokes,
            self:getTotalPoints(), self.config.max_points),
        self.x, self.y - 20
    )
    
    -- Draw points as circles
    love.graphics.setColor(1, 0, 0, 0.7)
    for _, stroke in ipairs(self.strokes) do
        for _, point in ipairs(stroke) do
            love.graphics.circle("fill", point.x, point.y, 2)
        end
    end
    
    -- Draw current stroke points
    if self.currentStroke then
        love.graphics.setColor(1, 1, 0, 0.7)
        for _, point in ipairs(self.currentStroke) do
            love.graphics.circle("fill", point.x, point.y, 2)
        end
    end
    
    -- Reset graphics state
    love.graphics.setColor(1, 1, 1, 1)
end

return M
