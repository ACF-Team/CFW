-- The stock duplicator copies an entity's whole Lua table for classes it has no factory for, CFW's own state included.
-- A pasted copy would then share the original's links, contraption and family
local private = { "_links", "_contraption", "_family", "_cfwChildren", "_cfwLinkedParent", "_mass", "CFW_REMOVING" }

local function strip(tab)
    for _, key in ipairs(private) do
        tab[key] = nil
    end
end

local function wrap()
    if duplicator.CFW_Wrapped then return end
    duplicator.CFW_Wrapped = true

    local copyEntTable = duplicator.CopyEntTable

    function duplicator.CopyEntTable(ent)
        local out = copyEntTable(ent)
        if istable(out) then strip(out) end

        return out
    end

    -- Dupes saved before this still carry it
    local createEntityFromTable = duplicator.CreateEntityFromTable

    function duplicator.CreateEntityFromTable(ply, data)
        if istable(data) then strip(data) end

        return createEntityFromTable(ply, data)
    end
end

if duplicator then
    wrap()
else
    hook.Add("Initialize", "cfw.duplicator", wrap)
end
