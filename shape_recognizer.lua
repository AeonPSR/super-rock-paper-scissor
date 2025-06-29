
local M = {}

-- Helper: distance between two points
local function dist(a, b)
    return math.sqrt((a.x - b.x)^2 + (a.y - b.y)^2)
end

-- Counts how many times the path changes direction sharply
function M.countCorners(path)
    local corners = 0
    for i = 2, #path - 1 do
        local a = path[i - 1]
        local b = path[i]
        local c = path[i + 1]

        local dx1 = b.x - a.x
        local dy1 = b.y - a.y
        local dx2 = c.x - b.x
        local dy2 = c.y - b.y

        local dot = dx1 * dx2 + dy1 * dy2
        local mag1 = math.sqrt(dx1*dx1 + dy1*dy1)
        local mag2 = math.sqrt(dx2*dx2 + dy2*dy2)
        if mag1 > 0 and mag2 > 0 then
            local angle = math.acos(math.max(-1, math.min(1, dot / (mag1 * mag2))))
            if angle > math.rad(60) then
                corners = corners + 1
            end
        end
    end
    return corners
end

-- Checks if path is closed
local function isClosed(path)
    return dist(path[1], path[#path]) < 30
end

-- Main recognition function
function M.recognizeShape(path)
    if #path < 10 then
        return nil, "Draw a bigger shape!"
    end

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
    local aspect = width / height

    local corners = M.countCorners(path)
    local closed = isClosed(path)

    -- Cross: many corners, not closed, aspect ~1
    if corners >= 6 and not closed then
        return "scissors"
    end

    -- Square: closed, 4 corners, aspect ~1
    if closed and corners >= 3 and corners <= 6 and aspect > 0.8 and aspect < 1.2 then
        return "paper"
    end

    -- Circle: closed, few corners, aspect ~1
    if closed and corners <= 2 and aspect > 0.7 and aspect < 1.3 then
        return "rock"
    end

    return nil
end

return M
