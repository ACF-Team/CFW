local connect    = CFW.connect
local disconnect = CFW.disconnect
local filter     = {
    gmod_hands = true
}
local specialEngineEnts = {
    env_sprite = true,
    env_spritetrail = true,
}

CFW.parentFilter = filter

local blockers = {}

-- A "transform proxy" pairs a logical OWNER entity (e.g. a turret drive) with an internal PROXY entity (e.g. its rotator)
-- The proxyowns the physical and transform (position and orientation)
-- The owner stays the contraption-visible parent; the proxy never appears in connectivity
local ownerToProxy = {} -- [ownerClass] = field on the owner holding its proxy   (owner -> proxy)
local proxyToOwner = {} -- [proxyClass] = field on the proxy holding its owner   (proxy -> owner)

-- Resolves a transform-proxy owner to its proxy (turret -> rotator), or returns it unchanged
local function toProxy(entity)
    local field = ownerToProxy[entity:GetClass()]

    if not field then return entity end

    local proxy = entity[field]
    return IsValid(proxy) and proxy or entity
end

-- Registers an entity class that should always be the root of its own family
-- This is useful for entities like turrets that rotate independently of their parent
function CFW.addBlocker(class)
    if not class then return end
    blockers[class] = true
end

function CFW.removeBlocker(class)
    if not class then return end
    blockers[class] = nil
end

function CFW.isBlocker(class)
    return blockers[class] or false
end

