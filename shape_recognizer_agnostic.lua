local M = {}

-- Helper: distance between two points
local function dist(a, b)
    if not a or not b then return math.huge end
    return math.sqrt((a.x - b.x)^2 + (a.y - b.y)^2)
end

-- Helper: resample a path to N points
local function resamplePath(path, n)
    if #path < 2 then return path end
    local filteredPath = {}
    for _, point in ipairs(path) do
        if point and point.x and point.y then table.insert(filteredPath, point) end
    end
    if #filteredPath < 2 then return filteredPath end
    local totalLength = 0
    for i = 2, #filteredPath do
        totalLength = totalLength + dist(filteredPath[i-1], filteredPath[i])
    end
    if totalLength == 0 then return filteredPath end
    local interval = totalLength / (n-1)
    local D = 0
    local newPath = {filteredPath[1]}
    local prev = filteredPath[1]
    local i = 2
    while i <= #filteredPath do
        local d = dist(prev, filteredPath[i])
        if (D + d) >= interval then
            local t = (interval - D) / d
            local nx = prev.x + t * (filteredPath[i].x - prev.x)
            local ny = prev.y + t * (filteredPath[i].y - prev.y)
            local newpt = {x = nx, y = ny}
            table.insert(newPath, newpt)
            prev = newpt
            D = 0
        else
            D = D + d
            prev = filteredPath[i]
            i = i + 1
        end
    end
    while #newPath < n do
        table.insert(newPath, {x = filteredPath[#filteredPath].x, y = filteredPath[#filteredPath].y})
    end
    return newPath
end

-- Helper: normalize path (all points from all strokes)
local function normalizeAllPoints(strokes)
    local all = {}
    for _, stroke in ipairs(strokes) do
        for _, p in ipairs(stroke) do
            -- Create a copy of the point to avoid modifying the original
            table.insert(all, {x = p.x, y = p.y})
        end
    end
    if #all == 0 then return {} end
    local minX, maxX = all[1].x, all[1].x
    local minY, maxY = all[1].y, all[1].y
    for _, p in ipairs(all) do
        minX = math.min(minX, p.x)
        maxX = math.max(maxX, p.x)
        minY = math.min(minY, p.y)
        maxY = math.max(maxY, p.y)
    end
    local width = maxX - minX
    local height = maxY - minY
    local scale = math.max(width, height)
    if scale == 0 then
        for _, p in ipairs(all) do p.x, p.y = 0.5, 0.5 end
        return all
    end
    for _, p in ipairs(all) do
        p.x = (p.x - minX) / scale
        p.y = (p.y - minY) / scale
    end
    return all
end

-- Path distance (with alignment)
local function findBestPathAlignment(userPath, templatePath)
    local bestDistance = math.huge
    local n = #userPath
    if n ~= #templatePath or n < 2 then return math.huge end
    for startOffset = 0, n-1 do
        local distance = 0
        for i = 1, n do
            local userIdx = ((i - 1 + startOffset) % n) + 1
            distance = distance + dist(userPath[userIdx], templatePath[i])
        end
        bestDistance = math.min(bestDistance, distance / n)
        -- Try reversed
        distance = 0
        for i = 1, n do
            local userIdx = ((n - i + startOffset) % n) + 1
            distance = distance + dist(userPath[userIdx], templatePath[i])
        end
        bestDistance = math.min(bestDistance, distance / n)
    end
    return bestDistance
end

-- Agnostic recognizer: flatten all strokes, resample to N points, normalize, then compare
local layout = require("layout")
local drawingConfig = require("drawing_config")
local templates = layout.shape_templates

function M.recognizeShape(strokes)
    -- Remove empty strokes
    local filtered = {}
    for _, s in ipairs(strokes) do if #s > 0 then table.insert(filtered, s) end end
    if #filtered == 0 then return nil, "Draw a bigger shape!" end
    
    local N = drawingConfig.resampling_points
    
    -- Resample each stroke individually to get evenly distributed points
    local allUserPoints = {}
    for _, stroke in ipairs(filtered) do
        local resampledStroke = resamplePath(stroke, N)
        for _, p in ipairs(resampledStroke) do
            table.insert(allUserPoints, p)
        end
    end
    
    -- Normalize the entire point cloud (no stroke structure)
    allUserPoints = normalizeAllPoints({allUserPoints})

    local bestMatch, bestScore = nil, -math.huge
    local allScores = {}
    for name, tmpl in pairs(templates) do
        -- Process template the same way: resample each stroke, then flatten
        local allTemplatePoints = {}
        for _, stroke in ipairs(tmpl) do
            local resampledStroke = resamplePath(stroke, N)
            for _, p in ipairs(resampledStroke) do
                table.insert(allTemplatePoints, p)
            end
        end
        allTemplatePoints = normalizeAllPoints({allTemplatePoints})

        -- Score: for each user point, find closest template point
        local total = 0
        local bonus_radius = 0.08 -- within this, full bonus
        local malus_radius = 0.25 -- beyond this, malus
        for _, up in ipairs(allUserPoints) do
            local best = math.huge
            for _, tp in ipairs(allTemplatePoints) do
                local d = dist(up, tp)
                if d < best then best = d end
            end
            if best <= bonus_radius then
                total = total + 1
            elseif best <= malus_radius then
                total = total + (1 - (best-bonus_radius)/(malus_radius-bonus_radius))
            else
                total = total - 1
            end
        end
        -- Optionally, penalize for missing template points
        for _, tp in ipairs(allTemplatePoints) do
            local best = math.huge
            for _, up in ipairs(allUserPoints) do
                local d = dist(up, tp)
                if d < best then best = d end
            end
            if best > malus_radius then
                total = total - 1
            end
        end
        -- Normalize score
        local maxScore = #allUserPoints + #allTemplatePoints
        local score = total / maxScore
        allScores[name] = score
        if score > bestScore then bestScore = score; bestMatch = name end
    end
    -- Normalize scores to [0,1]
    local minScore, maxScore = 0, 1
    for _, v in pairs(allScores) do
        if v < minScore then minScore = v end
        if v > maxScore then maxScore = v end
    end
    local matchPercents = {}
    for name, v in pairs(allScores) do
        matchPercents[name] = (v - minScore) / (maxScore - minScore + 1e-6)
    end
    if bestScore > 0.5 then
        return bestMatch, matchPercents
    else
        return nil, matchPercents
    end
end

-- Helper function to get processed user points (for visualization)
function M.getProcessedUserPoints(strokes)
    local filtered = {}
    for _, s in ipairs(strokes) do if #s > 0 then table.insert(filtered, s) end end
    if #filtered == 0 then return {} end
    
    local N = drawingConfig.resampling_points
    local allUserPoints = {}
    for _, stroke in ipairs(filtered) do
        local resampledStroke = resamplePath(stroke, N)
        for _, p in ipairs(resampledStroke) do
            table.insert(allUserPoints, p)
        end
    end
    return normalizeAllPoints({allUserPoints})
end

-- Helper function to get processed template points (for visualization)
function M.getProcessedTemplatePoints(templateName)
    local tmpl = templates[templateName]
    if not tmpl then return {} end
    
    local N = drawingConfig.resampling_points
    local allTemplatePoints = {}
    for _, stroke in ipairs(tmpl) do
        local resampledStroke = resamplePath(stroke, N)
        for _, p in ipairs(resampledStroke) do
            table.insert(allTemplatePoints, p)
        end
    end
    return normalizeAllPoints({allTemplatePoints})
end

return M
