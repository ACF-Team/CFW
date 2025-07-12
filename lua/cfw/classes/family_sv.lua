-- Families are collections of parented entities, you know, parents... children...

CFW.Classes.Family = {}
CFW.Families       = {}

function CFW.Classes.Family.create(ancestor)
    local fam = {
        count    = 0,
        ents     = {},
        ancestor = ancestor,
        children = {},
        color    = ColorRand()
    }

    setmetatable(fam, CFW.Classes.Family)

    fam:Init()
    fam:Add(ancestor, true)

    return fam
end

do -- Class def
    local CLASS = CFW.Classes.Family

    CLASS.__index = CLASS

    function CLASS:Init()
        CFW.Families[self] = true

        hook.Run("cfw.family.created", self)
    end

    function CLASS:GetRoot()
        return self.ancestor
    end

    function CLASS:Delete()
        self:Sub(self.ancestor, true)

        hook.Run("cfw.family.deleted", self)

        CFW.Families[self] = nil
    end

    function CLASS:Add(entity, isAncestor)
        self.count        = self.count + 1
        self.ents[entity] = true

        entity._family = self

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

        entity._family = nil

        hook.Run("cfw.family.subbed", self, entity)

        if isAncestor then return end

        self.children[entity] = nil

        if not IsValid(entity) then return end

        for k, v in pairs(entity:GetChildren()) do
            local child = isnumber(k) and v or k
            if child == entity then continue end
            if child.CFW_NO_FAMILY_TRAVERSAL then continue end

            self:Sub(child)
        end
    end
end

do
    local ENT = FindMetaTable("Entity")

    function ENT:GetFamily()
        return self._family
    end

    function ENT:GetAncestor()
        local Family = self._family
        return Family and Family.ancestor or self
    end

    function ENT:SetFamily(newFamily)
        local oldFamily = self._family

        if oldFamily then
            oldFamily:Sub(self)

            if oldFamily.count <= 1 then oldFamily:Delete() end
        end

        if newFamily then
            newFamily:Add(self)
        end

        if not newFamily and next(self:GetChildren()) then
            CFW.Classes.Family.create(self)
        end
    end

    function ENT:GetFamilyChildren()
        local Family = self._family
        return Family and Family.children or self:GetChildren()
    end
end