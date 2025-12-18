local CLASS     = CFW.Classes.Contraption
local VEC_0     = Vector(0, 0, 0)

function CLASS:GetPos()
    -- TODO: Optimize this

    local pos = VEC_0

    for ent in pairs(self.ents) do
        pos = pos + ent:GetPos()
    end

    return pos / self.count
end

do -- AABB
    local HUGE   = math.huge
    local corner = Vector()

    local function expandAABB(ent, x, y, z, mins, maxs)
        corner:SetUnpacked(x, y, z)

        local worldCorner = ent:LocalToWorld(corner)

        if worldCorner.x < mins.x then mins.x = worldCorner.x end
        if worldCorner.y < mins.y then mins.y = worldCorner.y end
        if worldCorner.z < mins.z then mins.z = worldCorner.z end
        if worldCorner.x > maxs.x then maxs.x = worldCorner.x end
        if worldCorner.y > maxs.y then maxs.y = worldCorner.y end
        if worldCorner.z > maxs.z then maxs.z = worldCorner.z end
    end

    function CLASS:GetAABB(filter)
        local mins, maxs = Vector(HUGE, HUGE, HUGE), -Vector(HUGE, HUGE, HUGE)

        for ent in pairs(self.ents) do
            if filter and not filter(ent) then continue end
            local obbMins, obbMaxs = ent:GetCollisionBounds()
            local minX, minY, minZ = obbMins.x, obbMins.y, obbMins.z
            local maxX, maxY, maxZ = obbMaxs.x, obbMaxs.y, obbMaxs.z

            -- Calculate all 8 corners of the entity's OBB in world space
            expandAABB(ent, maxX, minY, minZ, mins, maxs) -- Top Left Front
            expandAABB(ent, maxX, minY, maxZ, mins, maxs) -- Top Left Back
            expandAABB(ent, maxX, maxY, minZ, mins, maxs) -- Top Right Front
            expandAABB(ent, maxX, maxY, maxZ, mins, maxs) -- Top Right Back
            expandAABB(ent, minX, minY, minZ, mins, maxs) -- Bottom Left Front
            expandAABB(ent, minX, minY, maxZ, mins, maxs) -- Bottom Left Back
            expandAABB(ent, minX, maxY, minZ, mins, maxs) -- Bottom Right Front
            expandAABB(ent, minX, maxY, maxZ, mins, maxs) -- Bottom Right Back
        end

        local center = (mins + maxs) * 0.5

        debugoverlay.Cross(mins, 12, 0.03, Color(255, 0, 0), true)
        debugoverlay.Cross(maxs, 12, 0.03, Color(0, 255, 0), true)
        debugoverlay.Box(center, mins - center, maxs - center, 0.03, self.color)

        return mins, maxs, center
    end
end