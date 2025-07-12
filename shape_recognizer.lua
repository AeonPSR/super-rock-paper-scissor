local M = {}

-- Helper: distance between two points
local function dist(a, b)
    if not a or not b then
        return math.huge -- Return large distance for nil points
    end
    return math.sqrt((a.x - b.x)^2 + (a.y - b.y)^2)
end

-- Helper: resample a path to N points (for normalization)
local function resamplePath(path, n)
    if #path < 2 then return path end
    
    -- Filter out nil points
    local filteredPath = {}
    for _, point in ipairs(path) do
        if point and point.x and point.y then
            table.insert(filteredPath, point)
        end
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

-- Helper: normalize path (translate to origin, scale to fit box)
local function normalizePath(path)
    if #path == 0 then return {} end
    if #path == 1 then return {{x = 0.5, y = 0.5}} end -- center point for single point
    
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
    
    -- Handle case where all points are the same (scale = 0)
    if scale == 0 then
        local norm = {}
        for _, p in ipairs(path) do
            table.insert(norm, {x = 0.5, y = 0.5})
        end
        return norm
    end
    
    local norm = {}
    for _, p in ipairs(path) do
        table.insert(norm, {x = (p.x - minX) / scale, y = (p.y - minY) / scale})
    end
    return norm
end

-- Helper: normalize multiple strokes together as a unified shape
local function normalizeMultipleStrokes(strokes)
    if #strokes == 0 then return {} end
    
    -- Calculate overall bounding box from all strokes
    local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
    local hasPoints = false
    
    for _, stroke in ipairs(strokes) do
        if stroke then
            for _, p in ipairs(stroke) do
                if p and p.x and p.y then
                    minX = math.min(minX, p.x)
                    maxX = math.max(maxX, p.x)
                    minY = math.min(minY, p.y)
                    maxY = math.max(maxY, p.y)
                    hasPoints = true
                end
            end
        end
    end
    
    if not hasPoints then return {} end
    
    local width = maxX - minX
    local height = maxY - minY
    local scale = math.max(width, height)
    
    -- Handle case where all points are the same (scale = 0)
    if scale == 0 then
        local normalizedStrokes = {}
        for _, stroke in ipairs(strokes) do
            if stroke then
                local normalizedStroke = {}
                for _, p in ipairs(stroke) do
                    if p and p.x and p.y then
                        table.insert(normalizedStroke, {x = 0.5, y = 0.5})
                    end
                end
                if #normalizedStroke > 0 then
                    table.insert(normalizedStrokes, normalizedStroke)
                end
            end
        end
        return normalizedStrokes
    end
    
    -- Normalize all strokes using the unified bounding box
    local normalizedStrokes = {}
    for _, stroke in ipairs(strokes) do
        if stroke then
            local normalizedStroke = {}
            for _, p in ipairs(stroke) do
                if p and p.x and p.y then
                    table.insert(normalizedStroke, {x = (p.x - minX) / scale, y = (p.y - minY) / scale})
                end
            end
            if #normalizedStroke > 0 then
                table.insert(normalizedStrokes, normalizedStroke)
            end
        end
    end
    
    return normalizedStrokes
end

-- Example templates (multi-stroke)
local layout = require("layout")
local drawingConfig = require("drawing_config")
local templates = layout.shape_templates

-- Compute average distance between two paths (assume same length)
local function pathDistance(p1, p2)
    local sum = 0
    for i = 1, #p1 do
        sum = sum + dist(p1[i], p2[i])
    end
    return sum / #p1
end

-- Find the best alignment between two paths (handles different starting points and directions)
local function findBestPathAlignment(userPath, templatePath)
    local bestDistance = math.huge
    local n = #userPath
    
    -- Early exit for very small paths
    if n <= 2 then
        return pathDistance(userPath, templatePath)
    end
    
    -- Try different starting points
    for startOffset = 0, n-1 do
        -- Try normal direction
        local distance = 0
        for i = 1, n do
            local userIdx = ((i - 1 + startOffset) % n) + 1
            distance = distance + dist(userPath[userIdx], templatePath[i])
        end
        local normalDist = distance / n
        bestDistance = math.min(bestDistance, normalDist)
        
        -- Early exit if we found a very good match
        if normalDist < drawingConfig.early_exit_threshold then
            return normalDist
        end
        
        -- Try reversed direction
        distance = 0
        for i = 1, n do
            local userIdx = ((n - i + startOffset) % n) + 1
            distance = distance + dist(userPath[userIdx], templatePath[i])
        end
        local reverseDist = distance / n
        bestDistance = math.min(bestDistance, reverseDist)
        
        -- Early exit if we found a very good match
        if reverseDist < drawingConfig.early_exit_threshold then
            return reverseDist
        end
    end
    
    return bestDistance
