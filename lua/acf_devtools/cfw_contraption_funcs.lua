local ACF_DevTools = ACF_DevTools
local EventViewer = ACF_DevTools.EventViewer

do
    local Created = EventViewer.DefineEvent("CFW.Contraption.Created")
    Created.Icon = "icon16/add.png"

    function Created.BuildNode(Node)

    end
end

local function RenderEntity3D(Entity)
    if not IsValid(Entity) then return end

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

do
    local EntityAdded = EventViewer.DefineEvent("CFW.Contraption.EntityAdded")
    EntityAdded.Icon = "icon16/basket_put.png"

    function EntityAdded.BuildNode(Node, Entity)
        EventViewer.AddKeyValueNode(Node, "Entity", Entity, "icon16/brick.png")
    end
    EntityAdded.Render3D = RenderEntity3D
end

do
    local EntityRemoved = EventViewer.DefineEvent("CFW.Contraption.EntityRemoved")
    EntityRemoved.Icon = "icon16/basket_remove.png"

    function EntityRemoved.BuildNode(Node, Entity)
        EventViewer.AddKeyValueNode(Node, "Entity", Entity, "icon16/brick.png")
    end
    EntityRemoved.Render3D = RenderEntity3D
end

do
    local Merged = EventViewer.DefineEvent("CFW.Contraption.Merged")
    Merged.Icon = "icon16/arrow_merge.png"

    function Merged.BuildNode(Node, Other)
        EventViewer.AddKeyValueNode(Node, "Merged Into", Other, "icon16/bricks.png")
    end
end

do
    local Split = EventViewer.DefineEvent("CFW.Contraption.Split")
    Split.Icon = "icon16/arrow_divide.png"

    function Split.BuildNode(Node, Other)
        EventViewer.AddKeyValueNode(Node, "Split Into", Other, "icon16/bricks.png")
    end
end

do
    local Removed = EventViewer.DefineEvent("CFW.Contraption.Removed")
    Removed.Icon = "icon16/cancel.png"

    function Removed.BuildNode(Node)

    end
end