local CLASS     = CFW.classes.contraption
local VEC_0     = Vector(0, 0, 0)
local VEC_SMALL = -Vector(math.huge, math.huge, math.huge)
local VEC_HUGE  = Vector(math.huge, math.huge, math.huge)

function CLASS:GetPos()
    -- TODO: Optimize this

    local pos = VEC_0

    for ent in pairs(self.ents) do
        pos = pos + ent:GetPos()
    end

    return pos / table.Count(self.ents)
end

function CLASS:GetAABB()
    local mins, maxs = Vector(math.huge, math.huge, math.huge), -Vector(math.huge, math.huge, math.huge)

    for ent in pairs(self.ents) do
        local pos = ent:GetPos()

        if pos.x < mins.x then mins.x = pos.x end
        if pos.y < mins.y then mins.y = pos.y end
        if pos.z < mins.z then mins.z = pos.z end

        if pos.x > maxs.x then maxs.x = pos.x end
        if pos.y > maxs.y then maxs.y = pos.y end
        if pos.z > maxs.z then maxs.z = pos.z end
    end

    local center = (mins + maxs) * 0.5

    debugoverlay.Cross(mins, 12, 0.03, Color(255, 0, 0), true)
    debugoverlay.Cross(maxs, 12, 0.03, Color(0, 255, 0), true)
    debugoverlay.Box(center, mins - center, maxs - center, 0.03, self.color)

    return mins, maxs, center
end