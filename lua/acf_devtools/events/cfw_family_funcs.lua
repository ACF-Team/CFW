local ACF_DevTools = ACF_DevTools
local EventViewer = ACF_DevTools.EventViewer

local function RenderEntities3D(...)
    for i = 1, select("#", ...) do
        local Entity = select(i, ...)
        if not IsValid(Entity) then continue end

        local pulse = Lerp((math.sin(CurTime() * 7) + 1) / 2, 0.33, 1)

        render.SuppressEngineLighting(true)
        render.ModelMaterialOverride(Material("models/debug/debugwhite"))
        render.SetColorModulation(pulse, pulse, pulse)

        render.DepthRange(0, 0)
        Entity:DrawModel()
        render.DepthRange(0, 1)

        render.SetColorModulation(1, 1, 1)
        render.ModelMaterialOverride(nil)
        render.SuppressEngineLighting(false)
    end
end

do
    local Init = EventViewer.DefineEvent("CFW.Family.Init")
    Init.Icon = "icon16/group_add.png"

    function Init.BuildNode()

    end
end

do
    local EntityAdded = EventViewer.DefineEvent("CFW.Family.EntityAdded")
    EntityAdded.Icon = "icon16/basket_put.png"

    function EntityAdded.BuildNode(Node, Entity)
        EventViewer.AddKeyValueNode(Node, "Entity", Entity, "icon16/brick.png")
    end
    EntityAdded.Render3D = RenderEntities3D
end

do
    local EntityRemoved = EventViewer.DefineEvent("CFW.Family.EntityRemoved")
    EntityRemoved.Icon = "icon16/basket_remove.png"

    function EntityRemoved.BuildNode(Node, Entity)
        EventViewer.AddKeyValueNode(Node, "Entity", Entity, "icon16/brick.png")
    end
    EntityRemoved.Render3D = RenderEntities3D
end

do
    local Merged = EventViewer.DefineEvent("CFW.Family.Merged")
    Merged.Icon = "icon16/arrow_merge.png"

    function Merged.BuildNode(Node, Other)
        EventViewer.AddKeyValueNode(Node, "Merged Into", Other, "icon16/group.png")
    end
end

do
    local Split = EventViewer.DefineEvent("CFW.Family.Split")
    Split.Icon = "icon16/arrow_divide.png"

    function Split.BuildNode(Node, Other, Ancestor)
        EventViewer.AddKeyValueNode(Node, "Split Into", Other, "icon16/group.png")
        EventViewer.AddKeyValueNode(Node, "New Ancestor", Ancestor, "icon16/brick.png")
    end
    Split.Render3D = RenderEntities3D
end

do
    local AncestorRemoved = EventViewer.DefineEvent("CFW.Family.AncestorRemoved")
    AncestorRemoved.Icon = "icon16/arrow_up.png"

    function AncestorRemoved.BuildNode(Node, Old, New)
        EventViewer.AddKeyValueNode(Node, "Old Ancestor", Old, "icon16/brick.png")
        EventViewer.AddKeyValueNode(Node, "New Ancestor", New, "icon16/brick.png")
    end
    AncestorRemoved.Render3D = RenderEntities3D
end

do
    local AncestorInserted = EventViewer.DefineEvent("CFW.Family.AncestorInserted")
    AncestorInserted.Icon = "icon16/arrow_down.png"

    function AncestorInserted.BuildNode(Node, Old, New)
        EventViewer.AddKeyValueNode(Node, "Old Ancestor", Old, "icon16/brick.png")
        EventViewer.AddKeyValueNode(Node, "New Ancestor", New, "icon16/brick.png")
    end
    AncestorInserted.Render3D = RenderEntities3D
end

do
    local BecameRoot = EventViewer.DefineEvent("CFW.Family.BecameRoot")
    BecameRoot.Icon = "icon16/shield.png"

    function BecameRoot.BuildNode()

    end
end

do
    local BecameSubFamily = EventViewer.DefineEvent("CFW.Family.BecameSubFamily")
    BecameSubFamily.Icon = "icon16/shield_go.png"

    function BecameSubFamily.BuildNode()

    end
end

do
    local Removed = EventViewer.DefineEvent("CFW.Family.Removed")
    Removed.Icon = "icon16/cancel.png"

    function Removed.BuildNode()

    end
end
