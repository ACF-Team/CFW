-- Families are collections of parented entities, you know, parents... children...

local CFW = CFW

local Families       = {}
local EntityFamilies = setmetatable({}, {__mode = "k"})

CFW.Families       = Families
CFW.EntityFamilies = EntityFamilies

local CLASS = {}
CFW.Classes.Family = CLASS

function CFW.Classes.Family.create(ancestor)
    local fam = {
        count       = 0,
        ents        = {},
        entsbyclass = {},
        ancestor    = ancestor,
        children    = {},
        color       = ColorRand(),
        created     = CurTime(),
    }

    setmetatable(fam, CLASS)

    fam:Init()
    fam:Add(ancestor, true)

    return fam
end

do -- Class def
    CLASS.__index = CLASS

    function CLASS:Init()
        Families[self] = true

        local con = self.ancestor:CFW_GetContraption()
        if con then con.families[self] = true end

        hook.Run("cfw.family.created", self)
    end

    function CLASS:GetRoot()
        return self.ancestor
    end

    function CLASS:Delete()
        self:Sub(self.ancestor, true)

        local con = self.ancestor:CFW_GetContraption()
        if con then con.families[self] = nil end

        hook.Run("cfw.family.deleted", self)

        Families[self] = nil
    end

    function CLASS:Add(entity, isAncestor)
        self.count        = self.count + 1
        self.ents[entity] = true

        EntityFamilies[entity] = self

        local className = entity:GetClass()
        self.entsbyclass[className] = self.entsbyclass[className] or {}
        self.entsbyclass[className][entity] = true

        hook.Run("cfw.family.added", self, entity)

        if not isAncestor then
            self.children[entity] = true
        end

        for k, v in pairs(entity:GetChildren()) do
            local child = isnumber(k) and v or k
            if child == entity then continue end
            if not IsValid(child) then continue end
            if child.CFW_NO_FAMILY_TRAVERSAL then continue end

            self:Add(child)
        end
    end

    function CLASS:Sub(entity, isAncestor)
        self.count        = self.count - 1
        self.ents[entity] = nil

        EntityFamilies[entity] = nil

        local entValid    = IsValid(entity)
        local className   = entValid and entity:GetClass() or ""
        local entsByClass = self.entsbyclass[className]

        if entsByClass then
            entsByClass[entity] = nil

            if not next(entsByClass) then
                self.entsbyclass[className] = nil
            end
        end

        hook.Run("cfw.family.subbed", self, entity)

        if isAncestor then return end

        self.children[entity] = nil

        if not entValid then return end

        for k, v in pairs(entity:GetChildren()) do
            local child = isnumber(k) and v or k
            if child == entity then continue end
            if child.CFW_NO_FAMILY_TRAVERSAL then continue end

            self:Sub(child)
        end
    end

    local Empty     = {}
    function CLASS:EntitiesByClass(ClassName)
        local Tracked = self.entsbyclass[ClassName]
        if not Tracked then return Empty end

        return Tracked
    end

    function CLASS:ContainsClass(ClassName)
        local Tracked = self.entsbyclass[ClassName]
        if not Tracked then return false end

        return next(Tracked) ~= nil
    end
end

do
    local ENT = FindMetaTable("Entity")

    function ENT:GetFamily()
        return EntityFamilies[self]
    end

    function ENT:GetAncestor()
        local Family = EntityFamilies[self]
        return Family and Family.ancestor or self
    end

    function ENT:SetFamily(newFamily)
        local oldFamily = EntityFamilies[self]

        if oldFamily then
            oldFamily:Sub(self)

            if oldFamily.count <= 1 then oldFamily:Delete() end
        end

        if newFamily then
            newFamily:Add(self)
        end

        if not newFamily and not self.CFW_REMOVING and next(self:GetChildren()) then
            CFW.Classes.Family.create(self)
        end
    end

    function ENT:GetFamilyChildren()
        local Family = EntityFamilies[self]
        return Family and Family.children or self:GetChildren()
    end
end
