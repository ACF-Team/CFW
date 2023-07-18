-- Families are collections of parented entities, you know, parents... children...

CFW.classes.family = {}
CFW.families       = {}

function CFW.classes.family.create(ancestor)
    local fam = {
        count    = 0,
        ents     = {},
        ancestor = ancestor,
        color    = ColorRand()
    }

    setmetatable(fam, CFW.classes.family)

    fam:Init()
    fam:Add(ancestor)

    return fam
end

do -- Class def
    local CLASS = CFW.classes.family; CLASS.__index = CLASS

    function CLASS:Init() print("INIT", self)
        CFW.families[self] = true

        hook.Run("cfw.family.created", self)
    end

    function CLASS:GetRoot()
        return self.ancestor
    end

    function CLASS:Delete()
        --self:Sub(self.ancestor)

        print("DELETE", self)
        hook.Run("cfw.family.deleted", self)

        CFW.families[self] = nil
    end

    function CLASS:Add(entity, depth)
        depth = depth or 0
        print(string.rep("    ", depth) .. "ADD", entity, self)

        self.count        = self.count + 1
        self.ents[entity] = true

        entity._family = self
        entity:DebugColor(self.color)

        hook.Run("cfw.family.added", self, entity)

        for child in pairs(entity:GetChildren()) do
            self:Add(child, depth + 1)
        end
    end

    function CLASS:Sub(entity, depth)
        depth = depth or 0

        self.count        = self.count - 1
        self.ents[entity] = nil

        entity._family = nil
        entity:DebugColor()

        print(string.rep("    ", depth) .. "SUB", entity, self)
        hook.Run("cfw.family.subbed", self, entity)

        for child in pairs(entity:GetChildren()) do
            self:Sub(child, depth + 1)
        end
    end
end

do
    local ENT = FindMetaTable("Entity")

    function ENT:GetFamily()
        return self._family
    end

    function ENT:GetAncestor()
        return self._family and self._family.ancestor or self
    end

    function ENT:SetFamily(newFamily) print("SET FAMILY", self, newFamily)
        local oldFamily = self._family

        if oldFamily then
            oldFamily:Sub(self)

            if oldFamily.count <= 1 then oldFamily:Delete() end
        end

        if newFamily then
            newFamily:Add(self)
        end

        if not newFamily and next(self:GetChildren()) then
            CFW.classes.family.create(self)
        end
    end

    function ENT:GetFamilyChildren()
        return self._family.lookup[self].children
    end

    function ENT:DebugColor(color)
        print(color)
        if color then
            self._originalColor    = self._originalColor or self:GetColor()
            self._originalMaterial = self._originalMaterial or self:GetMaterial()

            self:SetColor(color)
            self:SetMaterial("models/debug/debugwhite")
        else
            self:SetColor(self._originalColor)
            self:SetMaterial(self._originalMaterial)

            self._originalColor    = nil
            self._originalMaterial = nil
        end
    end
end