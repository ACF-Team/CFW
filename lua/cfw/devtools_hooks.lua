local function ContraptionName(Contraption) return "Contraption: " .. tostring(Contraption):sub(8) end
local function FamilyName(Family)            return "Family: "      .. tostring(Family):sub(8) end

local Events = {
    ["cfw.contraption.init"]          = function(con)         return ContraptionName(con), "CFW.Contraption.Init" end,
    ["cfw.contraption.entityAdded"]   = function(con, ent)    return ContraptionName(con), "CFW.Contraption.EntityAdded", ent end,
    ["cfw.contraption.entityRemoved"] = function(con, ent)    return ContraptionName(con), "CFW.Contraption.EntityRemoved", ent end,
    ["cfw.contraption.merged"]        = function(from, into)  return ContraptionName(from), "CFW.Contraption.Merged", ContraptionName(into) end,
    ["cfw.contraption.split"]         = function(old, new)    return ContraptionName(old), "CFW.Contraption.Split", ContraptionName(new) end,
    ["cfw.contraption.removed"]       = function(con)         return ContraptionName(con), "CFW.Contraption.Removed" end,

    ["cfw.family.init"]               = function(fam)         return FamilyName(fam), "CFW.Family.Init" end,
    ["cfw.family.added"]              = function(fam, ent)    return FamilyName(fam), "CFW.Family.EntityAdded", ent end,
    ["cfw.family.subbed"]             = function(fam, ent)    return FamilyName(fam), "CFW.Family.EntityRemoved", ent end,
    ["cfw.family.removed"]            = function(fam)         return FamilyName(fam), "CFW.Family.Removed" end,
    -- merged/split fire on the surviving / original family; the other family goes away
    ["cfw.family.merged"]             = function(fam, old)    return FamilyName(old), "CFW.Family.Merged", FamilyName(fam) end,
    ["cfw.family.split"]              = function(old, new, ancestor) return FamilyName(old), "CFW.Family.Split", FamilyName(new), ancestor end,
    ["cfw.family.ancestorRemoved"]    = function(fam, old, new)      return FamilyName(fam), "CFW.Family.AncestorRemoved", old, new end,
    ["cfw.family.ancestorInserted"]   = function(fam, old, new)      return FamilyName(fam), "CFW.Family.AncestorInserted", old, new end,
    ["cfw.family.becameRoot"]         = function(fam)         return FamilyName(fam), "CFW.Family.BecameRoot" end,
    ["cfw.family.becameSubFamily"]    = function(fam)         return FamilyName(fam), "CFW.Family.BecameSubFamily" end,
}

local function InitializeHooks(Enabled)
    for hookName in pairs(Events) do
        hook.Remove(hookName, "CFW_DevtoolsHooks")
    end

    if not Enabled then return end

    local EventViewer = CFW.EventViewer

    for hookName, build in pairs(Events) do
        hook.Add(hookName, "CFW_DevtoolsHooks", function(...)
            if EventViewer.Enabled() then
                EventViewer.AppendEvent(build(...))
            end
        end)
    end
end

hook.Add("ACF3_DevTools_EnableChanged", "CFW_Hook", InitializeHooks)

if CFW.EventViewer then -- ??????????????????
    InitializeHooks(CFW.EventViewer.Enabled())
end
