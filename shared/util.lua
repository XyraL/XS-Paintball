Util = {}

function Util.truthy(v)
    return v == true or v == 1 or v == '1'
end

function Util.clamp(v, min, max)
    if type(v) ~= 'number' then return min end
    if v < min then return min end
    if v > max then return max end
    return v
end

function Util.round(v, places)
    local m = 10 ^ (places or 0)
    return math.floor(v * m + 0.5) / m
end

function Util.trim(s)
    if type(s) ~= 'string' then return '' end
    return (s:gsub('^%s+', ''):gsub('%s+$', ''))
end

function Util.copy(t)
    if type(t) ~= 'table' then return t end
    local out = {}
    for k, v in pairs(t) do
        out[k] = type(v) == 'table' and Util.copy(v) or v
    end
    return out
end

function Util.count(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

function Util.keys(t)
    local out = {}
    for k in pairs(t or {}) do out[#out + 1] = k end
    table.sort(out)
    return out
end

function Util.contains(list, value)
    for _, v in ipairs(list or {}) do
        if v == value then return true end
    end
    return false
end

function Util.shuffle(list)
    for i = #list, 2, -1 do
        local j = math.random(i)
        list[i], list[j] = list[j], list[i]
    end
    return list
end

function Util.dist2(a, b)
    local dx, dy = (a.x or 0) - (b.x or 0), (a.y or 0) - (b.y or 0)
    return dx * dx + dy * dy
end

function Util.dist3(a, b)
    local dx, dy, dz = (a.x or 0) - (b.x or 0), (a.y or 0) - (b.y or 0), (a.z or 0) - (b.z or 0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function Util.timeString(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    return ('%d:%02d'):format(math.floor(seconds / 60), seconds % 60)
end

function Util.slug(text, fallback)
    local s = tostring(text or ''):lower():gsub('[^%w]+', '-'):gsub('^-+', ''):gsub('-+$', '')
    if s == '' then return fallback or 'map' end
    return s:sub(1, 40)
end

local CODE_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'

function Util.code(length)
    local out = {}
    for i = 1, (length or 5) do
        local n = math.random(#CODE_CHARS)
        out[i] = CODE_CHARS:sub(n, n)
    end
    return table.concat(out)
end

function Util.pointInPolygon(x, y, points)
    local inside = false
    local n = #points
    local j = n

    for i = 1, n do
        local xi, yi = points[i].x, points[i].y
        local xj, yj = points[j].x, points[j].y

        if ((yi > y) ~= (yj > y)) and (x < (xj - xi) * (y - yi) / ((yj - yi) ~= 0 and (yj - yi) or 0.0001) + xi) then
            inside = not inside
        end
        j = i
    end

    return inside
end

function Util.polygonCentre(points)
    local sx, sy, sz = 0.0, 0.0, 0.0
    local n = #points
    if n == 0 then return { x = 0.0, y = 0.0, z = 0.0 } end

    for _, p in ipairs(points) do
        sx = sx + (p.x or 0.0)
        sy = sy + (p.y or 0.0)
        sz = sz + (p.z or 0.0)
    end

    return { x = sx / n, y = sy / n, z = sz / n }
end
