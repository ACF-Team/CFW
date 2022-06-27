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

local function onRemove(constraint)
    if not IsValid(constraint.Ent1) then
        -- TODO: PLEASE FIX THIS
        -- Wire Hydraulics break during Undos for... some reason
        -- The constraint.Ent1 on the hydraulic/phys_spring is NULL
        ErrorNoHalt("Error: Wire Hydraulic Bug!\n", constraint,  constraint.Ent1, constraint.Ent2)
        debug.Trace()

        -- Dumbass workaround to clean this up
        for otherEnt, link in pairs(constraint.Ent2:GetLinks()) do
            if not IsValid(otherEnt) then
                link.count = link.count - 1

                if link.count == 0 then
                    local a, b = link.a, link.b

                    CFW.links[link] = nil

                    if IsValid(a) then
                        a._links[b] = nil
                        a._links    = nil

                        local c = a:GetContraption()
                        
                        c:Sub(a)
                        c[b] = nil

                        c.count = c.count - 1

                        if c.count <= 1 then c:Remove() end
                    end

                    if IsValid(b) then
                        b._links[a] = nil
                        b._links    = nil

                        local c = b:GetContraption()
                        
                        c:Sub(b)
                        c[a] = nil

                        c.count = c.count - 1

                        if c.count <= 1 then c:Remove() end
                    end
                end
            end
        end

        return
    end

    disconnect(constraint.Ent1, constraint.Ent2 or constraint.Ent4)
end

-- This is a dumb hack necessitated by SetTable being called on constraints immediately after they are created
-- https://github.com/Facepunch/garrysmod/blob/master/garrysmod/lua/includes/modules/constraint.lua#L449
-- Any data stored in the same tick the constraint is created will be removed. Thus, we delay for one tick
-- This also conveniently prevents CFW from responding to constraints created and removed in the same tick
hook.Add("OnEntityCreated", "CFW", function(constraint)
    if isConstraint[constraint:GetClass()] then
        timerSimple(0, function()
            if IsValid(constraint)then
                local a, b = constraint.Ent1, constraint.Ent2 or constraint.Ent4
                
                if not IsValid(a) or a:IsWorld() then return end
                if not IsValid(b) or b:IsWorld() then return end

                constraint:CallOnRemove("CFW", onRemove)

                connect(a, b)
            end
        end)
    end
end)