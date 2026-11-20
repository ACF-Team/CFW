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

local function isCharacter(ent)
    return IsValid(ent) and (ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot())
end

-- The parent an entity's parent link was added for, so unparenting takes away exactly what parenting added
-- Connects first so moving between parents in one contraption doesn't split it in between
local function setLinkedParent(ent, parent)
    local old = ent._cfwLinkedParent
    if old == parent then return end

    ent._cfwLinkedParent = parent

    if IsValid(parent) then connect(ent, parent) end
    if IsValid(old) and ent._links then disconnect(ent, old:EntIndex()) end
end

-- Brings an entity's parent link and family in line with its engine parent
local function trackParent(ent, engineParent)
    if isCharacter(ent) then return end
    if filter[ent:GetClass()] then return end

    -- Hide transform proxies from CFW: the link, family, and contraption all use the
    -- logical parent, while the engine attach may use the proxy
    -- Players, NPCs and nextbots never join a contraption, so parenting to one counts as unparenting
    local parent = not isCharacter(engineParent) and logicalParent(engineParent) or nil

    setLinkedParent(ent, IsValid(parent) and parent or nil)

    if ent.CFW_NO_FAMILY_TRAVERSAL then return end

    if IsValid(parent) then
        local oldFamily    = ent:GetFamily()
        local parentFamily = parent:GetFamily() or CFW.Classes.Family.create(parent)

        if oldFamily == parentFamily then
            -- Moving within a family still changes the parent chain of everything under ent, and family hooks are
            -- the only thing that tells listeners (ACF_ParentState) about it
            parentFamily:Sub(ent)
            parentFamily:Add(ent)
        elseif ent:GetFamily() ~= parentFamily then
            -- A new family finds its members through GetChildren, which addons can replace with one that misses bone followers
            ent:SetFamily(parentFamily)
        end
    else
        ent:SetFamily(nil)
    end
end

-- Requested parents with CFW callbacks, kept from preParent until the matching postParent
local pendingParent = {}

-- The engine's GetParent and GetChildren, set once the detours go in
local getParent, getChildren, getMoveParent

-- What an entity physically follows. SetMoveParent only changes this, GetParent keeps reporting the old parent
local function effectiveParent(ent)
    local moveParent = getMoveParent(ent)
    if IsValid(moveParent) then return moveParent end

    return getParent(ent)
end

-- Children of an engine parent, keeping the shape GetChildren gave. Addons can replace GetChildren
-- (Multi-Parent tool) with one that misses bone followers and keeps children that already moved away
local function childrenOf(target)
    local children = getChildren(target)
    local keyed    = next(children) ~= nil and isentity(next(children))
    local out, seen = {}, {}

    local function add(child)
        if seen[child] or not IsValid(child) then return end
        if effectiveParent(child) ~= target then return end

        seen[child] = true

        if keyed then out[child] = child else out[#out + 1] = child end
    end

    for k, v in pairs(children) do add(isentity(k) and k or v) end

    local tracked = target._cfwChildren

    if tracked then
        for child in pairs(tracked) do
            if IsValid(child) and effectiveParent(child) == target then add(child) else tracked[child] = nil end
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
    -- Its own proxy counts as self too
    if self == newParent or (IsValid(newParent) and toOwner(newParent) == self) then return false end

    -- Check if the parent is willing to accept this child or not
    if IsValid(savedParent) and savedParent.CFW_PreParented and savedParent:CFW_PreParented(self) == false then
        return false
    end

    -- The engine breaks a cycle by unparenting the new parent's ancestor that hangs off self, without going through Lua
    -- Children of an owner hang off its proxy. The engine would unparent the proxy from its owner there, which leaves
    -- the owner logically parented to its own descendant, so unparent the entity hanging off the proxy instead
    -- The engine checks the GetParent chain, and SetMoveParent can make what an entity follows differ from it,
    -- so both chains get checked. Capped since SetMoveParent links the move hierarchy without a cycle check
    local selfProxy = toProxy(self)

    for _, step in ipairs({ getParent, effectiveParent }) do
        local ancestor = newParent

        for _ = 1, 1024 do
            if not IsValid(ancestor) then break end

            local up = step(ancestor)

            if up == self or up == selfProxy then
                ancestor:SetParent(nil)
                break
            end

            ancestor = up
        end
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
-- CFW tracks what the engine actually did rather than what was asked
local function postParent(self, oldParent, newParent)
    local savedParent = pendingParent[self]
    pendingParent[self] = nil

    local followed = effectiveParent(self)

    if IsValid(oldParent) and oldParent._cfwChildren then oldParent._cfwChildren[self] = nil end
    if IsValid(followed) then
        followed._cfwChildren = followed._cfwChildren or {}
        followed._cfwChildren[self] = true
    end

    -- Hook for post-new-child
    if IsValid(savedParent) and savedParent.CFW_OnParented then
        savedParent:CFW_OnParented(self, true)
    end

    -- Hook for post-new-parent
    if self.CFW_OnParentedTo then
        self:CFW_OnParentedTo(oldParent, newParent)
    end

    if followed == oldParent then return end

    trackParent(self, followed)
end

hook.Add("Initialize", "CFW", function()
    timer.Simple(0, function()
        local ENT = FindMetaTable("Entity")

        getParent     = ENT.GetParent
        getChildren   = ENT.GetChildren
        getMoveParent = ENT.GetMoveParent

        -- SetParent, FollowBone and SetMoveParent all attach in the engine
        local function overrideParenting(name, needsParent)
            local engineFn = ENT[name]

            ENT[name] = function(self, newParent, newAttach, ...)
                -- SetMoveParent can't unparent, it errors on its own
                if needsParent and not IsValid(newParent) then return engineFn(self, newParent, newAttach, ...) end

                local oldParent    = effectiveParent(self)
                local engineParent = preParent(self, oldParent, newParent, newAttach, ...)

                if engineParent == false then return end

                engineFn(self, engineParent, newAttach, ...)
                postParent(self, oldParent, engineParent)
            end
        end

        overrideParenting("SetParent")
        overrideParenting("FollowBone")
        overrideParenting("SetMoveParent", true)

        -- What the entity is attached to, the same parent CFW tracks
        function ENT:GetParent()
            return logicalParent(effectiveParent(self))
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
        if not IsValid(ent) or ent:IsMarkedForDeletion() then return end

        -- Map sprites can get here before the overrides are in
        local parent = getMoveParent and effectiveParent(ent) or ent:GetParent()
        if not IsValid(parent) then return end

        trackParent(ent, parent)
    end)
end)

-- In order to prevent NULL entities flooding the ENT._links table, we'll just get rid of them before they get removed
-- This is a fix for a really annoying issue that was showing up in multiple different ways
hook.Add("EntityRemoved", "cfw.entityRemoved", function(ent)
    if not IsValid(ent) then return end

    ent.CFW_REMOVING = true
    local links = ent:GetCFWLinks()

    if not next(links) then return end

    -- Nothing stays connected to a removed entity, whatever made the connection
    for index in pairs(links) do
        disconnect(ent, index, true)
    end
end)
