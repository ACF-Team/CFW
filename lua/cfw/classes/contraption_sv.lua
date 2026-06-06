CFW.Contraptions        = setmetatable({}, {__mode = 'k'})
CFW.Classes.Contraption = {}

local BASE  = CFW.Classes.EntityCollection
local CLASS = CFW.Classes.Contraption

setmetatable(CLASS, { __index = BASE })
CLASS.__index = CLASS

function CFW.createContraption()
    local con  = {
        ents        = {},                               -- All entities in this contraption
        entsbyclass = {},                               -- All entities by class (for fast class lookups)
        count       = 0,                                -- Number of entities in this contraption
        color       = ColorRand(50, 255),               -- Random color for debug rendering
        families    = setmetatable({}, {__mode = 'k'}), -- All families in this contraption
        physical    = {},                               -- Entities not parented to anything (family ancestors of root families, or non-family entities)
    }

    setmetatable(con, CFW.Classes.Contraption)

    CFW.Contraptions[con] = true

    return con
end

do -- MARK: External API
    local ENT = FindMetaTable("Entity")

    function ENT:CFW_GetContraption()
        return self._contraption
    end
end

-- MARK: Constrained pair
function CLASS:AddConstrainedPair(a, b)
    local link = a._links and a._links[b]

    if link then
        if link.isParent then
            -- Transforming from a parent to constraint

            link.isParent = false
        else
            link:Add()
        end
    else
        CFW.createLink(a, b, false)

        if not self.ents[a] then self:Add(a) end
        if not self.ents[b] then self:Add(b) end
    end
end


