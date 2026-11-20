local connect       = CFW.connect
local disconnect    = CFW.disconnect
local timerSimple   = timer.Simple
local isConstraint  = {
    phys_hinge = true, -- axis
    phys_lengthconstraint = true, -- rope
    phys_constraint = true, -- weld
    phys_ballsocket = true, -- ballsocket
    phys_spring = true, -- elastic, hydraulics, muscles
    phys_pulleyconstraint = true, -- pulley (do people ever use these?)
    phys_slideconstraint = true, -- sliders
    phys_ragdollconstraint = true, -- adv. ballsocket
}

local function onRemove(con)
    local a, b = con.Ent1, con.Ent2 or con.Ent4

    if IsValid(a) then disconnect(a, con._cfwEntB) else disconnect(b, con._cfwEntA) end
end

-- This is a dumb hack necessitated by SetTable being called on constraints immediately after they are created
-- https://github.com/Facepunch/garrysmod/blob/master/garrysmod/lua/includes/modules/constraint.lua#L449
-- Any data stored in the same tick the constraint is created will be removed. Thus, we delay for one tick
-- This also conveniently prevents CFW from responding to constraints created and removed in the same tick
hook.Add("OnEntityCreated", "cfw.entityCreated", function(con)
    if isConstraint[con:GetClass()] then
        timerSimple(0, function()
            -- Removed entities stay valid until the end of the tick
            if IsValid(con) and not con:IsMarkedForDeletion() then
                local a, b = con.Ent1, con.Ent2 or con.Ent4

                if not IsValid(a) or a:IsWorld() or a:IsMarkedForDeletion() then return end
                if not IsValid(b) or b:IsWorld() or b:IsMarkedForDeletion() then return end

                con:CallOnRemove("CFW", onRemove)

                con._cfwEntA = a:EntIndex()
                con._cfwEntB = b:EntIndex()

                connect(a, b)
            end
        end)
    end
end)