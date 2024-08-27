-- Tracks the total mass of a contraption or family

local PHYS    = FindMetaTable("PhysObj")
local setMass = setMass or PHYS.SetMass

function PHYS:SetMass(newMass)
    local ent     = self:GetEntity()
    local oldMass = ent._mass or 0 -- The 'or 0' handles cases of ents connected before they had a physObj

    ent._mass = newMass

    setMass(self, newMass)

    local con = ent:GetContraption()

    if con then
        con.totalMass = con.totalMass + (newMass - oldMass)
    end
end

local function InitMass(Class)
    Class.totalMass = 0
end

hook.Add("cfw.contraption.created", "CFW_Mass", InitMass)
hook.Add("cfw.family.created", "CFW_Mass", InitMass)

local function AddMass(Class, Ent)
    if not IsValid(Ent) then return end

    local PhysObj = Ent:GetPhysicsObject()

    if IsValid(PhysObj) then
        local Mass = PhysObj:GetMass()

        Ent._mass     = Mass
        Class.totalMass = Class.totalMass + Mass
    end
end

hook.Add("cfw.contraption.entityAdded", "CFW_Mass", AddMass)
hook.Add("cfw.family.added", "CFW_Mass", AddMass)

local function SubMass(Class, Ent)
    if not IsValid(Ent) then return end

    local PhysObj = Ent:GetPhysicsObject()

    if IsValid(PhysObj) then
        Class.totalMass = Class.totalMass - PhysObj:GetMass()
    end
end

hook.Add("cfw.contraption.entityRemoved", "CFW_Mass", SubMass)
hook.Add("cfw.family.subbed", "CFW_Mass", SubMass)