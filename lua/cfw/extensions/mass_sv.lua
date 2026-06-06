-- Tracks the total mass of contraptions and families
-- Each family and contraption tracks its own entity mass; Contraptions use the aggregate of families to derive a total
-- Also tracks physical vs parented mass
-- Center of (total) mass is tracked as a mass-weighted position sum (divide by totalMass to get CoM)

local PHYS        = FindMetaTable("PhysObj")
local setMass     = PHYS.SetMass
local angle_zero  = Angle(0, 0, 0)
local getParent   = getParent or FindMetaTable("Entity").GetParent
local IsValidPhys = IsValidPhys or PHYS.IsValid
local IsParented  = IsParented or function(ent) return IsValid(getParent(ent)) end


-- MARK: Helpers
local GetEntCoMWorld, GetEntCoMLocal, GetEntMass, AddCoM, RecalcCoM

do
    GetEntCoMWorld = function(ent)
        local phys = ent:GetPhysicsObject()
        if not IsValidPhys(phys) then return ent:GetPos() end
        return ent:LocalToWorld(phys:GetMassCenter())
    end

    -- World mass-center of ent expressed in root's local space (root = the family's physical root)
    GetEntCoMLocal = function(ent, root)
        return WorldToLocal(GetEntCoMWorld(ent), angle_zero, root:GetPos(), root:GetAngles()):Unpack()
    end

    -- Returns cached mass, or reads it from the physics object on first access
    GetEntMass = function(ent)
        local mass = ent._mass
        if mass then return mass end

        local phys = ent:GetPhysicsObject()
        if not IsValidPhys(phys) then return 0 end

        mass = phys:GetMass()
        ent._mass = mass

        return mass
    end

    -- Increments the family's mass-weighted CoM accumulators by one entity's contribution.
    -- Accumulators live in the family's physical-root local space (the rotator for turrets),
    -- so the cached CoM holds as the root moves; only intra-family relative motion drifts it.
    AddCoM = function(family, ent, mass)
        local root = CFW.getPhysicalRoot(family.ancestor)
        local x, y, z = GetEntCoMLocal(ent, root)

        family.massWeightedX = family.massWeightedX + x * mass
        family.massWeightedY = family.massWeightedY + y * mass
        family.massWeightedZ = family.massWeightedZ + z * mass
    end

    -- Recomputes the family's mass-weighted CoM accumulators from scratch, in physical-root space
    RecalcCoM = function(family)
        local root = CFW.getPhysicalRoot(family.ancestor)
        local wx, wy, wz = 0, 0, 0

        for ent in pairs(family.ents) do
            local mass = GetEntMass(ent)
            local x, y, z = GetEntCoMLocal(ent, root)

            wx = wx + x * mass
            wy = wy + y * mass
            wz = wz + z * mass
        end

        family.massWeightedX = wx
        family.massWeightedY = wy
        family.massWeightedZ = wz
    end
end


do -- MARK: PhysObj Detour
    function PHYS:SetMass(newMass)
        local ent     = self:GetEntity()
        local oldMass = ent._mass or 0

        -- Apply the mass, then read back what actually stuck: the engine clamps mass
        -- to [0, 50000], so the requested value may not be the value in effect. Track
        -- the clamped result so CFW's cache never drifts from physics reality
        setMass(self, newMass)
        newMass = self:GetMass()

        local delta = newMass - oldMass
        ent._mass   = newMass

        local con = ent._contraption
        if not con then return end

        con.totalMass = con.totalMass + delta

        local family = ent._family
        if family then
            family.totalMass = family.totalMass + delta

            if ent == family.ancestor and not IsParented(ent) then
                family.physicalMass = family.physicalMass + delta
            else
                family.parentedMass = family.parentedMass + delta
            end

            AddCoM(family, ent, delta)
        end

        if IsParented(ent) then
            con.parentedMass = con.parentedMass + delta
        else
            con.physicalMass = con.physicalMass + delta
        end

        hook.Run("cfw.contraption.massChanged", con, ent, newMass)

        if family then
            hook.Run("cfw.family.massChanged", family, ent, newMass)
        end
    end
