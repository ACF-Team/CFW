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

-- What CFW sees as an engine parent: detour targets, and owners instead of their proxies
local function logicalParent(parent)
    if not IsValid(parent) then return parent end

    local detour = detours[parent:GetClass()]

    if detour then
        parent = detour(parent) or parent
    end

    return toOwner(parent)
end

-- Requested parents with CFW callbacks, kept from preParent until the matching postParent
local pendingParent = {}

-- The engine's GetParent and GetChildren, set once the detours go in
local getParent, getChildren, getMoveParent

-- Children of an engine parent, keeping the shape GetChildren gave. Addons can replace GetChildren
-- (Multi-Parent tool) with one that misses bone followers and keeps children that already moved away
local function childrenOf(target)
    local children = getChildren(target)
    local keyed    = next(children) ~= nil and isentity(next(children))
    local out, seen = {}, {}

    local function add(child)
        if seen[child] or not IsValid(child) then return end
        if getParent(child) ~= target and getMoveParent(child) ~= target then return end

        seen[child] = true

        if keyed then out[child] = child else out[#out + 1] = child end
    end

    for k, v in pairs(children) do add(isentity(k) and k or v) end

    local tracked = target._cfwChildren

    if tracked then
        for child in pairs(tracked) do
            if IsValid(child) and getParent(child) == target then add(child) else tracked[child] = nil end
        end
    end

    return out
end

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

        preParent runs everything before the engine call and postParent everything after it.
]]

-- Returns false to block, otherwise the parent the engine should actually attach to
local function preParent(self, oldParent, newParent, newAttach, ...)
    -- Check if the entity is able to be a child to this parent or not.
    if self.CFW_PreParentedTo and self:CFW_PreParentedTo(oldParent, newParent, newAttach, ...) == false then
        return false
    end

    local savedParent

    if IsValid(newParent) then
        -- Store savedParent so we can do CFW_PreParented and CFW_OnParented later on the actual target
        if newParent.CFW_OnParented or newParent.CFW_PreParented then
            savedParent = newParent
        end

        -- Detour targets are logical parents
        local detour = detours[newParent:GetClass()]

        if detour then
            newParent = detour(newParent) or newParent
        end

        -- If parenting to an owner, attach to its proxy in the engine
        newParent = toProxy(newParent)
    end

    -- Block parenting to self (why doesn't this just happen earlier on?? that case would never be valid!)
    if self == newParent then return false end

    -- Check if the parent is willing to accept this child or not
    if IsValid(savedParent) and savedParent.CFW_PreParented and savedParent:CFW_PreParented(self) == false then
        return false
    end

    -- The engine breaks a cycle by unparenting the new parent's ancestor that hangs off self, without going through Lua
    local ancestor = newParent

    while IsValid(ancestor) do
        local up = getParent(ancestor)

        if up == self then
            ancestor:SetParent(nil)
            break
        end

        ancestor = up
    end

    -- At this point on, nothing else will block the parenting call
    -- Pre-deparenting hook
    -- MARCH: Changed this to not check "not validNewParent" (didn't really make sense... and didn't allow deparenting checks unless there was no valid parent??)
    if IsValid(oldParent) and oldParent.CFW_OnParented then
        oldParent:CFW_OnParented(self, false)
    end

    pendingParent[self] = savedParent

    return newParent
end

-- oldParent and newParent are engine parents, the proxy rather than its owner
local function postParent(self, oldParent, newParent)
    local savedParent = pendingParent[self]
    pendingParent[self] = nil

    if IsValid(oldParent) and oldParent._cfwChildren then oldParent._cfwChildren[self] = nil end
    if IsValid(newParent) then
        newParent._cfwChildren = newParent._cfwChildren or {}
        newParent._cfwChildren[self] = true
    end

    -- Hook for post-new-child
    if IsValid(savedParent) and savedParent.CFW_OnParented then
        savedParent:CFW_OnParented(self, true)
    end

    -- Hook for post-new-parent
    if self.CFW_OnParentedTo then
        self:CFW_OnParentedTo(oldParent, newParent)
    end

    local validOldParent, validNewParent = IsValid(oldParent), IsValid(newParent)

    if self._cfwRemoved then return end -- Removed by an undo
    if oldParent == newParent then return end
    if (validOldParent and oldParent:IsPlayer()) or (validNewParent and newParent:IsPlayer()) then return end
    if (validOldParent and oldParent:IsNPC()) or (validNewParent and newParent:IsNPC()) then return end
    if (validOldParent and oldParent:IsNextBot()) or (validNewParent and newParent:IsNextBot()) then return end

    local entClass = self:GetClass()
    if filter[entClass] then return end

    -- Hide transform proxies from CFW: the link, family, and contraption all use the
    -- logical parent, while the engine attach may use the proxy
    local logicalOldParent = logicalParent(oldParent)
    local logicalNewParent = logicalParent(newParent)

    -- Handle the edge case where an entity was originally parented in-engine but is being reparented in the same tick before we could even detect the old parent
    local isUnlinkedSpecialEngineEnt = validOldParent and specialEngineEnts[entClass] and not self:GetCFWLink(logicalOldParent)

    if validOldParent and not isUnlinkedSpecialEngineEnt then disconnect(self, logicalOldParent:EntIndex()) end
    if IsValid(logicalNewParent) then connect(self, logicalNewParent) end

    if self.CFW_NO_FAMILY_TRAVERSAL then return end

    if IsValid(logicalNewParent) then
        local newParentFamily = logicalNewParent:GetFamily() or CFW.Classes.Family.create(logicalNewParent)

        -- A new family finds its members through GetChildren, which addons can replace with one that misses bone followers
        if self:GetFamily() ~= newParentFamily then
            self:SetFamily(newParentFamily)
        end
    else
        self:SetFamily(nil)
    end
end

hook.Add("Initialize", "CFW", function()
    timer.Simple(0, function()
        local ENT = FindMetaTable("Entity")

        getParent     = ENT.GetParent
        getChildren   = ENT.GetChildren
        getMoveParent = ENT.GetMoveParent

        -- SetParent and FollowBone both parent in the engine
        local function overrideParenting(name)
            local engineFn = ENT[name]

            ENT[name] = function(self, newParent, newAttach, ...)
                local oldParent    = getParent(self)
                local engineParent = preParent(self, oldParent, newParent, newAttach, ...)

                if engineParent == false then return end

                engineFn(self, engineParent, newAttach, ...)
                postParent(self, oldParent, engineParent)
            end
        end

        overrideParenting("SetParent")
        overrideParenting("FollowBone")

        function ENT:GetParent()
            return logicalParent(getParent(self))
        end

        function ENT:GetChildren()
            -- A transform-proxy owner's children actually live on its proxy
            return childrenOf(toProxy(self))
        end
    end)

    hook.Remove("Initialize", "CFW")
end)

-- The parent inputs (Fire, map I/O, wire) never call the Lua functions, so do them through SetParent instead
hook.Add("AcceptInput", "CFW", function(ent, input, activator, caller, value)
    input = string.lower(input)

    if input == "clearparent" then
        ent:SetParent(nil)
        return true
    end

    if input ~= "setparent" then return end

    if not value or value == "" then
        ent:SetParent(nil)
        return true
    end

    local target
    if value == "!activator" then target = activator
    elseif value == "!caller" then target = caller
    elseif value == "!self" then target = ent
    else target = ents.FindByName(value)[1] end

    -- Unknown names go to the engine, which warns about the bad parent
    if not IsValid(target) then return end

    ent:SetParent(target)
    return true
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
