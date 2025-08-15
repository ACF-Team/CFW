-- Tracks classnames -> entity instances on a contraption

local function InitClassTracking(Contraption)
    Contraption.Classes = {}
end

hook.Add("cfw.contraption.created", "CFW_ClassTracking", InitClassTracking)
hook.Add("cfw.family.created", "CFW_ClassTracking", InitClassTracking)

local function AddEntityClass(Class, Ent)
    if not IsValid(Ent) then return end
    local ClassName = Ent:GetClass()

    local Table = Class.Classes[ClassName]
    if not Table then
        Table = {}
        Class.Classes[ClassName] = Table
    end

    Table[Ent] = true
end

hook.Add("cfw.contraption.entityAdded", "CFW_ClassTracking", AddEntityClass)
hook.Add("cfw.family.added", "CFW_ClassTracking", AddEntityClass)

local function SubEntityClass(Class, Ent)
    if not IsValid(Ent) then return end
    local ClassName = Ent:GetClass()

    local Table = Class.Classes[ClassName]
    if not Table then return end

    Table[Ent] = false
end

hook.Add("cfw.contraption.entityRemoved", "CFW_ClassTracking", SubEntityClass)
hook.Add("cfw.family.subbed", "CFW_ClassTracking", SubEntityClass)

local CLASS     = CFW.Classes.Contraption
local Empty     = {}

function CLASS:FindByClass(ClassName)
    local Tracked = self.Classes[ClassName]
    if not Tracked then return Empty end

    return Tracked
end