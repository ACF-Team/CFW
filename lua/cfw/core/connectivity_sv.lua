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
        else -- No contraption
            local newContraption = CFW.createContraption()
            
            newContraption:Add(a)
            newContraption:Add(b)
        end
    end
end

function CFW.disconnect(a, b)
    -- Decrement the link counter between two ents
    -- If the link is broken with either ent having no other connections, it's a clean break
    -- Otherwise, it needs to be determined whether or not there is an indirect chain of connections

    local link       = a._links[b]
    local cleanBreak = link:Sub()

    if cleanBreak then return end

    local indirectlyConnected, floodedEnts, floodedCount = floodFill(a, b)

    if indirectlyConnected then return end

    -- At this point the contraption has been split
    -- Create a new contraption and move the cut-off ents to it
    -- The child contraption will always be the smaller of the two

    local parentContraption, childContraption = a:GetContraption(), CFW.createContraption()

    if parentContraption.count < floodedCount then parentContraption, childContraption = childContraption, parentContraption end

    for ent in pairs(floodedEnts) do
        parentContraption:Sub(ent)
        childContraption:Add(ent)
    end

    hook.Run("cfw.contraption.split", parentContraption, childContraption)
end