do -- MARK: Parented pair
    local function createFamilyWithAncestor(contraption, ancestor)
        local fam = CFW.createFamily(contraption, ancestor)

        hook.Run("cfw.family.init", fam)

        -- Add ancestor
        fam.count          = 1
        fam.ents[ancestor] = true
        ancestor._family   = fam

        -- Blocking entities can create new families on top of existing families
        -- Theyre not physical tho, they're parented to something
        if IsValid(ancestor:GetParent()) then
            contraption.physical[ancestor] = nil
        end

        fam:AddByClass(ancestor)

        hook.Run("cfw.family.added", fam, ancestor)

        return fam
    end

    -- Adds a parented pair to this contraption
    function CLASS:AddParentedPair(child, parent)
        local link = child._links and child._links[parent]

        if link then
            if not link.isParent then
                link.isParent = true
                -- Fix up entA/entB to match the parent-link convention (entA=child, entB=parent).
                -- The original constraint link may have entA/entB in arbitrary order. If we don't
                -- fix this, Link:Remove will operate on the wrong entity: it will Sub the ancestor
                -- out of the family instead of the child, and the child never gets its physical
                -- status restored.
                if link.entA ~= child or link.entB ~= parent then
                    link.entA, link.entB = child, parent
                end
            else
                link:Add()
            end
        else
            CFW.createLink(child, parent, true)

            if not self.ents[child] then self:Add(child) end
            if not self.ents[parent] then self:Add(parent) end
        end

        -- Blockers (e.g. turrets) root their own family instead of joining the parent's:
        -- still parented, but they impede family propagation as a sub-family of the parent.
        if CFW.isBlocker(child:GetClass()) then
            local existingFamily = child._family
            local childFamily    = existingFamily or createFamilyWithAncestor(self, child)

            -- Attach the blocker's family as a SUB-family of the parent's
            -- If it has none, wrap it in a single-member one
            -- this is the only place a non-blocker size-1 family is legitimately created
            --
            -- A parented blocker can't be a root family (physical): It's parented!
            -- The AABB/split/networking traversals walk family -> subFamilies from physical roots
            -- a sub-family hung off a bare with no families entity would never be reached
            local parentFamily = parent._family

            if not parentFamily then
                parentFamily = createFamilyWithAncestor(self, parent)
            end

            childFamily:AttachTo(parentFamily)

            -- Pre-existing root family: its ancestor was physical, so demote its mass
            -- physical -> parented
            -- A freshly created family already counted the ancestor as parented, so don't demote it again
            if existingFamily then
                hook.Run("cfw.family.becameSubFamily", childFamily)
            end

            -- The blocker is parented now, so it leaves the physical set
            -- New-family path: createFamilyWithAncestor already cleared it (we're just doing it again)
            -- Existing-family path: it's still flagged physical from its root-family days -- clear it here
            self.physical[child] = nil

            return
        end

        -- Family management (normal case)
        local parentFamily = parent._family

        if parentFamily then              -- If the parent has a family
            if child._family then         -- And the child has one too
                parentFamily:Merge(child) -- Merge that family
            else
                parentFamily:Add(child)   -- Otherwise just add the child to the parent family
            end
        elseif child._family then
            -- InsertAncestor: parent becomes the new ancestor of child's existing family
            child._family:InsertAncestor(parent)
        else
            local fam = createFamilyWithAncestor(self, parent)
            fam:Add(child)
        end
    end
end

do -- MARK: Splitting
    local function moveEntity(ent, fromContraption, toContraption)
        ent._contraption = toContraption

        toContraption.ents[ent]   = true
        fromContraption.ents[ent] = nil

        toContraption:AddByClass(ent)
        fromContraption:RemoveByClass(ent)

        -- Transfer physical tracking (only if entity was physical)
        if fromContraption.physical[ent] then
            toContraption.physical[ent]   = true
            fromContraption.physical[ent] = nil
        end

        toContraption.count   = toContraption.count + 1
        fromContraption.count = fromContraption.count - 1
    end

    -- Splits the contraption, moving flooded entities to a new contraption
    -- Returns the new child contraption
    function CLASS:Split(flooded, floodedCount)
        -- TODO: The entity count comparison is incorrect, particularly if the contraption is parent-heavy
        -- This count is purely the physical entities

        -- Determine which set is smaller for optimal transfer
        local moveFlooded      = self.count - floodedCount > floodedCount
        local childContraption = CFW.createContraption()

        -- self.physical contains every constraint-reachable entity (family ancestors + bare entities).
        -- For each one in the target set: if it heads a family, migrate the whole family (including any
        -- nested sub-families) via MoveToContraption; otherwise move the bare entity directly.
        for ent in pairs(self.physical) do
            if (flooded[ent] ~= nil) == moveFlooded then
                local family = ent._family

                if family then
                    family:MoveToContraption(self, childContraption)
                else
                    moveEntity(ent, self, childContraption)
                end
            end
        end

        hook.Run("cfw.contraption.init", childContraption)
        hook.Run("cfw.contraption.split", self, childContraption)

        return childContraption
    end
end


function CLASS:Merge(other) -- MARK: Merging
    -- Always absorb the smaller contraption into the larger one
    if other.count > self.count then
        return other:Merge(self)
    end

    self.count = self.count + other.count

    -- Bulk move entities
    for ent in pairs(other.ents) do
        ent._contraption = self
        self.ents[ent]   = true
    end

    self:MergeByClass(other)

    -- Bulk merge physical entities
    for ent in pairs(other.physical) do
        self.physical[ent] = true
    end

    -- Move families by reference
    for family in pairs(other.families) do
        family.contraption = self
        self.families[family] = true
    end

    other.count = 0 -- This must be set before Remove

    other:Remove(true)
    hook.Run("cfw.contraption.merged", other, self)

    return self
end


function CLASS:Add(ent) -- MARK: Add leaf entity
    ent._contraption   = self
    self.ents[ent]     = true
    self.count         = self.count + 1
    self.physical[ent] = true -- Newly added entities are physical until families resolve

    self:AddByClass(ent)

    hook.Run("cfw.contraption.entityAdded", self, ent)
end


function CLASS:Sub(ent) -- MARK: Remove leaf entity
    local wasPhysical = self.physical[ent] ~= nil -- Using GetParent here instead causes incorrect classification

    ent._contraption   = nil
    self.ents[ent]     = nil
    self.count         = self.count - 1
    self.physical[ent] = nil

    self:RemoveByClass(ent)

    hook.Run("cfw.contraption.entityRemoved", self, ent, wasPhysical)
end

function CLASS:Remove(noHook) -- MARK: Remove contraption
    if self.count > 0 then
        ErrorNoHalt("[CFW] Contraption:Remove called with " .. self.count .. " entities remaining\n")
        for ent in pairs(self.ents) do
            ErrorNoHalt("[CFW]   leftover entity: " .. tostring(ent) .. "\n")
        end
    end

    CFW.Contraptions[self] = nil

    if not nohook then
        for family in pairs(self.families) do
            hook.Run("cfw.family.removed", family)
        end

        hook.Run("cfw.contraption.removed", self)
    end
end