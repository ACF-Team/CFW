-- Links are an abstraction of constraints and parents or "connections"
-- These are used to keep track of the number of connections between two entities
-- In graph theory these are edges

CFW.Classes.Link = {}

local CLASS = CFW.Classes.Link

CLASS.__index = CLASS

function CFW.createLink(a, b, isParent)
    local link = {
        entA     = a,
        entB     = b,
        count    = 1,
        isParent = isParent or false,
        color    = ColorRand()
    }

    a._links = a._links or {}
    b._links = b._links or {}

    a._links[b] = link
    b._links[a] = link

    setmetatable(link, CFW.Classes.Link)

    return link
end

-- Simple incrementing of counter whenever another constraint is added between two entities already constrained together
-- In the case of parents, there will only be 1 connection between two entities
function CLASS:Add()
    self.count = self.count + 1
end -- MARK: Add

-- Decrements the connection count; removes the link when count reaches zero
function CLASS:Sub() -- MARK: Sub
    self.count = self.count - 1

    if self.count == 0 then
        self:Remove()
    end
end

do -- MARK: Remove
    -- Flood-fill over constraint edges only (parent edges are skipped)
    -- Parent links form trees — an entity has exactly one parent, so
    -- removing a parent link is guaranteed to separate that subtree
    -- Returns (true, visitedEntities) if sink is reachable from source
    -- (false, visitedEntities, visitedCount) if it is not
    local function floodFill(source, sink)
        local closed      = {[source] = true}
        local closedCount = 1
        local open        = {}

        -- Initialize open set from source's constraint links (skip parent links)
        for neighbor, link in pairs(source._links) do
            if not link.isParent then
                open[neighbor] = true
            end
        end

        -- Flood outwards until we find the target
        while next(open) do
            local ent = next(open)

            open[ent]   = nil
            closed[ent] = true

            closedCount = closedCount + 1

            if ent == sink then return true, closed end

            for neighbor, link in pairs(ent._links) do
                if not closed[neighbor] and not link.isParent then
                    open[neighbor] = true
                end
            end
        end

        return false, closed, closedCount
    end

    -- Post-detach cleanup for the parent side of a just-removed blocker parent link
    --
    -- When a blocker (e.g. a turret) is parented CFW gives the parent a family
    -- purely so the blocker's family has something to attach to as a sub-family
    -- 
    -- The caller has just detached the blocker's family, so that wrapper family may now be pointless
    --
    --   parentFamily : parent's family captured before the link was removed (may be nil)
    --   parent       : the entity the blocker had been parented to
    --   contraption  : the child's contraption, captured at the top of Link:Remove
    --   bIsLeaf      : true if parent has no remaining links of its own
    local function dissolveDetachedParent(parentFamily, parent, contraption, bIsLeaf)
        -- Has parentFamily become a single-member family with no subFamilies?
        --   * parentFamily is a root family (parentFamily.parentFamily == nil)
        --   * count == 1 -- the ancestor is its sole member
        --   * no subFamilies -- no OTHER blocker still hangs off it (e.g. a second turret
        --     sharing the same baseplate), which would keep the family meaningful
        -- Together these mean the family existed only to host the now-departed blocker/turret
        -- dissolve it and let the ancestor revert to a bare physical entity
        if parentFamily and parentFamily.parentFamily == nil and parentFamily.count == 1 and not next(parentFamily.subFamilies) then
            parentFamily:Sub(parentFamily.ancestor)
            parentFamily:Remove()

            -- The ancestor (parent) is now a bare physical entity.
            -- Only remove it from the contraption if it now has no third party connection to the contraption
            if bIsLeaf then
                contraption:Sub(parent)
            end
        end

        if contraption.count == 0 then contraption:Remove() end
    end

    function CLASS:Remove()
        local entA, entB  = self.entA, self.entB
        local contraption = entA._contraption

        -- Remove the link reference from both entities
        entA._links[entB] = nil
        entB._links[entA] = nil

        -- Are they leafs? (an entity with no connections to other entities)
        local aIsLeaf = not next(entA._links)
        local bIsLeaf = not next(entB._links)

        -- Handle family changes for parent links
        -- For parent links: entA is child, entB is parent
        if self.isParent then
            local child, parent = entA, entB
            local childFamily   = child._family
            local parentFamily  = parent._family

            -- Check if child is in its own family (family root / sub-family) rather than parent's family
            -- Family roots (e.g., turrets) have their own family and are not part of parent's family
            -- In this case, detach the sub-family relationship and let contraption split handle the rest
            if childFamily and childFamily ~= parentFamily then
                -- Child is a family root - detach from parent family (becomes a root family)
                childFamily:Detach()

                if aIsLeaf then
                    if childFamily.count == 1 then
                        childFamily:Sub(child)
                        childFamily:Remove()
                        -- Child is now bare and isolated; Sub it from the contraption,
                        -- and drain the parent if it is also bare and leaf
                        contraption:Sub(child)
                        -- After detaching child's family, dissolve a now-zombie parent family
                        dissolveDetachedParent(parentFamily, parent, contraption, bIsLeaf)
                        return
                    else
                        -- Family root is a constraint-leaf but has parented children
                        -- Split the entire family off into its own new contraption
                        local newContraption = CFW.createContraption()
                        childFamily:MoveToContraption(contraption, newContraption)
                        newContraption.physical[child] = true -- ancestor is now a physical root

                        hook.Run("cfw.contraption.init", newContraption)
                        hook.Run("cfw.contraption.split", contraption, newContraption)
                        hook.Run("cfw.family.becameRoot", childFamily)

                        -- After detaching child's family, dissolve a now-zombie parent family
                        dissolveDetachedParent(parentFamily, parent, contraption, bIsLeaf)
                        return
                    end
                else
                    -- Non-leaf family root: the child still has links (parent or constraint)
                    -- The flood-fill path below is skipped for parent links, so we must
                    -- explicitly move the sub-family to its own contraption here
                    local newContraption = CFW.createContraption()
                    childFamily:MoveToContraption(contraption, newContraption)
                    newContraption.physical[child] = true -- ancestor is now a physical root

                    hook.Run("cfw.contraption.init", newContraption)
                    hook.Run("cfw.contraption.split", contraption, newContraption)
                    hook.Run("cfw.family.becameRoot", childFamily)

                    -- After detaching child's family, dissolve a now-zombie parent family
                    dissolveDetachedParent(parentFamily, parent, contraption, bIsLeaf)
                    return
                end
            elseif parentFamily then
                -- Typical case: child is in parent's family
                if parentFamily.ancestor == parent and not aIsLeaf and bIsLeaf then
                    -- RemoveAncestor: parent is ancestor, child has parented children, parent has no other links
                    -- Since constraints and parents are mutually exclusive, not aIsLeaf guarantees
                    -- child has parented children.
                    parentFamily:RemoveAncestor(parent, child)

                    if parentFamily.parentFamily == nil and parentFamily.count == 1 and not next(parentFamily.subFamilies) then
                        parentFamily:Sub(parentFamily.ancestor)
                        parentFamily:Remove()
                        -- The new ancestor (child) is now bare (no family).
                        -- If it is also a leaf with no remaining links, remove it
                        -- from the contraption so it doesn't become a zombie
                        if not next(child._links) then
                            contraption:Sub(child)
                        end
                    end

                    -- Old ancestor (parent) has no links and is no longer in any family:
                    -- remove it from the contraption. The generic "one leaf" path below
                    -- is skipped for parent links, so we must handle it explicitly here
                    contraption:Sub(parent)
                elseif not aIsLeaf then
                    -- Child heads its own sub-tree (all remaining links are parent links,
                    -- since constraints and parents are mutually exclusive).
                    -- Split the sub-tree into a new contraption.
                    parentFamily:Split(child)

                    if parentFamily.parentFamily == nil and parentFamily.count == 1 and not next(parentFamily.subFamilies) then
                        parentFamily:Sub(parentFamily.ancestor)
                        parentFamily:Remove()
                    end

                    return
                else
                    -- Child is a leaf, just remove it from the family
                    parentFamily:Sub(child)

                    if parentFamily.parentFamily == nil and parentFamily.count == 1 and not next(parentFamily.subFamilies) then
                        -- Family dissolves.  If the parent is also now a leaf,
                        -- both are leaves: the "both leaves" path below will
                        -- Sub both and Remove.  Otherwise the child must be
                        -- Sub'd from the contraption individually.
                        parentFamily:Sub(parentFamily.ancestor)
                        parentFamily:Remove()
                        if not bIsLeaf then
                            contraption:Sub(child)
                        end
                    else
                        -- Child is now isolated (no family, no links): remove from contraption.
                        -- The generic "one leaf → Contraption:Sub" path below is skipped for
                        -- parent links, so we must handle it explicitly here
                        contraption:Sub(child)
                    end
                end
            end
        end

        -- Parent links: the isParent block above handles family restructuring and
        -- leaf removal when a family persists.  The generic "one leaf" paths
        -- below are skipped for parent links (they would undo physical tracking that Family:Sub just set)

        -- Both entities are now isolated.  Sub each from the contraption so
        -- the internal tables are naturally empty before Remove.
        if aIsLeaf and bIsLeaf then
            contraption:Sub(entA)
            contraption:Sub(entB)
            contraption:Remove()
            return
        end

        -- One entity is a leaf being trimmed.
        -- For parent links, a leaf entity was already Sub'd from its family and
        -- marked physical — do NOT trim it from the contraption.
        if aIsLeaf and not self.isParent then
            contraption:Sub(entA)
            return
        end

        if bIsLeaf and not self.isParent then
            contraption:Sub(entB)
            return
        end

        -- Parent-link removal is fully handled by the isParent block above
        if self.isParent then return end

        -- Only constraint linsk get this far
        -- Both entities still have other links - check for an indirect connection by flood filling
        local indirectlyConnected, flooded, floodedCount = floodFill(entA, entB)

        if not indirectlyConnected then
            contraption:Split(flooded, floodedCount)
        end
    end
end

do -- MARK: Entity API
    local ENT = FindMetaTable("Entity")

    function ENT:GetCFWLink(other)
        return self._links and self._links[other] or nil
    end

    function ENT:GetCFWLinks()
        local links = self._links
        local out   = {}

        if links then
            for k, v in pairs(links) do
                out[k] = v
            end
        end

        return out
    end
end