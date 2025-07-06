local M = {}

-- Helper: distance between two points
local function dist(a, b)
    return math.sqrt((a.x - b.x)^2 + (a.y - b.y)^2)
end

-- Helper: resample a path to N points (for normalization)
local function resamplePath(path, n)
    if #path < 2 then return path end
    local totalLength = 0
    for i = 2, #path do
        totalLength = totalLength + dist(path[i-1], path[i])
    end
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

-- Helper: normalize path (translate to origin, scale to fit box)
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

-- Example templates (multi-stroke)
local layout = require("layout")
local templates = layout.shape_templates

-- Compute average distance between two paths (assume same length)
local function pathDistance(p1, p2)
    local sum = 0
    for i = 1, #p1 do
        sum = sum + dist(p1[i], p2[i])
    end
    return sum / #p1
end

-- Multi-stroke template matching
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

-- Main recognition function (multi-stroke template matching)
function M.recognizeShape(strokes)
    -- Remove empty strokes
    local filtered = {}
    for _, s in ipairs(strokes) do if #s > 0 then table.insert(filtered, s) end end
    if #filtered == 0 or #filtered[1] < 2 then
        return nil, "Draw a bigger shape!"
    end
    local N = 16
    local bestMatch, bestDist = nil, math.huge
    local allScores = {}
    for name, tmpl in pairs(templates) do
        local d = strokesDistance(filtered, tmpl, N)
        allScores[name] = d
        if d < bestDist then
            bestDist = d
            bestMatch = name
        end
    end
    -- Normalize scores to [0,1] and invert so that 1 = best match, 0 = worst
    local matchPercents = {}
    local maxDist = 0
    for _, d in pairs(allScores) do if d > maxDist and d < math.huge then maxDist = d end end
    for name, d in pairs(allScores) do
        if d == math.huge then
            matchPercents[name] = 0
        else
            -- Lower distance = better match
            matchPercents[name] = math.max(0, 1 - (d / (maxDist > 0 and maxDist or 1)))
        end
    end
    if bestDist < 0.25 then
        return bestMatch, matchPercents
    else
        return nil, matchPercents
    end
end

return M
