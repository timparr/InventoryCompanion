-- Experimental geometry only: not an approved placement policy or addon code.
local function NearestClearPosition(screen, panel, origin, obstacles)
    local maxX, maxY = screen.width - panel.width, screen.height - panel.height
    if maxX < 0 or maxY < 0 then return nil end
    local function Clamp(value, maximum) return math.max(0, math.min(value, maximum)) end
    local xs, ys = { Clamp(origin.x, maxX), 0, maxX }, { Clamp(origin.y, maxY), 0, maxY }
    for _, obstacle in ipairs(obstacles) do
        xs[#xs + 1] = Clamp(obstacle.x - panel.width, maxX)
        xs[#xs + 1] = Clamp(obstacle.x + obstacle.width, maxX)
        ys[#ys + 1] = Clamp(obstacle.y - panel.height, maxY)
        ys[#ys + 1] = Clamp(obstacle.y + obstacle.height, maxY)
    end
    local best
    for _, x in ipairs(xs) do
        for _, y in ipairs(ys) do
            local clear = true
            for _, obstacle in ipairs(obstacles) do
                if x < obstacle.x + obstacle.width and x + panel.width > obstacle.x
                    and y < obstacle.y + obstacle.height and y + panel.height > obstacle.y then
                    clear = false
                    break
                end
            end
            local distance = (x - origin.x) ^ 2 + (y - origin.y) ^ 2
            if clear and (best == nil or distance < best.distance) then
                best = { x = x, y = y, distance = distance }
            end
        end
    end
    return best
end

local function BruteForceDistance(screen, panel, origin, obstacles)
    local best
    for x = 0, screen.width - panel.width do
        for y = 0, screen.height - panel.height do
            local clear = true
            for _, obstacle in ipairs(obstacles) do
                local horizontal = math.min(x + panel.width, obstacle.x + obstacle.width) - math.max(x, obstacle.x)
                local vertical = math.min(y + panel.height, obstacle.y + obstacle.height) - math.max(y, obstacle.y)
                if horizontal > 0 and vertical > 0 then clear = false; break end
            end
            if clear then
                local distance = (x - origin.x) ^ 2 + (y - origin.y) ^ 2
                if best == nil or distance < best then best = distance end
            end
        end
    end
    return best
end

function GetScenePlacementInvestigationTests()
    return {
        {
            name = "Scene placement experiment matches exhaustive nearest-position search around multiple rectangles",
            run = function()
                local screen, panel = { width = 12, height = 10 }, { width = 3, height = 2 }
                local fixtures = {
                    {},
                    { { x = 3, y = 2, width = 5, height = 5 } },
                    { { x = 2, y = 0, width = 2, height = 7 }, { x = 4, y = 5, width = 6, height = 2 } },
                    { { x = -2, y = 1, width = 8, height = 4 }, { x = 7, y = 4, width = 8, height = 5 } },
                    { { x = 0, y = 0, width = 12, height = 10 } },
                }
                for _, obstacles in ipairs(fixtures) do
                    for x = -1, 13 do
                        for y = -1, 11 do
                            local origin = { x = x, y = y }
                            local candidate = NearestClearPosition(screen, panel, origin, obstacles)
                            local exhaustive = BruteForceDistance(screen, panel, origin, obstacles)
                            assert((candidate and candidate.distance) == exhaustive,
                                "Candidate search differs from exhaustive integer-coordinate search")
                        end
                    end
                end
            end,
        },
        {
            name = "Scene placement experiment preserves fractional clear anchors and distinguishes impossible fits",
            run = function()
                local screen, panel = { width = 12, height = 10 }, { width = 3, height = 2 }
                local origin = { x = 1.25, y = 2.75 }
                local clear = NearestClearPosition(screen, panel, origin, {})
                assert(clear.x == origin.x and clear.y == origin.y and clear.distance == 0)
                local moved = NearestClearPosition(screen, panel, origin,
                    { { x = 3.5, y = 2, width = 2, height = 5 } })
                assert(moved.x == 0.5 and moved.y == 2.75 and moved.distance == 0.75 ^ 2)
                assert(NearestClearPosition(screen, { width = 13, height = 2 }, origin, {}) == nil)
                assert(NearestClearPosition(screen, panel, origin,
                    { { x = 0, y = 0, width = 12, height = 10 } }) == nil)
            end,
        },
    }
end
