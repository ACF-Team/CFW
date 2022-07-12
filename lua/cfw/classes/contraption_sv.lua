-- Contraptions are an object to refer to a collection of connected entities

CFW.contraptions        = {}
CFW.classes.contraption = {}

function CFW.createContraption()
    local con  = {
        ents  = {},
        count = 0,
        color = ColorRand(50, 255)
    }

    setmetatable(con, CFW.classes.contraption)

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
    local CLASS = CFW.classes.contraption

    CLASS.__index = CLASS

    function CLASS:Init()
        CFW.contraptions[self] = true
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

        hook.Run("cfw.contraption.entityAdded", self, ent)
    end

    function CLASS:Sub(ent)
        ent._contraption = nil
        self.ents[ent]   = nil
        self.count       = self.count - 1

        hook.Run("cfw.contraption.entityRemoved", self, ent)

        if not next(self.ents) then
            self:Remove()
        end
    end

    function CLASS:Remove(mergedInto)
        if mergedInto then
            hook.Run("cfw.contraption.merged", self, mergedInto)
        else
            hook.Run("cfw.contraption.removed", self)
        end

        CFW.contraptions[self] = nil
    end
end