end

-- Enhanced path distance that handles rotation and direction invariance
local function pathDistanceInvariant(p1, p2)
    -- If paths are different lengths, fall back to simple distance
    if #p1 ~= #p2 then
        return pathDistance(p1, p2)
    end
    
    -- Use the alignment-based distance for same-length paths
    return findBestPathAlignment(p1, p2)
end

-- Multi-stroke template matching with flexible stroke count and unified normalization
local function strokesDistance(userStrokes, tmplStrokes, N)
    -- Safety check: ensure all strokes have at least 1 point
    for _, stroke in ipairs(userStrokes) do
        if #stroke == 0 then return math.huge end
    end
    for _, stroke in ipairs(tmplStrokes) do
        if #stroke == 0 then return math.huge end
    end

    -- Resample and normalize all strokes
    local resampledUserStrokes = {}
    local resampledTmplStrokes = {}
    for _, stroke in ipairs(userStrokes) do
        table.insert(resampledUserStrokes, resamplePath(stroke, N))
    end
    for _, stroke in ipairs(tmplStrokes) do
        table.insert(resampledTmplStrokes, resamplePath(stroke, N))
    end
    local normUser = normalizeMultipleStrokes(resampledUserStrokes)
    local normTmpl = normalizeMultipleStrokes(resampledTmplStrokes)

    -- Assignment-agnostic matching: find best assignment of user strokes to template strokes
    local nUser = #normUser
    local nTmpl = #normTmpl
    local usedTmpl = {}
    local totalDist = 0
    local count = 0

    -- Greedy assignment: for each user stroke, find the closest template stroke (no double assignment)
    for i = 1, nUser do
        local bestIdx, bestDist = nil, math.huge
        for j = 1, nTmpl do
            if not usedTmpl[j] then
                local d = pathDistanceInvariant(normUser[i], normTmpl[j])
                if d < bestDist then
                    bestDist = d
                    bestIdx = j
                end
            end
        end
        if bestIdx then
            usedTmpl[bestIdx] = true
            totalDist = totalDist + bestDist
            count = count + 1
        end
    end

    -- Penalize for unmatched template strokes (if user drew fewer than template)
    local penalty = 1.0 -- can be tuned
    local unmatched = nTmpl - count
    totalDist = totalDist + unmatched * penalty
    count = count + unmatched

    -- Penalize for extra user strokes (if user drew more than template)
    local extra = nUser - nTmpl
    if extra > 0 then
        totalDist = totalDist + extra * penalty
        count = count + extra
    end

    if count == 0 then return math.huge end
    return totalDist / count
end

-- Main recognition function (multi-stroke template matching)
function M.recognizeShape(strokes)
    -- Remove empty strokes
    local filtered = {}
    for _, s in ipairs(strokes) do if #s > 0 then table.insert(filtered, s) end end
    if #filtered == 0 or #filtered[1] < 2 then
        return nil, "Draw a bigger shape!"
    end
    local N = drawingConfig.resampling_points
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
            -- Use a more generous scaling function
            local normalizedDist = d / (maxDist > 0 and maxDist or 1)
            matchPercents[name] = math.max(0, 1 - normalizedDist)
        end
    end
    -- More lenient threshold - accept matches with reasonable confidence
    if bestDist < drawingConfig.match_threshold then
        return bestMatch, matchPercents
    else
        return nil, matchPercents
    end
end

-- Expose helper functions for debugging/visualization
function M.resamplePath(path, n)
    return resamplePath(path, n or drawingConfig.resampling_points)
end

function M.normalizePath(path)
    return normalizePath(path)
end

function M.getProcessedStrokes(strokes)
    local resampled = {}
    local N = drawingConfig.resampling_points
    
    -- First, resample all strokes
    for _, stroke in ipairs(strokes) do
        if #stroke > 0 then
            local resampledStroke = resamplePath(stroke, N)
            table.insert(resampled, resampledStroke)
        end
    end
    
    -- Then normalize all strokes together as a unified shape
    return normalizeMultipleStrokes(resampled)
end

-- Get resampled strokes WITHOUT normalization (for visualization)
function M.getResampledStrokes(strokes)
    local resampled = {}
    local N = drawingConfig.resampling_points
    for _, stroke in ipairs(strokes) do
        if #stroke > 0 then
            local resampledStroke = resamplePath(stroke, N)
            table.insert(resampled, resampledStroke)
        end
    end
    return resampled
end

return M
