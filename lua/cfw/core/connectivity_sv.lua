local function floodFill(source, sink)
    local closed       = {[source] = true}
    local closedCount  = 0
    local open         = source._links

    while next(open) do
        local node = next(open)

        open[node]   = nil
        closed[node] = true

        closedCount = closedCount + 1

        if node == sink then return true, closed end

        for ent in pairs(node._links) do
            if not closed[ent] then
                open[ent] = true
            end
        end
    end

    return false, closed, closedCount
end

function CFW.connect(a, b)
    -- Called when a connection is made between two entities
    -- If a link already exists, add to the link counter
    -- If not, create a new link between the two entities and resolve their contraptions

    local link = a._links[b]

    if link then
        link:Add()
    else -- No existing connection
        -- Create a new link
        CFW.createLink(a, b)

        -- Resolve contraption states
        local ac, bc = a:GetContraption(), b:GetContraption()

        if ac and bc then
            if ac ~= bc then -- Two DIFFERENT contraptions
                if ac.count > bc.count then
                    ac:Merge(bc)
                else
                    bc:Merge(ac)
                end
            end
        elseif ac then -- Only contraption A
            ac:Add(b)
        elseif bc then -- Only contraption B
            bc:Add(a)
        else -- No contraption ( CREATE )
            local newContraption = CFW.createContraption()
            
            newContraption:Add(a)
            newContraption:Add(b)
        end
    end
end

function CFW.disconnect(a, b)
    local link       = a:GetLink(b)
    local cleanBreak = link:Sub()

    if cleanBreak then return end

    local directlyConnected, floodedEnts, floodedCount = floodFill(a, b)

    if directlyConnected then return end

    local parentContraption, childContraption = a:GetContraption(), CFW.createContraption()

    -- We want to move the least amount of things around, swap the order if necessary
    if parentContraption.count < floodedCount then parentContraption, childContraption = childContraption, parentContraption end

    for ent in pairs(floodedEnts) do
        parentContraption:Sub(ent)
        childContraption:Add(ent)
    end

    hook.Run("cfw.contraption.split", parentContraption, childContraption)
end