-- Gets the physical root for an entity (the entity whose transform is used for hull/CoM)
-- For a transform-proxy owner this is its proxy (e.g. a turret's rotator); otherwise the entity
function CFW.getPhysicalRoot(entity)
    if not IsValid(entity) then return entity end

    return toProxy(entity)
end

-- Registers the whole "transform proxy" for an ACF turret entity
--
-- The owner points at its proxy via ownerField; the proxy points back at the owner via proxyField.
-- From just that pair everything else is derived:
--   * owner is a blocker
--   * proxy is invisible to connectivity (engine-parented only, never a CFW link)
--   * children parented to the owner attach to the proxy in the engine, but link to the OWNER;
--     GetParent / GetChildren resolve through the proxy so it stays hidden either way
--   * hull/CoM math uses the proxy's transform (getPhysicalRoot)
--
-- CFW.addTransformProxy("acf_turret", "Rotator", "acf_turret_rotator", "Turret")
function CFW.addTransformProxy(ownerClass, ownerField, proxyClass, proxyField)
    if not (ownerClass and ownerField and proxyClass and proxyField) then return end

    ownerToProxy[ownerClass] = ownerField -- owner -> proxy (engine parent, children, transform)
    proxyToOwner[proxyClass] = proxyField -- proxy -> owner (logical GetParent)

    blockers[ownerClass] = true           -- owner rotates independently: roots its own family
    filter[proxyClass]   = true           -- proxy never shows up in CFW
end

hook.Add("Initialize", "CFW", function()
    timer.Simple(0, function()
        local ENT         = FindMetaTable("Entity")
        local setParent   = ENT.SetParent
        local getParent   = ENT.GetParent
        local getChildren = ENT.GetChildren

        --[[
            The hooks here are as follows:
            (we need better docs! many such cases!)

                - CFW_PreParentedTo: Allows the entity to block itself from being parented.
                - CFW_PreParented: Allows the entity to block another entity from being parented to it.
                - CFW_OnParentedTo: A non-blockable equiv. of PreParentedTo
                - CFW_OnParented: A non-blockable equiv. of PreParented

                The hook order is this:
                    - CFW_PreParentedTo on potential child (may block)
                    - CFW_PreParented on potential parent (may block)
                    - If a valid old parent exists, CFW_OnParented(child, false)
                    - ACTUAL SET PARENT HAPPENS
                    - If a valid new parent, call CFW_OnParented
                    - Call self OnParentedTo
        ]]
        function ENT:SetParent(newParent, newAttach, ...)
            local savedParent
            local oldParent = getParent(self)
            local validNewParent = IsValid(newParent)
            local validOldParent = IsValid(oldParent)

            -- Hide the actual parent from CFW if it's a transform proxy
            local logicalNewParent = newParent
            local logicalOldParent = self:GetParent()

            -- Check if the entity is able to be a child to this parent or not.
            if self.CFW_PreParentedTo and self:CFW_PreParentedTo(oldParent, newParent, newAttach, ...) == false then
                return
            end

            if validNewParent then
                -- Store savedParent so we can do CFW_PreParented and CFW_OnParented later on the actual target
                if newParent.CFW_OnParented or newParent.CFW_PreParented then
                    savedParent = newParent
                end

                -- Parenting to a transform-proxy owner attaches to its proxy in the engine (e.g. a turret's rotator)
                -- The CFW link uses the logical parent (logicalNewParent)
                newParent      = toProxy(newParent)
                validNewParent = IsValid(newParent)
            end

            -- Block parenting to self (why doesn't this just happen earlier on?? that case would never be valid!)
            if self == newParent then return end

            local validSavedParent = IsValid(savedParent)

            -- Check if the parent is willing to accept this child or not
            if validSavedParent and savedParent.CFW_PreParented and savedParent:CFW_PreParented(self) == false then
                return
            end

            -- At this point on, nothing else will block the parenting call
            -- Pre-deparenting hook
            -- MARCH: Changed this to not check "not validNewParent" (didn't really make sense... and didn't allow deparenting checks unless there was no valid parent??)
            if validOldParent and oldParent.CFW_OnParented then
                oldParent:CFW_OnParented(self, false)
            end

            -- Actual setparent call
            setParent(self, newParent, newAttach, ...)

            -- Hook for post-new-child
            if validSavedParent and savedParent.CFW_OnParented then
                savedParent:CFW_OnParented(self, true)
            end

            -- Hook for post-new-parent
            if self.CFW_OnParentedTo then
                self:CFW_OnParentedTo(oldParent, newParent)
            end

            if oldParent == newParent then return end
            if (validOldParent and oldParent:IsPlayer()) or (validNewParent and newParent:IsPlayer()) then return end
            if (validOldParent and oldParent:IsNPC()) or (validNewParent and newParent:IsNPC()) then return end
            if (validOldParent and oldParent:IsNextBot()) or (validNewParent and newParent:IsNextBot()) then return end

            local entClass = self:GetClass()
            if filter[entClass] or specialEngineEnts[entClass] then return end

            -- Constraints and parenting are mutually exclusive - remove ALL constraints on the child
            if validNewParent and self.Constraints then
                for i = #self.Constraints, 1, -1 do
                    local con = self.Constraints[i]

                    if IsValid(con) then
                        local other = con.Ent1 == self and con.Ent2 or con.Ent1

                        con:RemoveCallOnRemove("CFW")

                        if IsValid(other) and other ~= newParent and CFW.isConstraint[con:GetClass()] then
                            disconnect(self, other)
                        end

                        con:Remove()
                    end
                end
            end

            -- Handle the edge case where an entity was originally parented in-engine but is being reparented in the same tick before we could even detect the old parent
            local isUnlinkedSpecialEngineEnt = validOldParent and specialEngineEnts[entClass] and not self:GetCFWLink(logicalOldParent)

            if validOldParent and not isUnlinkedSpecialEngineEnt then
                disconnect(self, logicalOldParent)
            end

            if IsValid(logicalNewParent) then
                connect(self, logicalNewParent, true)
            end
        end

        function ENT:GetParent()
            local parent = getParent(self)

            if IsValid(parent) then
                -- If the engine parent is a transform proxy (e.g. a turret's rotator)
                -- report its owner (the turret drive) instead, so the proxy stays hidden
                local field = proxyToOwner[parent:GetClass()]

                if field then
                    local owner = parent[field]

                    -- Guard against self-referential loops (a proxy whose owner is self)
                    if IsValid(owner) and owner ~= self then
                        parent = owner
                    end
                end
            end

            return parent
        end

        function ENT:GetChildren()
            -- A transform-proxy owner's children actually live on its proxy (e.g. the rotator)
            local proxy = toProxy(self)

            if proxy ~= self then
                return getChildren(proxy)
            end

            return getChildren(self)
        end
    end)

    hook.Remove("Initialize", "CFW")
end)

-- Attempting to handle some entities that are parented in the engine before we can reach them
hook.Add("OnEntityCreated", "cfw.engineParentedEntityCreated", function(ent)
    if not specialEngineEnts[ent:GetClass()] then return end

    timer.Simple(0, function()
        if not IsValid(ent) then return end

        local parent = ent:GetParent()
        if not IsValid(parent) or ent:GetCFWLink(parent) then return end

        connect(ent, parent, true)
    end)
end)