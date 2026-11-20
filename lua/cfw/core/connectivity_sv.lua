-- Floods from both ends of a removed link, one entity at a time each
-- Returns true if they meet (still connected), otherwise the indices of the side that ran out first, the smaller one
local function floodBoth(indexA, indexB)
    local side   = { [indexA] = 1, [indexB] = 2 }
    local queues = { { indexA }, { indexB } }
    local heads  = { 1, 1 }

    while true do
        for s = 1, 2 do
            local queue, head = queues[s], heads[s]

            if head > #queue then
                local out = {}
                for index, owner in pairs(side) do
                    if owner == s then out[index] = true end
                end
                return false, out
            end

            heads[s] = head + 1

            local ent   = Entity(queue[head])
            local links = IsValid(ent) and ent._links

            if links then
                for neighbor in pairs(links) do
                    local owner = side[neighbor]

                    if not owner then
                        side[neighbor] = s
                        queue[#queue + 1] = neighbor
                    elseif owner ~= s then
                        return true
                    end
                end
            end
        end
    end
end

function CFW.connect(a, b)
    -- Called when a connection is made between two entities
    -- If a link already exists, add to the link counter
    -- If not, create a new link between the two entities and resolve their contraptions

    if a == b then return end -- Should not happen normally, but ragdolls allow you to constrain to other bones on the same ragdoll, and it is the same entity. We'll head it off here since we don't want to track links that don't actually link anything

    local link = a:GetCFWLink(b)

    if link then
        link:Add()
    else -- No existing connection
        -- Create a new link
        CFW.createLink(a, b)

        -- Resolve contraption states
        local ac, bc = a:CFW_GetContraption(), b:CFW_GetContraption()

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

-- all drops the whole link instead of one connection
function CFW.disconnect(entA, indexB, all)
    if entA:EntIndex() == indexB then return end -- Should not happen normally, but ragdolls allow you to constrain to other bones on the same ragdoll, and it is the same entity

    -- Don't soft error because if _links isn't present then it's a deeper CFW issue, nothing without a _links table should be able to reach this point at all
    local links = entA._links
    if not links then
        ErrorNoHaltWithStack("Contraption Framework Error: Entity had no links. This error generally indicates a deeper problem with CFW.")
        return
    end

    local link = links[indexB]

    if not link then return end -- There's nothing to disconnect here

    local contraptionPopped

    if all then
        contraptionPopped = link:Remove()
    else
        contraptionPopped = link:Sub()
    end

    if contraptionPopped then return end

    local indirectlyConnected, smallerSide = floodBoth(entA:EntIndex(), indexB)

    if indirectlyConnected then return end

    -- At this point the contraption has been split
    -- The smaller side moves to a new contraption, so a vehicle losing a part keeps its contraption
    local parentContraption, childContraption = entA:CFW_GetContraption(), CFW.createContraption()

    for entIndex in pairs(smallerSide) do
        local ent = Entity(entIndex)

        parentContraption:Sub(ent)
        childContraption:Add(ent)
    end

    hook.Run("cfw.contraption.split", parentContraption, childContraption)
end