end


do -- MARK: Base class
    -- Shared by Family and Contraption (both have totalMass, physicalMass, parentedMass)
    local BASE = CFW.Classes.EntityCollection

    function BASE:GetMass()         return self.totalMass    end
    function BASE:GetPhysicalMass() return self.physicalMass end
    function BASE:GetParentedMass() return self.parentedMass end
end


do -- MARK: Family
    local FAMILY = CFW.Classes.Family

    -- Family CoM is stored in physical-root local space; transformed to world on demand
    function FAMILY:GetCenterOfMass()
        local mass = self.totalMass
        local root = CFW.getPhysicalRoot(self.ancestor)

        return root:LocalToWorld(Vector(
            self.massWeightedX / mass,
            self.massWeightedY / mass,
            self.massWeightedZ / mass
        ))
    end
end


do -- MARK: Contraption
    local CONTRAPTION = CFW.Classes.Contraption

    -- Contraption CoM aggregates family CoMs and non-family entity positions
    function CONTRAPTION:GetCenterOfMass()
        local mass = self.totalMass
        local wx, wy, wz = 0, 0, 0

        -- Get the CoM from families
        for family in pairs(self.families) do
            local familyMass = family.totalMass
            local fx, fy, fz = family:GetCenterOfMass():Unpack()

            wx = wx + fx * familyMass
            wy = wy + fy * familyMass
            wz = wz + fz * familyMass
        end

        -- Then from physical entities (skip those with families)
        for ent in pairs(self.physical) do
            if not ent._family then
                local entMass = GetEntMass(ent)
                local ex, ey, ez = GetEntCoMWorld(ent):Unpack()

                wx = wx + ex * entMass
                wy = wy + ey * entMass
                wz = wz + ez * entMass
            end
        end

        return Vector(wx / mass, wy / mass, wz / mass)
    end
end


local function initMassTotals(obj)
    obj.totalMass    = 0
    obj.physicalMass = 0
    obj.parentedMass = 0
end


do -- MARK: Contraption hooks
    hook.Add("cfw.contraption.init", "CFW_Mass", initMassTotals)

    hook.Add("cfw.contraption.entityAdded", "CFW_Mass", function(contraption, ent)
        local mass = GetEntMass(ent)

        contraption.totalMass    = contraption.totalMass + mass
        contraption.physicalMass = contraption.physicalMass + mass
    end)

    -- wasPhysical is the entity's tracked physical state at removal time (passed by Contraption:Sub)
    -- It is the authoritative source - using the engine IsParented state here is racy: The parent state
    -- is changed before CFW processes the removal (e.g. constraining an already-parented entity)

    hook.Add("cfw.contraption.entityRemoved", "CFW_Mass", function(contraption, ent, wasPhysical)
        local mass = GetEntMass(ent)

        contraption.totalMass = contraption.totalMass - mass

        if wasPhysical then
            contraption.physicalMass = contraption.physicalMass - mass
        else
            contraption.parentedMass = contraption.parentedMass - mass
        end
    end)

    -- cfw.family.split fires before this, so family masses are already correct
    hook.Add("cfw.contraption.split", "CFW_Mass", function(oldContraption, newContraption)
        local totalMass    = 0
        local physicalMass = 0
        local parentedMass = 0

        for family in pairs(newContraption.families) do
            totalMass    = totalMass + family.totalMass
            physicalMass = physicalMass + family.physicalMass
            parentedMass = parentedMass + family.parentedMass
        end

        for ent in pairs(newContraption.ents) do
            if not ent._family then
                local mass = GetEntMass(ent)
                totalMass    = totalMass + mass
                physicalMass = physicalMass + mass
            end
        end

        newContraption.totalMass    = totalMass
        newContraption.physicalMass = physicalMass
        newContraption.parentedMass = parentedMass

        oldContraption.totalMass    = oldContraption.totalMass - totalMass
        oldContraption.physicalMass = oldContraption.physicalMass - physicalMass
        oldContraption.parentedMass = oldContraption.parentedMass - parentedMass
    end)

    hook.Add("cfw.contraption.merged", "CFW_Mass", function(oldContraption, newContraption)
        newContraption.totalMass    = newContraption.totalMass + oldContraption.totalMass
        newContraption.physicalMass = newContraption.physicalMass + oldContraption.physicalMass
        newContraption.parentedMass = newContraption.parentedMass + oldContraption.parentedMass
    end)
