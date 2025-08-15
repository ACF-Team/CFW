-- Contraptions are an object to refer to a collection of connected entities

CFW.Contraptions        = {}
CFW.Classes.Contraption = {}

function CFW.createContraption()
    local con  = {
        ents        = {},
        entsbyclass = {},
        count       = 0,
        color       = ColorRand(50, 255)
    }

    setmetatable(con, CFW.Classes.Contraption)

    con:Init()

    return con
end

do -- Contraption getters and setters
    local ENT = FindMetaTable("Entity")

    function ENT:GetContraption()
        return self._contraption
    end
end

do -- Class def
    local CLASS = CFW.Classes.Contraption

    CLASS.__index = CLASS

    function CLASS:Init()
        CFW.Contraptions[self] = true
        hook.Run("cfw.contraption.created", self)
    end

    function CLASS:Merge(other)
        for ent in pairs(other.ents) do
            self:Add(ent)
        end

        other:Remove(self)
    end

    function CLASS:Add(ent)
        ent._contraption = self
        self.ents[ent]   = true
        self.count       = self.count + 1

        local className = ent:GetClass()
        self.entsbyclass[className] = self.entsbyclass[className] or {}
        self.entsbyclass[className][ent] = true

        hook.Run("cfw.contraption.entityAdded", self, ent)
    end

    function CLASS:Sub(ent)
        ent._contraption = nil
        self.ents[ent]   = nil
        self.count       = self.count - 1

        local className = ent:GetClass()
        if self.entsbyclass[className] then
            self.entsbyclass[className][ent] = nil
        end

        hook.Run("cfw.contraption.entityRemoved", self, ent)

        if not next(self.ents) then
            self:Remove()
        end
    end

    function CLASS:Remove(mergedInto)
        self._removed = true

        if mergedInto then
            hook.Run("cfw.contraption.merged", self, mergedInto)
        else
            hook.Run("cfw.contraption.removed", self)
        end

        CFW.Contraptions[self] = nil
    end

    function CLASS:Defuse()
        for ent in pairs(self.ents) do
            if IsValid(ent) then
                self:Sub(ent)
            end
        end

        if not self._removed then self:Remove() end
    end

    local Empty     = {}
    function CLASS:EntitiesByClass(ClassName)
        local Tracked = self.entsbyclass[ClassName]
        if not Tracked then return Empty end

        return Tracked
    end
end