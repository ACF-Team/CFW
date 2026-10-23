-- Contraptions are an object to refer to a collection of connected entities

local CFW = CFW

local Contraptions       = {}
local EntityContraptions = setmetatable({}, {__mode = "k"})

CFW.Contraptions         = Contraptions
CFW.EntityContraptions   = EntityContraptions

local CLASS = {}
CFW.Classes.Contraption = CLASS

function CFW.createContraption()
    local con  = {
        ents        = {},
        entsbyclass = {},
        families    = {},
        count       = 0,
        color       = ColorRand(50, 255),
        created     = CurTime(),
    }

    setmetatable(con, CLASS)

    con:Init()

    return con
end

do -- Contraption getters and setters
    local ENT = FindMetaTable("Entity")

    if file.Exists("cfg/cfw_legacy_mode.cfg", "GAME") then
        CFW.LEGACY_MODE = true
    end

    function ENT:CFW_GetContraption()
        return EntityContraptions[self]
    end

    if os.time() < 1791417621 or CFW.LEGACY_MODE then
        local nextWarning

        function ENT:GetContraption()
            if not CFW.LEGACY_MODE then
                local t = os.time()
                if not nextWarning or t >= nextWarning then
                    nextWarning = t + 60
                    ErrorNoHaltWithStack("GetContraption is deprecated, use CFW_GetContraption instead. GetContraption will be removed on October 8th 2026.")
                end
            end
            return self:CFW_GetContraption()
        end
    end
end

do
    CLASS.__index = CLASS

    function CLASS:Init()
        Contraptions[self] = true
        hook.Run("cfw.contraption.created", self)
    end

    function CLASS:Merge(other)
        for ent in pairs(other.ents) do
            self:Add(ent)
        end

        other:Remove(self)
    end

    function CLASS:Add(ent)
        EntityContraptions[ent] = self
        self.ents[ent]   = true
        self.count       = self.count + 1

        local className = ent:GetClass()
        self.entsbyclass[className] = self.entsbyclass[className] or {}
        self.entsbyclass[className][ent] = true

        hook.Run("cfw.contraption.entityAdded", self, ent)
    end

    function CLASS:Sub(ent)
        EntityContraptions[ent] = nil
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

        Contraptions[self] = nil
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

        return next(Tracked) ~= nil
    end
end
