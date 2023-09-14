local function floodFill(source, sinkIndex)
    local closed       = {[source:EntIndex()] = true}
    local closedCount  = 0
    local open         = source:GetLinks()

    while next(open) do
        local entIndex, entLink = next(open)

        open[entIndex]   = nil
        closed[entIndex] = true

        closedCount = closedCount + 1

        if entIndex == sinkIndex then return true, closed end

        for neighborIndex, neighborLink in pairs(Entity(entIndex)._links) do
            if not closed[neighborIndex] then
                open[neighborIndex] = true
            end
        end
    end

    return false, closed, closedCount
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

function CFW.disconnect(entA, indexB)
    local link = entA._links[indexB]

    if not link then return end

    local contraptionPopped = link:Sub()

    if contraptionPopped then return end

    local indirectlyConnected, floodedIndecii, floodedCount = floodFill(entA, indexB)

    if indirectlyConnected then return end

    -- At this point the contraption has been split
    -- Create a new contraption and move the cut-off ents to it
    -- The child contraption will always be the smaller of the two

    local parentContraption, childContraption = entA:GetContraption(), CFW.createContraption()

    if parentContraption.count < floodedCount then parentContraption, childContraption = childContraption, parentContraption end

    for entIndex in pairs(floodedIndecii) do
        local ent = Entity(entIndex)

        parentContraption:Sub(ent)
        childContraption:Add(ent)
    end

    hook.Run("cfw.contraption.split", parentContraption, childContraption)
end
