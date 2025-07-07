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
    
    -- Resample all strokes first
    local resampledUserStrokes = {}
    local resampledTmplStrokes = {}
    
    for _, stroke in ipairs(userStrokes) do
        table.insert(resampledUserStrokes, resamplePath(stroke, N))
    end
    for _, stroke in ipairs(tmplStrokes) do
        table.insert(resampledTmplStrokes, resamplePath(stroke, N))
    end
    
    -- Normalize user strokes together
    local normalizedUserStrokes = normalizeMultipleStrokes(resampledUserStrokes)
    -- Normalize template strokes together (templates are already in normalized space, but we need to ensure consistency)
    local normalizedTmplStrokes = normalizeMultipleStrokes(resampledTmplStrokes)
    
    -- If stroke counts match exactly, use original algorithm with invariant matching
    if #normalizedUserStrokes == #normalizedTmplStrokes then
        local total = 0
        for i = 1, #normalizedUserStrokes do
            total = total + pathDistanceInvariant(normalizedUserStrokes[i], normalizedTmplStrokes[i])
        end
        return total / #normalizedUserStrokes
    end
    
    -- If user has more strokes than template, try to merge user strokes
    if #normalizedUserStrokes > #normalizedTmplStrokes then
        -- Strategy 1: Merge all user strokes into one and compare to template
        local mergedUserStroke = {}
        for _, stroke in ipairs(normalizedUserStrokes) do
            for _, point in ipairs(stroke) do
                table.insert(mergedUserStroke, point)
            end
        end
        
        -- Safety check: ensure merged stroke has points
        if #mergedUserStroke == 0 then return math.huge end
        
        -- Try matching against each template stroke and take the best match
        local bestDist = math.huge
        for i = 1, #normalizedTmplStrokes do
            local dist = pathDistanceInvariant(mergedUserStroke, normalizedTmplStrokes[i])
            bestDist = math.min(bestDist, dist)
        end
        
        -- If template has multiple strokes, try merging template strokes too
        if #normalizedTmplStrokes > 1 then
            local mergedTemplateStroke = {}
            for _, stroke in ipairs(normalizedTmplStrokes) do
                for _, point in ipairs(stroke) do
                    table.insert(mergedTemplateStroke, point)
                end
            end
            
            local mergedDist = pathDistanceInvariant(mergedUserStroke, mergedTemplateStroke)
            bestDist = math.min(bestDist, mergedDist)
        end
        
        -- Strategy 2: Try connecting strokes in different orders to form a closed shape
        -- This is especially important for shapes like squares drawn as separate lines
        if #normalizedUserStrokes >= 3 then
            -- Try to find the best way to connect the strokes
            local function tryConnectStrokes(strokes)
                local connected = {}
                -- Start with the first stroke
                for _, point in ipairs(strokes[1]) do
                    table.insert(connected, point)
                end
                
                -- Try to connect remaining strokes by finding closest endpoints
                local remaining = {}
                for i = 2, #strokes do
                    table.insert(remaining, strokes[i])
                end
                
                while #remaining > 0 do
                    local lastPoint = connected[#connected]
                    local bestIdx = 1
                    local bestDist = math.huge
                    local bestReverse = false
                    
                    -- Find the closest stroke to connect
                    for i, stroke in ipairs(remaining) do
                        if #stroke > 0 then
                            -- Try connecting to start of stroke
                            local distToStart = dist(lastPoint, stroke[1])
                            if distToStart < bestDist then
                                bestDist = distToStart
                                bestIdx = i
                                bestReverse = false
                            end
                            
                            -- Try connecting to end of stroke (reversed)
                            local distToEnd = dist(lastPoint, stroke[#stroke])
                            if distToEnd < bestDist then
                                bestDist = distToEnd
                                bestIdx = i
                                bestReverse = true
                            end
                        end
                    end
                    
                    -- Connect the best stroke
                    local strokeToConnect = table.remove(remaining, bestIdx)
                    if bestReverse then
                        -- Add stroke in reverse order
                        for i = #strokeToConnect, 1, -1 do
                            table.insert(connected, strokeToConnect[i])
                        end
                    else
                        -- Add stroke in normal order
                        for _, point in ipairs(strokeToConnect) do
                            table.insert(connected, point)
                        end
                    end
                end
                
                return connected
            end
            
            local connectedStroke = tryConnectStrokes(normalizedUserStrokes)
            if #connectedStroke > 0 then
                for i = 1, #normalizedTmplStrokes do
                    local dist = pathDistanceInvariant(connectedStroke, normalizedTmplStrokes[i])
                    bestDist = math.min(bestDist, dist)
                end
            end
        end
        
        return bestDist
    end
    
    -- If user has fewer strokes than template, try to match best subset
    if #normalizedUserStrokes < #normalizedTmplStrokes then
        -- Try matching user strokes to the best fitting template strokes
        local bestDist = math.huge
        
        -- Try different combinations of template strokes
        for i = 1, #normalizedTmplStrokes - #normalizedUserStrokes + 1 do
            local total = 0
            for j = 1, #normalizedUserStrokes do
                total = total + pathDistanceInvariant(normalizedUserStrokes[j], normalizedTmplStrokes[i + j - 1])
            end
            bestDist = math.min(bestDist, total / #normalizedUserStrokes)
        end
        
        return bestDist
    end
    
    return math.huge
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
