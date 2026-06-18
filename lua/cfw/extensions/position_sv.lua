-- Position and AABB calculations for contraptions and families
-- Families cache their AABB in ancestor local space; contraption AABB iterates physical entities only

local HUGE = math.huge
local abs  = math.abs

local function expandAABBWorld(x, y, z, mins, maxs)
    if x < mins.x then mins.x = x end
    if y < mins.y then mins.y = y end
    if z < mins.z then mins.z = z end
    if x > maxs.x then maxs.x = x end
    if y > maxs.y then maxs.y = y end
    if z > maxs.z then maxs.z = z end
end

-- Expand AABB with entity's OBB transformed to world space using optimized AABB transformation
local function expandAABBWithEnt(ent, mins, maxs)
    local obbMins, obbMaxs = ent:GetCollisionBounds()
    local ang = ent:GetAngles()

    local fx, fy, fz = ang:Forward():Unpack()
    local rx, ry, rz = ang:Right():Unpack()
    local ux, uy, uz = ang:Up():Unpack()
    local px, py, pz = ent:GetPos():Unpack()
    local mnx, mny, mnz = obbMins:Unpack()
    local mxx, mxy, mxz = obbMaxs:Unpack()

    local ocx = (mnx + mxx) * 0.5
    local ocy = (mny + mxy) * 0.5
    local ocz = (mnz + mxz) * 0.5
    local ex  = (mxx - mnx) * 0.5
    local ey  = (mxy - mny) * 0.5
    local ez  = (mxz - mnz) * 0.5

    local cx = px + ocx * fx + ocy * rx + ocz * ux
    local cy = py + ocx * fy + ocy * ry + ocz * uy
    local cz = pz + ocx * fz + ocy * rz + ocz * uz

    local newEx = ex * abs(fx) + ey * abs(rx) + ez * abs(ux)
    local newEy = ex * abs(fy) + ey * abs(ry) + ez * abs(uy)
    local newEz = ex * abs(fz) + ey * abs(rz) + ez * abs(uz)

    expandAABBWorld(cx - newEx, cy - newEy, cz - newEz, mins, maxs)
    expandAABBWorld(cx + newEx, cy + newEy, cz + newEz, mins, maxs)
end

