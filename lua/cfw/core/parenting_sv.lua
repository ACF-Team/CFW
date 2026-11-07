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

-- A "transform proxy" pairs a logical OWNER entity (e.g. a turret drive) with an internal PROXY
-- entity (e.g. its rotator). The proxy owns the physical transform; the owner stays the
-- contraption-visible parent, and the proxy never appears in CFW's connectivity
local ownerToProxy = {} -- [ownerClass] = field on the owner holding its proxy   (owner -> proxy)
local proxyToOwner = {} -- [proxyClass] = field on the proxy holding its owner   (proxy -> owner)

-- Resolves a transform-proxy owner to its proxy (turret -> rotator), or returns it unchanged
local function toProxy(entity)
    local field = ownerToProxy[entity:GetClass()]
    if not field then return entity end

    local proxy = entity[field]
    return IsValid(proxy) and proxy or entity
end

-- Resolves a transform proxy to its owner (rotator -> turret), or returns it unchanged
local function toOwner(entity)
    local field = proxyToOwner[entity:GetClass()]
    if not field then return entity end

    local owner = entity[field]
    return IsValid(owner) and owner or entity
end

-- Registers a transform-proxy pair: an owner entity whose children actually attach to an internal
-- proxy in the engine. The proxy is filtered out of CFW entirely; it never gets a link, family
-- membership, or contraption entry, and GetParent/GetChildren resolve through it so it stays
-- invisible to traversal
-- CFW.addTransformProxy("acf_turret", "Rotator", "acf_turret_rotator", "Turret")
function CFW.addTransformProxy(ownerClass, ownerField, proxyClass, proxyField)
    if not ownerClass then return end
    if not ownerField then return end
    if not proxyClass then return end
    if not proxyField then return end

    ownerToProxy[ownerClass] = ownerField
    proxyToOwner[proxyClass] = proxyField
    filter[proxyClass]       = true
end

local detours = {}

function CFW.addParentDetour(class, variable)
    if not class then return end
    if not variable then return end

    detours[class] = function(entity)
        return entity[variable]
    end
end

hook.Add("Initialize", "CFW", function()
    timer.Simple(0, function()
        local ENT        = FindMetaTable("Entity")
        local setParent  = ENT.SetParent
        local getParent  = ENT.GetParent
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

            -- Hide transform proxies from CFW: the link, family, and contraption all use the
            -- logical parent, while the engine attach may use the proxy (its owner transforms
            -- its children through the proxy)
            local logicalNewParent = newParent
            local logicalOldParent = self:GetParent()

            -- Check if the entity is able to be a child to this parent or not.
            if self.CFW_PreParentedTo and self:CFW_PreParentedTo(oldParent, newParent, newAttach, ...) == false then
                return
            end

            -- If a valid new parent, get any entity detours that may be present for the new parents class
            if validNewParent then
                local detour = detours[newParent:GetClass()]

                -- Store savedParent so we can do CFW_PreParented and CFW_OnParented later on the actual target
                if newParent.CFW_OnParented or newParent.CFW_PreParented then
                    savedParent = newParent
                end

                -- Set newParent to detour
                if detour then
                    -- march note: shouldn't we be setting validNewParent again here?
                    -- won't do it for now to avoid breaking anything, but seems like an obvious one
                    newParent        = detour(newParent) or newParent
                    logicalNewParent = newParent -- Detour targets are logical parents
                end

                -- If parenting directly to a proxy, the logical parent is its owner
                local owner = toOwner(newParent)

                if owner ~= newParent then
                    logicalNewParent = owner
                end

                -- If parenting to an owner, attach to its proxy in the engine
                local proxy = toProxy(newParent)

                if proxy ~= newParent then
                    newParent      = proxy
                    validNewParent = IsValid(newParent)
                end
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

            if self._cfwRemoved then return end -- Removed by an undo
            if oldParent == newParent then return end
            if (validOldParent and oldParent:IsPlayer()) or (validNewParent and newParent:IsPlayer()) then return end
            if (validOldParent and oldParent:IsNPC()) or (validNewParent and newParent:IsNPC()) then return end
            if (validOldParent and oldParent:IsNextBot()) or (validNewParent and newParent:IsNextBot()) then return end

            local entClass = self:GetClass()
            if filter[entClass] then return end

            -- Handle the edge case where an entity was originally parented in-engine but is being reparented in the same tick before we could even detect the old parent
            local isUnlinkedSpecialEngineEnt = validOldParent and specialEngineEnts[entClass] and not self:GetCFWLink(logicalOldParent)

            if validOldParent and not isUnlinkedSpecialEngineEnt then disconnect(self, logicalOldParent:EntIndex(), isParent) end
            if IsValid(logicalNewParent) then connect(self, logicalNewParent, isParent) end

            if self.CFW_NO_FAMILY_TRAVERSAL then return end

            if IsValid(logicalNewParent) then
                local newParentFamily = logicalNewParent:GetFamily()

                if newParentFamily then
                    self:SetFamily(newParentFamily)
                else
                    CFW.Classes.Family.create(logicalNewParent)
                end
            else
                self:SetFamily(nil)
            end
        end

        function ENT:GetParent()
            local parent = getParent(self)

            if IsValid(parent) then
                local detour = detours[parent:GetClass()]

                if detour then
                    parent = detour(parent) or parent
                end

                -- If the engine parent is a transform proxy, report its owner instead
                local owner = toOwner(parent)

                if owner ~= parent then
                    parent = owner
                end
            end

            return parent
        end

        function ENT:GetChildren()
            -- A transform-proxy owner's children actually live on its proxy
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

        connect(ent, parent)

        if ent.CFW_NO_FAMILY_TRAVERSAL then return end

        local parentFamily = parent:GetFamily()

        if parentFamily then
            ent:SetFamily(parentFamily)
        else
            CFW.Classes.Family.create(parent)
        end
    end)
end)

-- In order to prevent NULL entities flooding the ENT._links table, we'll just get rid of them before they get removed
-- This is a fix for a really annoying issue that was showing up in multiple different ways
hook.Add("EntityRemoved", "cfw.entityRemoved", function(ent)
    if not IsValid(ent) then return end

    ent.CFW_REMOVING = true
    local links = ent:GetCFWLinks()

    if not next(links) then return end

    for index in pairs(links) do
        disconnect(ent, index)
    end
end)
