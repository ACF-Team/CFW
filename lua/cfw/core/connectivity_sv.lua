function CFW.connect(a, b, isParent)
    -- Called when a connection is made between two entities
    -- If a link already exists, add to the link counter
    -- If not, create a new link between the two entities and resolve their contraption states

    -- Resolve which contraption will own this pair
    local ac, bc = a._contraption, b._contraption
    local contraption

    if ac and bc then
        if ac ~= bc then -- Two different contraptions
            contraption = ac:Merge(bc)
        else             -- The same contraption, we'll just use ac
            contraption = ac
        end
    elseif ac then       -- Entity A is part of a contraption
        contraption = ac
    elseif bc then       -- Entity B is part of a contraption
        contraption = bc
    else                 -- Neither entity was connected to anyhing before this
        contraption = CFW.createContraption()
        hook.Run("cfw.contraption.init", contraption)
    end

    -- Now that we've figured out which contraption we're using, add the entities to it
    if isParent then
        contraption:AddParentedPair(a, b)
    else
        contraption:AddConstrainedPair(a, b)
    end
end

function CFW.disconnect(entA, entB)
    local link = entA._links and entA._links[entB]
    if link then link:Sub() end
end

-- TODO: Dupes are ingesting and saving CFW contraption data, bloating file size significantly.
-- This doesn't need to be saved at all, CFW builds this data when the constraints are made