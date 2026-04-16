-- Contraptions are an object to refer to a collection of connected entities

CFW.Contraptions        = {}
CFW.Classes.Contraption = {}

function CFW.createContraption()
    local con  = {
        ents        = {},
        entsbyclass = {},
        families    = {},
        count       = 0,
        color       = ColorRand(50, 255),
        created     = CurTime(),
    }

    setmetatable(con, CFW.Classes.Contraption)

    con:Init()

    return con
end

do -- Contraption getters and setters
    local ENT              = FindMetaTable("Entity")
    local Entity_GetTable  = ENT.GetTable

    -- MARCH 4/16/2026
    -- We're going to deprecate this function and remove it sometime within the next 3-4 months probably.
    -- Appropriate announcement will be given out to potential consumers of the API soonish, and then I'll make this ErrorNoHaltWithStack
    -- for a week or so, then remove it entirely. Use CFW_GetContraption as its replacement which is properly namespaced.
    -- This function has caused headaches in other codebases (wiremod's cam controllers for example) and should've always been namedspaced...

    function ENT:GetContraption()
        return Entity_GetTable(self)._contraption
    end

    function ENT:CFW_GetContraption()
        return Entity_GetTable(self)._contraption
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

        local className   = ent:GetClass()
        local entsByClass = self.entsbyclass[className]

        if entsByClass then
            entsByClass[ent] = nil

            if not next(entsByClass) then
                self.entsbyclass[className] = nil
            end
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

    function CLASS:ContainsClass(ClassName)
        local Tracked = self.entsbyclass[ClassName]
        if not Tracked then return false end

        return next(Tracked) ~= nil -- I don't *THINK* we would ever get NULL here...
    end
end