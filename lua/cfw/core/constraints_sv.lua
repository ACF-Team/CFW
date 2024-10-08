local connect       = CFW.connect
local disconnect    = CFW.disconnect
local timerSimple   = timer.Simple
local stringExplode = string.Explode
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
            if IsValid(con) then
                local a, b = con.Ent1, con.Ent2 or con.Ent4

                if not IsValid(a) or a:IsWorld() then return end
                if not IsValid(b) or b:IsWorld() then return end

                con:CallOnRemove("CFW", onRemove)

                con._cfwEntA = a:EntIndex()
                con._cfwEntB = b:EntIndex()

                connect(a, b)
            end
        end)
    end
end)

-- Short-Circuits the usual CFW behavior to delete all contraptions in a dupe at once
-- Circumvents strange behavior with elastics (including hydraulics)
hook.Add("PreUndo", "cfw.undo", function(undo)
    if not undo.Entities then return end
    if stringExplode(" ", "AdvDupe2")[1] ~= "AdvDupe2"  then return end

    -- Find all entities including those not in the original dupe (wire holograms, etc.) by searching their contraptions
    -- Disable their CFW behavior and then delete the contraption
    local alreadyRemoved = {}

    for _, ent in ipairs(undo.Entities) do
        local contraption = ent:GetContraption()

        if contraption and not alreadyRemoved[contraption] then
            for ent in pairs(contraption.ents) do
                -- Disable constraint-removal behavior
                if ent.Constraints then
                    for _, con in ipairs(ent.Constraints) do
                        if IsValid(con) and isConstraint[con:GetClass()] then
                            con:RemoveCallOnRemove("CFW")
                        end
                    end
                end

                -- Disable unparenting behavior
                ent._cfwRemoved = true
            end

            -- Then remove the contraption
            alreadyRemoved[contraption] = true
            contraption:Remove()
        end
    end
end)