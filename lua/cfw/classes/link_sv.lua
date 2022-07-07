-- Links are an abstraction of constraints and parents or "connections"
-- These are used to keep track of the number of connections between two entities
-- In graph theory these are edges

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
        -- A clean break occurs when either entity no longer has any other links and there's no need
        -- to check for indirect connections
        local cleanBreak = false
        local a, b = self.a, self.b

        a._links[b] = nil
        b._links[a] = nil

        if not next(a._links) then
            a._links = nil
            a:GetContraption():Sub(a)

            cleanBreak = true
        end

        if not next(b._links) then
            b._links = nil
            b:GetContraption():Sub(b)

            cleanBreak = true
        end
        
        return cleanBreak
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