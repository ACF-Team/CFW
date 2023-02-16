-- Families are collections of parented entities, you know, parents... children...

CFW.classes.family = {}
CFW.families       = {}

function CFW.classes.family.create()
    local fam = {
        lookup   = {},
        count    = 0,
        ancestor = false,
        color    = ColorRand()
    }

    setmetatable(fam, CFW.classes.family)

    fam:Init()

    return fam
end

do -- Class def
    local CLASS = CFW.classes.family; CLASS.__index = CLASS

    function CLASS:Init()
        CFW.families[self] = true

        hook.Run("cfw.family.created", self)
    end

    function CLASS:Add(child, parent) print("ADD", child, self)
        self.count         = self.count + 1
        self.lookup[child] = {
            root     = parent or false,
            children = {}
        }

        if parent then
            self.lookup[parent].children[child] = true
        else -- If it has no parent it's the root!
            self.ancestor = child
        end
    end

    function CLASS:Pop(child, parent) print("POP", child, self)
        local lookup = self.lookup[child]
    
        self.count         = self.count - 1
        self.lookup[child] = nil

        if parent then self.lookup[parent].children[child] = nil end
    end

    function CLASS:GetRoot()
        return self.ancestor
    end

    function CLASS:Remove()
        self.ancestor:SetFamily(nil)

        hook.Run("cfw.family.removed", self)

        CFW.families[self] = nil
    end
end

do 
    local ENT = FindMetaTable("Entity")

    function ENT:GetFamily()
        return self._family
    end

    function ENT:GetAncestor()
        return self._family and self._family.root or self
    end

    function ENT:SetFamily(newFamily, parent) print("SET", self, newFamily)
        local oldFamily = self._family

        if oldFamily then
            if oldFamily == newFamily then return print("this shouldn't happen!", ent, newFamily) end

            for child in pairs(oldFamily.lookup[self].children) do
                print("->", child)
                child:SetFamily(newFamily, self)
            end
            
            oldFamily:Pop(self, parent)

            if oldFamily.count <= 1 and self ~= oldFamily.ancestor then oldFamily:Remove() end
        end

        if newFamily then
            newFamily:Add(self, parent)

            self._originalColor    = self._originalColor or self:GetColor()
            self._originalMaterial = self._originalMaterial or self:GetMaterial()
    
            self:SetColor(newFamily.color)
            self:SetMaterial("models/debug/debugwhite")
        else
            print("reset", self)
            timer.Simple(0, function()
                self:SetColor(self._originalColor)
                self:SetMaterial(self._originalMaterial)

                self._originalColor    = nil
                self._originalMaterial = nil
            end)
        end

        self._family = newFamily
    end

    function ENT:GetFamilyChildren()
        return self._family.lookup[self].children
    end
end