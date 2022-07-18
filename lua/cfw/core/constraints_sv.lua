local connect      = CFW.connect
local disconnect   = CFW.disconnect
local timerSimple  = timer.Simple
local isConstraint = {
    phys_hinge = true, -- axis
    phys_lengthconstraint = true, -- rope
    phys_constraint = true, -- weld
    phys_ballsocket = true, -- ballsocket
    phys_spring = true, -- elastic, hydraulics, muscles
    phys_pulleyconstraint = true, -- pulley (do people ever use these?)
    phys_slideconstraint = true, -- sliders
}

local function onRemove(con)
    local a, b = con.Ent1, con.Ent2 or con.Ent4

    if not IsValid(a) or not IsValid(b) then
        -- This shouldn't have happened
        -- Error and destroy the contraption
        ErrorNoHaltWithStack()
        print("Constraint Type: " .. con.Type)
        print("Ent1", con.Ent1)
        print("Ent2", con.Ent2)
        
        local contraption = (IsValid(a) and a or IsValid(b) and b):GetContraption()

        contraption:Defuse()

        return
    end

    disconnect(a, b)
end

-- This is a dumb hack necessitated by SetTable being called on constraints immediately after they are created
-- https://github.com/Facepunch/garrysmod/blob/master/garrysmod/lua/includes/modules/constraint.lua#L449
-- Any data stored in the same tick the constraint is created will be removed. Thus, we delay for one tick
-- This also conveniently prevents CFW from responding to constraints created and removed in the same tick
hook.Add("OnEntityCreated", "cfw.entityCreated", function(con)
    if isConstraint[con:GetClass()] then
        timerSimple(0, function()
            if IsValid(con)then
                local a, b = con.Ent1, con.Ent2 or con.Ent4
                
                if not IsValid(a) or a:IsWorld() then return end
                if not IsValid(b) or b:IsWorld() then return end

                con:CallOnRemove("CFW", onRemove)

                connect(a, b)
            end
        end)
    end
end)

-- Elastics and Hydraulics break during undos for some reason. This is a workaround.
-- Since all of the entities are being removed, we don't care about the individual disconnections
-- Just remove the contraption.
hook.Add("PreUndo", "cfw.undo", function(undo)
    if string.Explode(" ", "AdvDupe2")[1] == "AdvDupe2"  then
        local alreadyRemoved = {}

        for _, ent in ipairs(undo.Entities) do
            local contraption = ent:GetContraption()

            if contraption then
                -- Remove callbacks from constraints
                if ent.Constraints then
                    for _, con in ipairs(ent.Constraints) do
                        if IsValid(con) and isConstraint[con:GetClass()] then
                            con:RemoveCallOnRemove("CFW")
                        end
                    end
                end

                if not alreadyRemoved[contraption] then
                    -- Mark all entities, including those not in the dupe, as already removed
                    -- This takes care of holograms and such
                    for ent in pairs(contraption.ents) do
                        ent._cfwRemoved = true
                    end

                    -- Then remove the contraption
                    alreadyRemoved[contraption] = true
                    contraption:Remove()
                end
            end
        end
    end
end)