local PHYS        = FindMetaTable("PhysObj")
local getPhysics  = FindMetaTable("Entity").GetPhysicsObject
local IsValidPhys = PHYS.IsValid

local MASS_EPSILON = 0.05

local function entMass(ent)
    if not IsValid(ent) then return 0 end

    local phys = getPhysics(ent)

    if not IsValidPhys(phys) then return 0 end

    return phys:GetMass()
end

local isConstraint = CFW.isConstraint

-- Returns the parent entity recorded in the link graph for ent: the entB of ent's parent
-- link (parent links are stored entA = child, entB = parent). nil if ent has no parent link
local function linkParent(ent)
    local links = ent._links

    if not links then return nil end

    for other, link in pairs(links) do
        if link.isParent and link.entA == ent then return other end
    end

    return nil
end

-- Whether a constraint is a class CFW tracks at all, ignoring its endpoints.
-- Mirrors the filtering in constraints_sv.lua: only specific classes count and rotation-only
-- advanced ballsockets are ignored.
local function isTrackedConstraintClass(c)
    return IsValid(c) and isConstraint[c:GetClass()] ~= nil and not (c.onlyrotation and c.onlyrotation ~= 0)
end

-- Whether a constraint entity is one CFW would actually track as a link between a and b.
-- Adds the endpoint requirements on top of the class check: it must join a and b (in either
-- order) and never an entity to itself.
local function isTrackedConstraint(c, a, b)
    if not isTrackedConstraintClass(c) then return false end

    local e1, e2 = c.Ent1, c.Ent2

    if e1 == e2 then return false end

    return (e1 == a and e2 == b) or (e1 == b and e2 == a)
end

-- Number of real, CFW-trackable constraints currently between a and b
-- gmod records each constraint on both endpoints Constraints table, so a's is enough
local function realConstraintCount(a, b)
    local cons = a.Constraints

    if not cons then return 0 end

    local n = 0

    for _, c in pairs(cons) do
        if isTrackedConstraint(c, a, b) then n = n + 1 end
    end

    return n
end

-- The running list of problems for the contraption currently being verified
-- Reset at the start of every VerifyContraption call
local issues = {}

