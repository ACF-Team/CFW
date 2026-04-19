
local function GetEventViewerName(Contraption) return "Contraption: " .. tostring(Contraption):sub(8) end
local function InitializeHooks(Enabled)
    if not Enabled then
        hook.Remove("cfw.contraption.created", "CFW_DevtoolsHooks")
        hook.Remove("cfw.contraption.entityAdded", "CFW_DevtoolsHooks")
        hook.Remove("cfw.contraption.entityRemoved", "CFW_DevtoolsHooks")
        hook.Remove("cfw.contraption.merged", "CFW_DevtoolsHooks")
        hook.Remove("cfw.contraption.split", "CFW_DevtoolsHooks")
        hook.Remove("cfw.contraption.removed", "CFW_DevtoolsHooks")
        return
    end

    local EventViewer = CFW.EventViewer

    hook.Add("cfw.contraption.created", "CFW_DevtoolsHooks", function(self)
        if EventViewer.Enabled() then
            EventViewer.AppendEvent(GetEventViewerName(self), "CFW.Contraption.Created")
        end
    end)

    hook.Add("cfw.contraption.entityAdded", "CFW_DevtoolsHooks", function(self, ent)
        if EventViewer.Enabled() then
            EventViewer.AppendEvent(GetEventViewerName(self), "CFW.Contraption.EntityAdded", ent)
        end
    end)

    hook.Add("cfw.contraption.entityRemoved", "CFW_DevtoolsHooks", function(self, ent)
        if EventViewer.Enabled() then
            EventViewer.AppendEvent(GetEventViewerName(self), "CFW.Contraption.EntityRemoved", ent)
        end
    end)

    hook.Add("cfw.contraption.merged", "CFW_DevtoolsHooks", function(self, mergedInto)
        if EventViewer.Enabled() then
            EventViewer.AppendEvent(GetEventViewerName(self), "CFW.Contraption.Merged", GetEventViewerName(mergedInto))
        end
    end)

    hook.Add("cfw.contraption.split", "CFW_DevtoolsHooks", function(self, mergedInto)
        if EventViewer.Enabled() then
            EventViewer.AppendEvent(GetEventViewerName(self), "CFW.Contraption.Split", GetEventViewerName(mergedInto))
        end
    end)

    hook.Add("cfw.contraption.removed", "CFW_DevtoolsHooks", function(self)
        if EventViewer.Enabled() then
            EventViewer.AppendEvent(GetEventViewerName(self), "CFW.Contraption.Removed")
        end
    end)
end

hook.Add("ACF3_DevTools_EnableChanged", "CFW_Hook", InitializeHooks)
InitializeHooks(CFW.EventViewer.Enabled())