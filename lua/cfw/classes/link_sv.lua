-- Links are an abstraction of constraints and parents or "connections"
-- These are used to keep track of the number of connections between two entities
-- In graph theory these are edges

CFW.Classes.Link = {}

local EntityLinks = {}
CFW.EntityLinks   = EntityLinks

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
    local linksB = EntityLinks[b] or {}

    EntityLinks[a] = linksA
    EntityLinks[b] = linksB

    linksA[indexB] = link
    linksB[indexA] = link

    setmetatable(link, CFW.Classes.Link)

    return link:Init()
end

do -- Class def
    local CLASS = CFW.Classes.Link

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
        local linksA, linksB    = EntityLinks[entA], EntityLinks[entB]
        local emptyA, emptyB    = true, true

        if linksA then
            linksA[indexB] = nil

            if next(linksA) then
                emptyA = false
            else
                EntityLinks[entA] = nil
            end
        end

        if linksB then
            linksB[indexA] = nil

            if next(linksB) then
                emptyB = false
            else
                EntityLinks[entB] = nil
            end
        end

        if IsValid(entA) then
            if emptyA then
                -- It's important that the entity is removed from the family first, then the contraption in that order
                entA:SetFamily(nil)
                entA:CFW_GetContraption():Sub(entA)

                contraptionPopped = true
            end
        else
            contraptionPopped = true
        end

        if IsValid(entB) then
            if emptyB then
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