do -- MARK: Family
    local CLASS  = CFW.Classes.Family
    local Vector = Vector

    -- OBB edge indices (12 edges of a box)
    local OBB_EDGES = {
        {1, 2}, {2, 4}, {4, 3}, {3, 1}, -- bottom face
        {5, 6}, {6, 8}, {8, 7}, {7, 5}, -- top face
        {1, 5}, {2, 6}, {3, 7}, {4, 8}  -- vertical edges
    }

    function CLASS:GetPos()
        local physicalRoot = CFW.getPhysicalRoot(self.ancestor)
        return physicalRoot:LocalToWorld(self.aabbCenter)
    end

    -- Recalculate cached OBB in physical root local space (called when membership changes)
    function CLASS:RecalculateAABB()
        local physicalRoot = CFW.getPhysicalRoot(self.ancestor)
        local rootPos = physicalRoot:GetPos()
        local rootAng = physicalRoot:GetAngles()
        local mins = Vector(HUGE, HUGE, HUGE)
        local maxs = Vector(-HUGE, -HUGE, -HUGE)

        -- Pre-extract root basis and origin as scalars
        local rfx, rfy, rfz = rootAng:Forward():Unpack()
        local rrx, rry, rrz = rootAng:Right():Unpack()
        local rux, ruy, ruz = rootAng:Up():Unpack()
        local rpx, rpy, rpz = rootPos:Unpack()

        for ent in pairs(self.ents) do
            local obbMins, obbMaxs = ent:GetCollisionBounds()
            local entAng = ent:GetAngles()

            local fx, fy, fz = entAng:Forward():Unpack()
            local rx, ry, rz = entAng:Right():Unpack()
            local ux, uy, uz = entAng:Up():Unpack()
            local px, py, pz = ent:GetPos():Unpack()
            local mnx, mny, mnz = obbMins:Unpack()
            local mxx, mxy, mxz = obbMaxs:Unpack()

            -- OBB center and half-extents in entity local space
            local ocx = (mnx + mxx) * 0.5
            local ocy = (mny + mxy) * 0.5
            local ocz = (mnz + mxz) * 0.5
            local ex  = (mxx - mnx) * 0.5
            local ey  = (mxy - mny) * 0.5
            local ez  = (mxz - mnz) * 0.5

            -- Transform OBB center: entity local -> world
            local wcx = px + ocx * fx + ocy * rx + ocz * ux
            local wcy = py + ocx * fy + ocy * ry + ocz * uy
            local wcz = pz + ocx * fz + ocy * rz + ocz * uz

            -- Transform world center -> root local
            local dx, dy, dz = wcx - rpx, wcy - rpy, wcz - rpz
            local lcx = dx * rfx + dy * rfy + dz * rfz
            local lcy = dx * rrx + dy * rry + dz * rrz
            local lcz = dx * rux + dy * ruy + dz * ruz

            -- AABB-of-OBB: project entity half-extents onto each root axis
            local newEx = ex * abs(fx * rfx + fy * rfy + fz * rfz)
                        + ey * abs(rx * rfx + ry * rfy + rz * rfz)
                        + ez * abs(ux * rfx + uy * rfy + uz * rfz)
            local newEy = ex * abs(fx * rrx + fy * rry + fz * rrz)
                        + ey * abs(rx * rrx + ry * rry + rz * rrz)
                        + ez * abs(ux * rrx + uy * rry + uz * rrz)
            local newEz = ex * abs(fx * rux + fy * ruy + fz * ruz)
                        + ey * abs(rx * rux + ry * ruy + rz * ruz)
                        + ez * abs(ux * rux + uy * ruy + uz * ruz)

            -- Expand AABB
            local lminx, lminy, lminz = lcx - newEx, lcy - newEy, lcz - newEz
            local lmaxx, lmaxy, lmaxz = lcx + newEx, lcy + newEy, lcz + newEz

            if lminx < mins.x then mins.x = lminx end
            if lminy < mins.y then mins.y = lminy end
            if lminz < mins.z then mins.z = lminz end
            if lmaxx > maxs.x then maxs.x = lmaxx end
            if lmaxy > maxs.y then maxs.y = lmaxy end
            if lmaxz > maxs.z then maxs.z = lmaxz end
        end

        self.aabbMins   = mins
        self.aabbMaxs   = maxs
        self.aabbCenter = (mins + maxs) * 0.5
    end

    -- Returns 8 world-space OBB corners and 12 edge index pairs
    function CLASS:GetOBB()
        local physicalRoot = CFW.getPhysicalRoot(self.ancestor)
        local mins, maxs = self.aabbMins, self.aabbMaxs
        local mx, my, mz = mins.x, mins.y, mins.z
        local Mx, My, Mz = maxs.x, maxs.y, maxs.z

        local verts = {
            physicalRoot:LocalToWorld(Vector(mx, my, mz)),
            physicalRoot:LocalToWorld(Vector(Mx, my, mz)),
            physicalRoot:LocalToWorld(Vector(mx, My, mz)),
            physicalRoot:LocalToWorld(Vector(Mx, My, mz)),
            physicalRoot:LocalToWorld(Vector(mx, my, Mz)),
            physicalRoot:LocalToWorld(Vector(Mx, my, Mz)),
            physicalRoot:LocalToWorld(Vector(mx, My, Mz)),
            physicalRoot:LocalToWorld(Vector(Mx, My, Mz))
        }

        return verts, OBB_EDGES
    end
end


do -- MARK: Contraption
    local CLASS  = CFW.Classes.Contraption
    local Vector = Vector

    function CLASS:GetPos()
        local _, _, center = self:GetAABB()
        return center
    end

    -- Expands mins/maxs with the OBB of a family and all its sub-families
    local function expandAABBWithFamily(family, mins, maxs)
        local verts = family:GetOBB()
        for _, vert in ipairs(verts) do
            expandAABBWorld(vert.x, vert.y, vert.z, mins, maxs)
        end

        for subFamily in pairs(family.subFamilies) do
            expandAABBWithFamily(subFamily, mins, maxs)
        end
    end

    -- Iterates physical entities, using cached family OBBs where available
    function CLASS:GetAABB()
        local mins = Vector(HUGE, HUGE, HUGE)
        local maxs = Vector(-HUGE, -HUGE, -HUGE)

        for ent in pairs(self.physical) do
            local family = ent._family

            if family then
                expandAABBWithFamily(family, mins, maxs)
            else
                expandAABBWithEnt(ent, mins, maxs)
            end
        end

        local center = (mins + maxs) * 0.5
        return mins, maxs, center
    end
end


do -- MARK: Family hooks
    hook.Add("cfw.family.init", "CFW_Position", function(family)
        family.aabbMins   = Vector(0, 0, 0)
        family.aabbMaxs   = Vector(0, 0, 0)
        family.aabbCenter = Vector(0, 0, 0)
    end)

    local function recalc(family) family:RecalculateAABB() end

    hook.Add("cfw.family.added",           "CFW_Position", recalc)
    hook.Add("cfw.family.subbed",          "CFW_Position", recalc)
    hook.Add("cfw.family.merged",          "CFW_Position", recalc)
    hook.Add("cfw.family.ancestorRemoved",  "CFW_Position", recalc)
    hook.Add("cfw.family.ancestorInserted", "CFW_Position", recalc)

    hook.Add("cfw.family.split",           "CFW_Position", function(oldFamily, newFamily)
        oldFamily:RecalculateAABB()
        newFamily:RecalculateAABB()
    end)
end