end


do -- MARK: Family hooks
    hook.Add("cfw.family.init", "CFW_Mass", function(family)
        initMassTotals(family)
        family.massWeightedX = 0  -- Sum of (mass * localPos.x) for CoM calculation
        family.massWeightedY = 0
        family.massWeightedZ = 0
    end)

    hook.Add("cfw.family.added", "CFW_Mass", function(family, ent)
        local mass        = GetEntMass(ent)
        local contraption = family.contraption
        local isPhysical  = ent == family.ancestor and not IsParented(ent)

        family.totalMass = family.totalMass + mass

        if isPhysical then
            family.physicalMass = family.physicalMass + mass
        else
            family.parentedMass      = family.parentedMass + mass
            contraption.physicalMass = contraption.physicalMass - mass
            contraption.parentedMass = contraption.parentedMass + mass
        end

        AddCoM(family, ent, mass)
    end)

    hook.Add("cfw.family.merged", "CFW_Mass", function(family, oldFamily)
        local contraption  = family.contraption
        local physicalMass = oldFamily.physicalMass

        family.totalMass    = family.totalMass + oldFamily.totalMass
        family.parentedMass = family.parentedMass + oldFamily.totalMass

        contraption.physicalMass = contraption.physicalMass - physicalMass
        contraption.parentedMass = contraption.parentedMass + physicalMass

        -- oldFamily.ents is already cleared by the time this hook fires
        -- recompute the whole accumulator from the merged family's entity set instead
        RecalcCoM(family)
    end)

    hook.Add("cfw.family.subbed", "CFW_Mass", function(family, ent, wasPhysical)
        local mass        = GetEntMass(ent)
        local contraption = family.contraption

        family.totalMass = family.totalMass - mass

        AddCoM(family, ent, -mass)

        if wasPhysical then
            family.physicalMass = family.physicalMass - mass
            return
        end

        family.parentedMass = family.parentedMass - mass

        -- Entity transitions from parented to physical in the contraption
        -- If it's removed from the contraption then that will happen later. Families are resolved first.
        contraption.parentedMass = contraption.parentedMass - mass
        contraption.physicalMass = contraption.physicalMass + mass
    end)

    hook.Add("cfw.family.ancestorRemoved", "CFW_Mass", function(family, oldAncestor, newAncestor)
        local oldMass      = GetEntMass(oldAncestor)
        local newMass      = GetEntMass(newAncestor)
        local contraption  = family.contraption
        local isRootFamily = not family.parentFamily

        family.totalMass = family.totalMass - oldMass

        if isRootFamily then
            -- Root: old physical leaves, new parented becomes physical
            family.physicalMass      = family.physicalMass - oldMass + newMass
            family.parentedMass      = family.parentedMass - newMass
            contraption.parentedMass = contraption.parentedMass - newMass
            contraption.physicalMass = contraption.physicalMass + newMass
        else
            -- Sub-family: old parented leaves, new stays parented
            family.parentedMass = family.parentedMass - oldMass
        end

        RecalcCoM(family)
    end)

    -- InsertAncestor: a NEW ancestor is added in front of the old one, which becomes a
    -- parented child. The new ancestor was already added to the contraption as physical via Contraption:Add
    hook.Add("cfw.family.ancestorInserted", "CFW_Mass", function(family, oldAncestor, newAncestor)
        local oldMass     = GetEntMass(oldAncestor)
        local newMass     = GetEntMass(newAncestor)
        local contraption = family.contraption

        -- New ancestor joins the family.
        family.totalMass = family.totalMass + newMass

        -- Physical ancestor swaps from old -> new; old ancestor becomes a parented child.
        family.physicalMass = family.physicalMass - oldMass + newMass
        family.parentedMass = family.parentedMass + oldMass

        contraption.physicalMass = contraption.physicalMass - oldMass
        contraption.parentedMass = contraption.parentedMass + oldMass

        RecalcCoM(family)
    end)

    hook.Add("cfw.family.split", "CFW_Mass", function(oldFamily, newFamily, newAncestor)
        -- The moved members' contributions must be subtracted from oldFamily's accumulator
        -- in the SAME frame they were stored in: oldFamily's physical-root local space
        local oldRoot      = CFW.getPhysicalRoot(oldFamily.ancestor)
        local totalMass    = 0
        local oldWx, oldWy, oldWz = 0, 0, 0

        for ent in pairs(newFamily.ents) do
            local mass    = GetEntMass(ent)
            local x, y, z = GetEntCoMLocal(ent, oldRoot)

            totalMass = totalMass + mass

            oldWx = oldWx + x * mass
            oldWy = oldWy + y * mass
            oldWz = oldWz + z * mass
        end

        -- Treat the new family as still fully parented here. Every moved member WAS
        -- parented in the old contraption (including newAncestor, which was a child), so
        -- the cfw.contraption.split hook that runs next subtracts them all from the old
        -- contraption's parented weight correctly. newAncestor's parented -> physical
        -- transition is applied afterwards by the cfw.family.becameRoot hook
        newFamily.totalMass    = totalMass
        newFamily.physicalMass = 0
        newFamily.parentedMass = totalMass

        RecalcCoM(newFamily)

        oldFamily.totalMass     = oldFamily.totalMass - totalMass
        oldFamily.parentedMass  = oldFamily.parentedMass - totalMass
        oldFamily.massWeightedX = oldFamily.massWeightedX - oldWx
        oldFamily.massWeightedY = oldFamily.massWeightedY - oldWy
        oldFamily.massWeightedZ = oldFamily.massWeightedZ - oldWz

    end)

    -- A pre-existing root family became a sub-family because its (physical) ancestor got
    -- parented. Move the ancestor's mass physical -> parented at both the family and
    -- contraption level. This is the mirror of cfw.family.becameRoot and is fired
    -- explicitly from the blocker-parenting path only
    --
    -- physicalMass for a family is exactly the ancestor's mass (root) or 0 (sub-family)
    hook.Add("cfw.family.becameSubFamily", "CFW_Mass", function(family)
        local physical = family.physicalMass
        if physical == 0 then return end

        local contraption = family.contraption

        family.physicalMass = 0
        family.parentedMass = family.parentedMass + physical

        contraption.physicalMass = contraption.physicalMass - physical
        contraption.parentedMass = contraption.parentedMass + physical
    end)

    -- A sub-family became a root family: its parent link was removed and the family
    -- migrated to its own contraption, so the ancestor transitions parented -> physical.
    -- This fires AFTER cfw.contraption.split has rebuilt the new contraption's totals
    -- treating the family as fully parented (physicalMass == 0), so we just shift the
    -- ancestor's mass to physical on the (new) contraption.
    hook.Add("cfw.family.becameRoot", "CFW_Mass", function(family)
        local mass        = GetEntMass(family.ancestor)
        local contraption = family.contraption

        family.physicalMass = family.physicalMass + mass
        family.parentedMass = family.parentedMass - mass

        contraption.physicalMass = contraption.physicalMass + mass
        contraption.parentedMass = contraption.parentedMass - mass
    end)
end