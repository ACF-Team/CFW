-- Duplicators copy an entity's whole Lua table, CFW's own state included:
-- the stock one for classes it has no factory for, AdvDupe2 for every class registered with a "Data" argument
-- (prop_physics too). Copies get bigger and a pasted entity can end up with the original's links, contraption and family
local private = { "_links", "_contraption", "_family", "_cfwChildren", "_cfwLinkedParent", "_mass", "CFW_REMOVING" }

local function strip(tab)
    if not istable(tab) then return end

    for _, key in ipairs(private) do
        tab[key] = nil
    end
end

local function stripAll(entities)
    if not istable(entities) then return end

    for _, data in pairs(entities) do
        strip(data)
    end
end

local function wrapStock()
    if not duplicator or duplicator.CFW_Wrapped then return end
    duplicator.CFW_Wrapped = true

    local copyEntTable = duplicator.CopyEntTable

    function duplicator.CopyEntTable(ent)
        local out = copyEntTable(ent)
        strip(out)

        return out
    end

    -- Dupes saved before this still carry it
    local createEntityFromTable = duplicator.CreateEntityFromTable

    function duplicator.CreateEntityFromTable(ply, data)
        strip(data)

        return createEntityFromTable(ply, data)
    end
end

local function wrapAdvDupe2()
    local AD2 = AdvDupe2 and AdvDupe2.duplicator
    if not AD2 or AD2.CFW_Wrapped then return end
    AD2.CFW_Wrapped = true

    -- The tool, the area copy and autosaves all go through these
    for _, name in ipairs({ "Copy", "AreaCopy" }) do
        local copy = AD2[name]

        if isfunction(copy) then
            AD2[name] = function(...)
                local entities, constraints = copy(...)
                stripAll(entities)

                return entities, constraints
            end
        end
    end
end

-- Dupes saved before this still carry it
hook.Add("AdvDupe2_PreCreateEntity", "cfw.duplicator", strip)

wrapStock()
wrapAdvDupe2()

-- Either can load after CFW
hook.Add("Initialize", "cfw.duplicator", function()
    wrapStock()
    wrapAdvDupe2()
end)
