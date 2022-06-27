-- Links are an abstraction of constraints and parents or "connections"
-- These are used to keep track of the number of connections between two entities
-- In graph theory these are edges

CFW.links        = {}
CFW.classes.link = {}

function CFW.createLink(a, b)
    local link = {
        [a]   = true,
        [b]   = true,
        a     = a,
        b     = b,
        count = 1,
    }

    a._links = a._links or {}
    b._links = b._links or {}

    a._links[b] = link
    b._links[a] = link

    setmetatable(link, CFW.classes.link)

    return link:Init()
end

do -- Class def
    local CLASS = CFW.classes.link

    CLASS.__index = CLASS -- why?

    function CLASS:Init()
        CFW.links[self] = true

        return link
    end

    function CLASS:Add()
        self.count = self.count + 1
    end

    function CLASS:Sub()
        self.count = self.count - 1

        if self.count == 0 then
            return self:Remove() -- Returns true for a "dirty break"
        end

        return false
    end

    function CLASS:Remove()
        local dirtyBreak = true -- If both entities on the link have other links, it's a "dirty break"
        local a, b = self.a, self.b

        CFW.links[self] = nil

        a._links[b] = nil
        b._links[a] = nil

        if not next(a._links) then
            a._links = nil
            b:GetContraption():Sub(a)

            dirtyBreak = false
        end

        if not next(b._links) then
            b._links = nil
            b:GetContraption():Sub(b)

            dirtyBreak = false
        end
        
        return dirtyBreak
    end
end

do
    local ENT = FindMetaTable("Entity")

    function ENT:GetLink(other) -- Returns the link object between this and other
        return self._links and self._links[other] or nil
    end

    function ENT:GetLinks() -- Creates a shallow copy of the links table
        local out = {}

        for k, v in pairs(self._links) do
            out[k] = v
        end

        return out
    end
end