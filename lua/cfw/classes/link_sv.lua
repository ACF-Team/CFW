-- Links are an abstraction of constraints and parents or "connections"
-- These are used to keep track of the number of connections between two entities
-- In graph theory these are edges

local CFW = CFW

local EntityLinks = setmetatable({}, {__mode = "k"})

CFW.EntityLinks = EntityLinks

local CLASS = {}
CFW.Classes.Link = CLASS

function CFW.createLink(a, b)
    local indexA, indexB = a:EntIndex(), b:EntIndex()

    local link = {
        entA    = a,
        entB    = b,
        indexA  = indexA,
        indexB  = indexB,
        count   = 1,
        color   = ColorRand(),
        created = CurTime(),
    }

    local linksA = EntityLinks[a] or {}
    EntityLinks[a] = linksA
    local linksB = EntityLinks[b] or {}
    EntityLinks[b] = linksB

    linksA[indexB] = link
    linksB[indexA] = link

    setmetatable(link, CLASS)

    return link:Init()
end

do -- Class def
    CLASS.__index = CLASS -- why?

    function CLASS:Init()
        return link
    end

    function CLASS:Add()
        self.count = self.count + 1
    end

    function CLASS:Sub()
        self.count = self.count - 1

        if self.count == 0 then return self:Remove() end

        return true
    end

    function CLASS:Remove()
        local contraptionPopped = false
        local entA, entB        = self.entA, self.entB
        local indexA, indexB    = self.indexA, self.indexB

        if IsValid(entA) then
            local linksA = EntityLinks[entA]
            linksA[indexB] = nil

            if not next(linksA) then
                -- It's important that the entity is removed from the family first, then the contraption in that order
                entA:SetFamily(nil)
                entA:CFW_GetContraption():Sub(entA)

                contraptionPopped = true
            end
        else
            contraptionPopped = true
        end

        if IsValid(entB) then
            local linksB = EntityLinks[entB]
            linksB[indexA] = nil

            if not next(linksB) then
                entB:SetFamily(nil)
                entB:CFW_GetContraption():Sub(entB)

                contraptionPopped = true
            end
        else
            contraptionPopped = true
        end

        return contraptionPopped
    end
end

do
    local ENT = FindMetaTable("Entity")

    function ENT:GetCFWLink(other) -- Returns the link object between this and other
        local links = EntityLinks[self]
        return links and links[other:EntIndex()] or nil
    end

    function ENT:GetCFWLinks() -- Creates a shallow copy of the links table
        local links = EntityLinks[self]
        local out   = {}

        if links then
            for k, v in pairs(links) do
                out[k] = v
            end
        end

        return out
    end
end
