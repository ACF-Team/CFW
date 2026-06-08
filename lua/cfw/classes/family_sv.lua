-- Families are collections of parented entities, you know, parents... children...
-- Families are components of Contraptions - parent trees within a contraption
-- Families are created and managed exclusively by Contraptions

CFW.Classes.Family = {}

function CFW.createFamily(contraption, ancestor)
    local fam = {
        count       = 0,
        ents        = {},
        entsbyclass = {},
        ancestor    = ancestor,
        children    = {},
        contraption = contraption,
        color       = ColorRand(),
        -- Sub-family hierarchy: families can be nested when family roots are parented to other families
        parentFamily = nil,      -- The family this family's ancestor is parented into (nil if root family)
        subFamilies  = {},       -- Families attached to this family as children (key = sub-family, value = true)
    }

    setmetatable(fam, CFW.Classes.Family)

    contraption.families[fam] = true

    return fam
end

do -- Class def
    local BASE  = CFW.Classes.EntityCollection
    local CLASS = CFW.Classes.Family

    setmetatable(CLASS, { __index = BASE })
    CLASS.__index = CLASS

    function CLASS:GetRoot()
        return self.ancestor
    end

    function CLASS:CFW_GetContraption()
        return self.contraption
    end


    function CLASS:Remove(noHook) -- MARK: Remove
        -- Remove from parent family's subFamilies
        if self.parentFamily then
            self.parentFamily.subFamilies[self] = nil
            self.parentFamily = nil
        end

        -- Orphan any sub-families (they become root families)
        for subFamily in pairs(self.subFamilies) do
            subFamily.parentFamily = nil
        end

        self.subFamilies = {}

        -- A family must be fully drained (count == 0) before Remove is called.
        -- Each entity must be individually Sub'd via Family:Sub, which clears
        -- _family, decrements count, and restores physical tracking.
        if self.count > 0 then
            ErrorNoHalt("[CFW] Family:Remove called with " .. self.count .. " entities remaining\n")
        end

        self.contraption.families[self] = nil

        if not noHook then
            hook.Run("cfw.family.removed", self)
        end
    end

    -- Attaches this family as a sub-family of the given parent family
    function CLASS:AttachTo(parentFamily) -- MARK: Attach sub-family
        self:Detach() -- Detach from any existing parent family

        self.parentFamily = parentFamily

        parentFamily.subFamilies[self] = true
    end

    -- Detaches this family from its parent family (becomes a root family)
    function CLASS:Detach() -- MARK: Detach sub-family
        -- Already a root family: nothing to detach (e.g. AttachTo's pre-detach
        -- on a family that has no parent yet).
        if not self.parentFamily then return end

        self.parentFamily.subFamilies[self] = nil
        self.parentFamily = nil
    end

    -- Returns true if this family has no parent (is a root family)
    function CLASS:IsRoot() -- MARK: Is root
        return self.parentFamily == nil
    end

    function CLASS:Add(entity) -- MARK: Add -- Add entity
        self.count            = self.count + 1
        self.ents[entity]     = true
        self.children[entity] = true

        entity._family = self

        -- Entity is now parented, no longer physical
        self.contraption.physical[entity] = nil

        self:AddByClass(entity)

        hook.Run("cfw.family.added", self, entity)
    end

    function CLASS:Sub(entity) -- MARK: Sub -- Remove entity
        -- Capture the tracked physical state before restoring it. A normal child is
        -- parented (wasPhysical == false) and becomes physical here; but a dissolving
        -- family's ancestor is already physical (wasPhysical == true), so its mass must
        -- not be moved between tables.
        local wasPhysical = self.contraption.physical[entity] ~= nil

        self.count        = self.count - 1
        self.ents[entity] = nil
        self.children[entity] = nil

        entity._family = nil

        -- Entity is no longer parented into this family; restore it as a physical entity
        self.contraption.physical[entity] = true

        self:RemoveByClass(entity)

        hook.Run("cfw.family.subbed", self, entity, wasPhysical)
    end

    function CLASS:Merge(entity) -- MARK: Merge
        local oldFamily = entity._family

        for ent in pairs(oldFamily.ents) do
            ent._family = self

            self.count         = self.count + 1
            self.ents[ent]     = true
            self.children[ent] = true -- all old-family members (including the old ancestor) become children

            self:AddByClass(ent)
        end

        oldFamily.ents = {}
        oldFamily.children = {}
        oldFamily.entsbyclass = {}
        oldFamily.count = 0

        -- The merged entity (old ancestor) is now a child, no longer physical
        self.contraption.physical[entity] = nil

        -- Transfer sub-families from old family to this family
        for subFamily in pairs(oldFamily.subFamilies) do
            subFamily.parentFamily = self
            self.subFamilies[subFamily] = true
        end

        oldFamily.subFamilies = {}

        oldFamily:Remove(true)

        hook.Run("cfw.family.merged", self, oldFamily)
    end

    -- Removes the current ancestor from the family entirely; an existing child (newAncestor)
    -- is promoted to be the new root. The family shrinks by one. Inverse of InsertAncestor.
    function CLASS:RemoveAncestor(oldAncestor, newAncestor) -- MARK: Remove ancestor
        oldAncestor._family         = nil
        self.ents[oldAncestor]      = nil
        self.count                  = self.count - 1
        self.children[newAncestor]  = nil
        self.children[oldAncestor]  = nil

        self:RemoveByClass(oldAncestor)

        self.ancestor = newAncestor

        -- New ancestor becomes physical (old ancestor will be removed from contraption via Sub)
        self.contraption.physical[newAncestor] = true

        hook.Run("cfw.family.ancestorRemoved", self, oldAncestor, newAncestor)
    end

    -- Inserts a new entity as the family's ancestor, keeping the old ancestor as a child.
    -- The family grows by one. Fires when an entity with its own family is parented to an
    -- entity with no family — the parent becomes the new root, the old ancestor a child.
    function CLASS:InsertAncestor(newAncestor) -- MARK: Insert ancestor
        local oldAncestor       = self.ancestor
        local contraption       = self.contraption

        self.ancestor           = newAncestor
        self.ents[newAncestor]  = true
        self.count              = self.count + 1
        self.children[oldAncestor] = true  -- old ancestor becomes a child
        newAncestor._family     = self

        self:AddByClass(newAncestor)

        -- Old ancestor is now parented, no longer physical
        contraption.physical[oldAncestor] = nil
        -- newAncestor was already added to the contraption via Contraption:Add, which set physical = true

        hook.Run("cfw.family.ancestorInserted", self, oldAncestor, newAncestor)
    end

    do -- MARK: Splitting
        local function moveToNewContraption(oldFamily, newFamily, newContraption, ent, isAncestor)
            local oldContraption = oldFamily.contraption

            -- Remove from old family
            oldFamily.ents[ent] = nil
            oldFamily.count     = oldFamily.count - 1

            oldFamily:RemoveByClass(ent)

            if not isAncestor then
                oldFamily.children[ent] = nil
            end

            -- Remove from old contraption (physical tracking not needed - was either ancestor or child)
            oldContraption.ents[ent]     = nil
            oldContraption.count         = oldContraption.count - 1
            oldContraption.physical[ent] = nil

            oldContraption:RemoveByClass(ent)

            -- Add to new family
            ent._family = newFamily

            newFamily.ents[ent] = true
            newFamily.count     = newFamily.count + 1
            newFamily:AddByClass(ent)

            if not isAncestor then
                newFamily.children[ent] = true
            end

            -- Add to new contraption
            ent._contraption = newContraption

            newContraption.ents[ent] = true
            newContraption.count     = newContraption.count + 1

            newContraption:AddByClass(ent)

            -- Only ancestor is physical in new contraption
            if isAncestor then
                newContraption.physical[ent] = true
            end

            -- Recurse to children (normal family members only - not family roots)
            local children = ent._children
            if not children then return end

            for child in pairs(children) do
                if child and IsValid(child) and child ~= ent then
                    -- Check if child is a family root (has its own family as a sub-family)
                    local childFamily = child._family

                    if childFamily then
                        local isSubFamily = childFamily ~= oldFamily

                        if isSubFamily then
                            -- Child is a family root - transfer its sub-family relationship to newFamily
                            -- and migrate all of its entities and nested sub-families to the new contraption

                            oldFamily.subFamilies[childFamily] = nil
                            newFamily.subFamilies[childFamily] = true

                            childFamily.parentFamily = newFamily
                            childFamily:MoveToContraption(oldContraption, newContraption)
                        else
                            -- Normal child - recurse
                            moveToNewContraption(oldFamily, newFamily, newContraption, child, false)
                        end
                    end
                end
            end
        end

        -- Moves this family and all its sub-families to a different contraption.
        -- Transfers entity tracking, contraption pointers, and physical entries.
        function CLASS:MoveToContraption(oldContraption, newContraption)
            oldContraption.families[self] = nil
            newContraption.families[self] = true
            self.contraption              = newContraption

            for ent in pairs(self.ents) do
                ent._contraption             = newContraption

                oldContraption.ents[ent]     = nil
                oldContraption.count         = oldContraption.count - 1
                oldContraption:RemoveByClass(ent)

                newContraption.ents[ent]     = true
                newContraption.count         = newContraption.count + 1
                newContraption:AddByClass(ent)

                if oldContraption.physical[ent] then
                    oldContraption.physical[ent] = nil
                    newContraption.physical[ent] = true
                end
            end

            for subFamily in pairs(self.subFamilies) do
                subFamily:MoveToContraption(oldContraption, newContraption)
            end
        end

        function CLASS:Split(child)
            local oldContraption = self.contraption
            local newContraption = CFW.createContraption()
            local newFamily      = CFW.createFamily(newContraption, child)

            moveToNewContraption(self, newFamily, newContraption, child, true)

            hook.Run("cfw.contraption.init", newContraption)
            hook.Run("cfw.family.init", newFamily)
            hook.Run("cfw.family.split", self, newFamily, child)
            hook.Run("cfw.contraption.split", oldContraption, newContraption)
            -- child was a parented member of the old family/contraption and is now the
            -- physical ancestor of the new one: apply the parented -> physical transition
            -- after the split totals have been computed treating it as parented.
            hook.Run("cfw.family.becameRoot", newFamily)
        end
    end
end

do -- MARK: External API
    local ENT = FindMetaTable("Entity")

    function ENT:GetFamily()
        return self._family
    end

    function ENT:GetAncestor()
        local Family = self._family
        return Family and Family.ancestor or self
    end

    function ENT:GetFamilyChildren()
        local Family = self._family
        return Family and Family.children or self:GetChildren()
    end
end
