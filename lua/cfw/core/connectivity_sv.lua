
local function floodFill(source, sink)
    local closed = {[source] = true}
    local open   = source:GetLinks()

    while next(open) do
        local node = next(open)

        open[node]   = nil
        closed[node] = true

        if node == sink then return true, closed end

        for ent in pairs(node:GetLinks()) do
            if not closed[ent] then
                open[ent] = true
            end
        end
    end

    return false, closed
end

function CFW.connect(a, b)
    -- Called when a connection is made between two entities
    -- If a link already exists, add to the link counter
    -- If not, create a new link between the two entities and resolve their contraptions

    local link = a:GetLink(b)

    if link then
        link:Add()
    else -- No existing connection
        -- Create a new link
        CFW.createLink(a, b)

        -- Resolve contraption states
        local ac, bc = a:GetContraption(), b:GetContraption()

        if ac and bc then
            if ac ~= bc then -- Two DIFFERENT contraptions ( MERGE ) 
                if ac.count > bc.count then
                    ac:Merge(bc)
                else
                    bc:Merge(ac)
                end
            end
        elseif ac then -- Only contraption A ( ADD )
            ac:Add(b)
        elseif bc then -- Only contraption B ( ADD )
            bc:Add(a)
        else -- No contraption ( CREATE )
            CFW.createContraption(a, b)
        end
    end
end

function CFW.disconnect(a, b)
    print(a, b)
    -- Called when a connection is removed between two entities (constraint, parent, etc.)
    -- Reduce the link counter on their shared link

    if a:GetLink(b):Sub() then
        -- LINK:Sub returns TRUE on a dirty break
        -- If dirty break, check for indirect connections
    
        local connected, list = floodFill(a, b)

        if not connected then
            -- The ents are not connected anymore meaning there are now two separate contraptions
            -- TODO: Make this move the LEAST amount of ents possible

            -- Remove the collected ents from their current contraption
            local oldCon = a:GetContraption()

            for ent in pairs(list) do
                oldCon:Sub(ent)
            end

            -- Add them back to a new contraption
            CFW.createContraption(list)
        end
    end
end
