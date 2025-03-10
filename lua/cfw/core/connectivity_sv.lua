local function floodFill(source, sinkIndex)
    local closed       = {[source:EntIndex()] = true}
    local closedCount  = 0
    local open         = source:GetLinks()

    while next(open) do
        local entIndex = next(open) -- entIndex, entLink

        open[entIndex]   = nil
        closed[entIndex] = true

        closedCount = closedCount + 1

        if entIndex == sinkIndex then return true, closed end

        for neighborIndex in pairs(Entity(entIndex)._links) do -- neighborIndex, neighborLink
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

    if a == b then return end -- Should not happen normally, but ragdolls allow you to constrain to other bones on the same ragdoll, and it is the same entity. We'll head it off here since we don't want to track links that don't actually link anything

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
    if entA:EntIndex() == indexB then return end -- Should not happen normally, but ragdolls allow you to constrain to other bones on the same ragdoll, and it is the same entity

    -- Don't soft error because if _links isn't present then it's a deeper CFW issue, nothing without a _links table should be able to reach this point at all
    local links = entA._links
    if not links then ErrorNoHaltWithStack("Contraption Framework Error: Entity had no links. This error generally indicates a deeper problem with CFW.") end

    local link = links[indexB]

    if not link then return end -- There's nothing to disconnect here

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
