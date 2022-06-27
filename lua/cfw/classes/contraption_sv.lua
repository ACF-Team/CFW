-- Contraptions are an object to refer to a collection of connected entities

CFW.contraptions        = {}
CFW.classes.contraption = {}

function CFW.createContraption(...)
    local con  = {
        ents  = {},
        count = 0,
        color = ColorRand(50, 255)
    }

    setmetatable(con, CFW.classes.contraption)

    con:Init()

    if istable(...) then
        for ent in pairs(...) do
            con:Add(ent)
        end
    else
        for _, ent in ipairs({...}) do
            con:Add(ent)
        end
    end

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
        hook.Run("CFW_ContraptionInit", self)
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

        ent:SetColor(Color(math.Clamp(self.color.r + math.Rand(-20, 20), 0, 255), math.Clamp(self.color.g + math.Rand(-20, 20), 0, 255), math.Clamp(self.color.b + math.Rand(-20, 20), 0, 255)))
        ent:SetMaterial("models/debug/debugwhite")

        hook.Run("CFW_ContraptionAppended", self, ent)
    end

    function CLASS:Sub(ent)
        ent._contraption = nil
        self.ents[ent]   = nil
        self.count       = self.count - 1
        
        ent:SetColor(Color(255, 255, 255))
        ent:SetMaterial("")

        hook.Run("CFW_ContraptionPopped", self, ent)

        if not next(self.ents) then
            self:Remove()
        end
    end

    function CLASS:Remove(merged)
        if merged then
            hook.Run("CFW_ContraptionMerged", self, merged)
        else
            hook.Run("CFW_ContraptionRemoved", self)
        end

        CFW.contraptions[self] = nil
    end
end