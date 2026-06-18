local connect     = CFW.connect
local disconnect  = CFW.disconnect
local timerSimple = timer.Simple

-- Constraint types tracked by CFW
-- Note: Some types (weld, ballsocket, adv. ballsocket) are deduplicated by GMod's
-- constraint library before entity creation - duplicates simply won't fire OnEntityCreated
-- Elastics have a race condition when removed where one of the two entities may be removed before the hook fires
-- TODO: Figure out a way to handle elastics. Until then, they have to be ignored or we get stale entries
CFW.isConstraint = {
    phys_hinge = true, -- axis
    phys_lengthconstraint = true, -- rope
    phys_constraint = true, -- weld
    phys_ballsocket = true, -- ballsocket
    -- phys_spring = true, -- elastic, hydraulics, muscles -- INTENTIONALLY IGNORED. Introduces race conditions that cannot be handled (yet?)
    phys_slideconstraint = true, -- sliders
    phys_ragdollconstraint = true, -- adv. ballsocket
}

local isConstraint = CFW.isConstraint

local function onRemove(con)
    disconnect(con.Ent1, con.Ent2)
end

-- This is a dumb hack necessitated by SetTable being called on constraints immediately after they are created
-- https://github.com/Facepunch/garrysmod/blob/master/garrysmod/lua/includes/modules/constraint.lua#L449
-- Any data stored in the same tick the constraint is created will be removed. Thus, we delay for one tick
-- This also conveniently prevents CFW from responding to constraints created and removed in the same tick
hook.Add("OnEntityCreated", "cfw.entityCreated", function(con)
    if isConstraint[con:GetClass()] then
        timerSimple(0, function()
            if not IsValid(con) then return end

            -- Rotation-only advanced ballsockets (phys_ragdollconstraint with onlyrotation=1)
            -- don't constrain position, so we ignore them entirely
            -- This mostly applies to setAng steering plates
            if con.onlyrotation and con.onlyrotation ~= 0 then return end

            local a, b = con.Ent1, con.Ent2

            if not IsValid(a) or not IsValid(b) then return end

            -- Ignore map stuff
            if a:IsWorld() or a:CreatedByMap() then return end
            if b:IsWorld() or b:CreatedByMap() then return end

            -- Prevent ragdolls from constraining to themselves
            if a == b then return end

            -- Constraints and parenting are mutually exclusive
            -- Severing a third-party parent matters: given child -> parent -> grandparent
            -- adding constraint child <-> parent, the parent must lose its link to the grandparent (which splits the contraption)
            if IsValid(a:GetParent()) then a:SetParent(nil) end
            if IsValid(b:GetParent()) then b:SetParent(nil) end

            con:CallOnRemove("CFW", onRemove)

            connect(a, b)
        end)
    end
end)