local function add(fmt, ...)
    local n    = select("#", ...)
    local args = { ... }

    for i = 1, n do
        local v = args[i]

        if type(v) ~= "number" then args[i] = tostring(v) end
    end

    issues[#issues + 1] = string.format(fmt, unpack(args, 1, n))
end

-- MARK: Members
-- count, entity validity, and the _contraption reference
local function checkMembers(con)
    local ents      = con.ents
    local realCount = 0

    for ent in pairs(ents) do
        realCount = realCount + 1

        if not IsValid(ent) then
            add("NULL entity present in con.ents")
        elseif ent._contraption ~= con then
            add("ent %s is in con.ents but _contraption points elsewhere", ent)
        end
    end

    if con.count ~= realCount then
        add("con.count=%s but con.ents holds %d entities", con.count, realCount)
    end
end

-- MARK: Entsbyclass
local function checkEntsByClass(con)
    local ents = con.ents
    local seen = {}

    for cls, set in pairs(con.entsbyclass) do
        if not next(set) then add("entsbyclass[%s] is an empty table", cls) end

        for ent in pairs(set) do
            seen[ent] = true

            if not ents[ent] then
                add("ent %s in entsbyclass[%s] but not in con.ents", ent, cls)
            elseif IsValid(ent) and ent:GetClass() ~= cls then
                add("ent %s filed under class %s but is actually %s", ent, cls, ent:GetClass())
            end
        end
    end

    for ent in pairs(ents) do
        if IsValid(ent) and not seen[ent] then
            add("ent %s in con.ents but missing from entsbyclass", ent)
        end
    end
end

-- MARK: Physical status
-- An entity is either "physical" (an unparented root) or "parented". Four independently
-- maintained views must agree on this: con.physical, the link graph, the family structure, and the engine's actual ent:GetParent()
-- Also nothing may be in con.physical without being in con.ents
local function checkPhysicalStatus(con)
    local ents     = con.ents
    local physical = con.physical

    for ent in pairs(ents) do
        if IsValid(ent) then
            local graphParent = linkParent(ent) -- Does LINK say it's parented?
            local isRoot      = graphParent == nil

            -- Does con.physical agree on whether it's parented?
            if (physical[ent] ~= nil) ~= isRoot then
                add("ent %s: con.physical=%s but link graph says root=%s (must match)", ent, physical[ent] ~= nil, isRoot)
            end

            -- Family structure must agree: an entity is a root if it has no family
            -- OR it is its own family's ancestor and that family is itself a root family (typical case)
            local fam         = ent._family
            local famSaysRoot = not fam or (fam.ancestor == ent and fam.parentFamily == nil)

            if famSaysRoot ~= isRoot then
                add("ent %s: family structure implies root=%s but link graph says root=%s", ent, famSaysRoot, isRoot)
            end

            -- The link graph must agree with reality
            local realParent = ent:GetParent()

            if isRoot then
                -- A root cannot be parented to another entity in the contraption
                if IsValid(realParent) and ents[realParent] then
                    add("ent %s: treated as a root but ent:GetParent()=%s is a contraption member", ent, realParent)
                end
            elseif graphParent ~= realParent then
                -- Covers both a wrong parent and a stale link
                add("ent %s: parent link points to %s but ent:GetParent()=%s", ent, graphParent, realParent)
            end
        end
    end

    for ent in pairs(physical) do
        if not ents[ent] then
            add("ent %s in con.physical but not in con.ents", ent)
        end
    end
end

-- MARK: Contraption mass
local function checkContraptionMass(con)
    if con.totalMass == nil then return end

    local ents     = con.ents
    local physical = con.physical

    local total, phys, parented = 0, 0, 0

    for ent in pairs(ents) do
        local m = entMass(ent)

        total = total + m

        if physical[ent] then phys = phys + m else parented = parented + m end
    end

    -- Total mass
    if math.abs(total - con.totalMass) > MASS_EPSILON then
        add("con.totalMass=%.3f but actual sum=%.3f", con.totalMass, total)
    end

    -- Physical mass
    if math.abs(phys - con.physicalMass) > MASS_EPSILON then
        add("con.physicalMass=%.3f but physical sum=%.3f", con.physicalMass, phys)
    end

    -- Parented mass
    if math.abs(parented - con.parentedMass) > MASS_EPSILON then
        add("con.parentedMass=%.3f but parented sum=%.3f", con.parentedMass, parented)
    end

    -- Does the parented and physical mass add up to the total?
    if math.abs((con.physicalMass + con.parentedMass) - con.totalMass) > MASS_EPSILON then
        add("physicalMass+parentedMass=%.3f != totalMass=%.3f", con.physicalMass + con.parentedMass, con.totalMass)
    end
end

-- MARK: Families
local function checkFamilyMembers(con, fam, famOf)
    local ents = con.ents
    local fc   = 0

    for ent in pairs(fam.ents) do
        fc = fc + 1
        famOf[ent] = fam

        if ent._family ~= fam then
            add("ent %s in family.ents but its _family reference difers", ent)
        end

        if not ents[ent] then
            add("ent %s in family(anc=%s).ents but not in con.ents", ent, fam.ancestor)
        end

        if ent == fam.ancestor then
            if fam.children[ent] then
                add("ancestor %s wrongly listed in family.children", ent)
            end
        elseif not fam.children[ent] then
            add("child %s missing from family.children", ent)
        end
    end

    if fam.count ~= fc then
        add("family(anc=%s).count=%s but holds %d ents", fam.ancestor, fam.count, fc)
    end

    if fam.ancestor and not fam.ents[fam.ancestor] then
        add("family ancestor %s not present in its own ents", fam.ancestor)
    end
end


local function checkFamilyMass(con, fam)
    if fam.totalMass == nil then return end

    local physical = con.physical
    local total    = 0

    for ent in pairs(fam.ents) do total = total + entMass(ent) end

    -- Total mass
    if math.abs(total - fam.totalMass) > MASS_EPSILON then
        add("family(anc=%s).totalMass=%.3f but physics sum=%.3f", fam.ancestor, fam.totalMass, total)
    end

    -- Physical mass
    local expectPhys = (physical[fam.ancestor] and entMass(fam.ancestor)) or 0

    if math.abs(expectPhys - fam.physicalMass) > MASS_EPSILON then
        add("family(anc=%s).physicalMass=%.3f but ancestor-physical implies %.3f",
            fam.ancestor, fam.physicalMass, expectPhys)
    end

    -- Do they all add up?
    if math.abs((fam.physicalMass + fam.parentedMass) - fam.totalMass) > MASS_EPSILON then
        add("family(anc=%s) physicalMass+parentedMass=%.3f != totalMass=%.3f",
            fam.ancestor, fam.physicalMass + fam.parentedMass, fam.totalMass)
    end
end


local function checkFamilyHierarchy(con, fam)
    for sub in pairs(fam.subFamilies) do
        -- Does this subFamily believe this family is its parent?
        if sub.parentFamily ~= fam then
            add("subFamily(anc=%s).parentFamily does not point back to family(anc=%s)", sub.ancestor, fam.ancestor)
        end

        -- Is the subfamily in the family table?
        if not con.families[sub] then
            add("subFamily(anc=%s) is not registered in con.families", sub.ancestor)
        end
    end

    -- Is this family in it's parent's subFamily table?
    if fam.parentFamily and not fam.parentFamily.subFamilies[fam] then
        add("family(anc=%s) has a parentFamily but is absent from its subFamilies", fam.ancestor)
    end
end

local function checkFamilies(con)
    local ents  = con.ents
    local famOf = {}

    for fam in pairs(con.families) do
        if fam.contraption ~= con then
            add("family(anc=%s).contraption does not point back to this contraption", fam.ancestor)
        end

        checkFamilyMembers(con, fam, famOf)
        checkFamilyMass(con, fam)
        checkFamilyHierarchy(con, fam)
    end

    for ent in pairs(ents) do
        local fam = ent._family

        if fam and famOf[ent] ~= fam then
            add("ent %s._family is not the con.families entry that contains it", ent)
        end
    end
end

-- MARK: Links
-- the link table is symmetric and parent links reference their own endpoints
local function checkLinks(con)
    local ents = con.ents

    for ent in pairs(ents) do
        if not IsValid(ent) then continue end

        for other, link in pairs(ent._links) do
            if not (other._links and other._links[ent] == link) then
                add("asymmetric link: %s -> %s not mirrored", ent, other)
            end

            if link.isParent and link.entA ~= ent and link.entB ~= ent then
                add("link on %s does not reference it as entA or entB", ent)
            end
        end
    end
end

-- MARK: Constraint reality
-- checkLinks only proves the link table is internally symmetric. This compares the constraint
-- links against the actual constraints in the world: every constraint link must be backed by
-- the right number of real constraints (link.count tracks how many), and every real constraint
-- between two members must have a constraint link.
local function checkConstraintReality(con)
    local ents = con.ents

    -- Every constraint link must have matching real constraints
    -- Visit each link once, from its entA side
    for ent in pairs(ents) do
        if not IsValid(ent) then continue end

        for other, link in pairs(ent._links) do
            if link.isParent then continue end

            if ent == link.entA and IsValid(other) then
                local real = realConstraintCount(ent, other)

                if real == 0 then
                    add("constraint link %s <-> %s (count=%d) has no real constraint backing it", ent, other, link.count)
                elseif real ~= link.count then
                    add("constraint link %s <-> %s: count=%d but %d real constraints exist", ent, other, link.count, real)
                end
            end
        end
    end

    -- Every real constraint between two members must have a (non-parent) link
    -- Visit each constraint once using EntIndex ordering to avoid duplicate reports
    for ent in pairs(ents) do
        if not IsValid(ent) then continue end
        if not ent.Constraints then continue end

        for _, c in pairs(ent.Constraints) do
            if isTrackedConstraintClass(c) then
                local e1, e2 = c.Ent1, c.Ent2
                local other

                if e1 == ent then other = e2 elseif e2 == ent then other = e1 end

                if IsValid(other) and other ~= ent and ents[other] and ent:EntIndex() < other:EntIndex() then
                    local link = ent._links and ent._links[other]

                    if not link then
                        add("real constraint %s <-> %s exists but there is no link between them",
                            ent, other)
                    elseif link.isParent then
                        add("real constraint %s <-> %s exists but their link is marked isParent",
                            ent, other)
                    end
                end
            end
        end
    end
end

-- MARK: Connectivity
-- the contraption is a single connected component over its link graph (constraint + parent edges), and no link crosses out of the contraption
local function checkConnectivity(con)
    local ents = con.ents

    local start

    -- Pick the first valid entity we find
    for ent in pairs(ents) do if IsValid(ent) then start = ent break end end

    if not start then return end

    local closed  = { [start] = true }
    local open    = { start }

    -- Flood through the contraption
    while #open > 0 do
        local ent = open[#open]

        open[#open] = nil

        for other in pairs(ent._links) do
            if closed[other] then continue end

            closed[other] = true

            if not ents[other] then
                add("link from %s reaches %s which is NOT in this contraption", ent, other)
            else
                open[#open + 1] = other
            end
        end
    end

    for ent in pairs(ents) do
        if IsValid(ent) and not closed[ent] then
            add("ent %s is in con.ents but unreachable via links (disconnected island)", ent)
        end
    end
end


function CFW.VerifyContraption(con)
    if type(con) ~= "table" then return false, { "object is not a contraption" } end

    issues = {}

    if not CFW.Contraptions[con] then
        add("contraption is not registered in CFW.Contraptions")
    end

    checkMembers(con)
    checkEntsByClass(con)
    checkPhysicalStatus(con)
    checkContraptionMass(con)
    checkFamilies(con)
    checkLinks(con)
    checkConstraintReality(con)
    checkConnectivity(con)

    return #issues == 0, issues
end
